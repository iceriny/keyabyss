import { counterWorldDelta, dodgeDirection } from "../shared/defense.ts";
import { enemyInCombat } from "../shared/arena.ts";
import * as FlameSystem from "./systems/FlameSystem.ts";
import * as EffectExecutor from "./systems/EffectExecutor.ts";
import type { WorldState } from "./Runtime.ts";
import { WordReservations } from "./targeting/WordReservations.ts";
import { EventJournal } from "./EventJournal.ts";
import type { DomainEvent, PresentationCue } from "../contracts/events.ts";
import * as EncounterDirector from "./progression/EncounterDirector.ts";
import { updateBossPhase } from "./systems/PhaseController.ts";
import * as RewardSystem from "./progression/RewardSystem.ts";
import * as PresentationSystem from "./systems/PresentationSystem.ts";
import * as SummonSystem from "./systems/SummonSystem.ts";
import * as EnemySystem from "./systems/EnemySystem.ts";
import * as MovementSystem from "./systems/MovementSystem.ts";
import * as ProjectileSystem from "./systems/ProjectileSystem.ts";
import * as StatusSystem from "./systems/StatusSystem.ts";
import * as DamageSystem from "./systems/DamageSystem.ts";
import * as CastSystem from "./systems/CastSystem.ts";
import * as Targeting from "./targeting/Targeting.ts";
import { TaskScheduler, type ScheduledTask } from "./TaskScheduler.ts";
import { RelicRules } from "./RelicRules.ts";
import { Campaign } from "./progression/Campaign.ts";
import type { Config, GameState, GameEvents } from "../contracts/game.ts";
import { WordPool } from "../vocabulary/index.ts";

import * as DefenseSystem from "./systems/DefenseSystem.ts";
import { inAttackRange } from "./systems/EnemyRange.ts";
import { difficulty } from "./progression/difficulty.ts";
import type { SimulationContent } from "../contracts/SimulationContent.ts";
import { createPlayer } from "../combat/model.ts";
import type { Point, Enemy } from "../combat/model.ts";
/* Keyabyss — fixed-substep combat and native Three.js presentation.
 * Gameplay RNG and presentation RNG are separate; React owns the interface.
 */

import * as C from "../shared/math.ts";
import { silentFeedback, type FeedbackPort } from "../contracts/feedback.ts";
const { clamp, pick, random, hash } = C;
const W = 1280,
  H = 800,
  TAU = Math.PI * 2,
  ENTITY_SCALE = 0.66;
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);
export interface CombatSimulation extends WorldState {}
export class CombatSimulation {
  godMode = false;
  activateGodMode() {
    this.godMode = true;
    this.resonance = 100;
    this.player.dash = this.player.maxDash;
    this.emit("toast", "GOD MODE · 致死回满 · 无限终式与闪避");
    this.emit("hud");
  }
  canEnemyAct(enemy: Enemy) {
    return !enemy.dead && enemyInCombat(this.arena, enemy);
  }
  applyBurn = FlameSystem.applyBurn;
  igniteExplosion = FlameSystem.igniteExplosion;
  fireImpact = FlameSystem.fireImpact;
  tickBurn = FlameSystem.tickBurn;
  spreadBurn = FlameSystem.spreadBurn;
  tickFireField = FlameSystem.tickFireField;
  effectSource = EffectExecutor.effectSource;
  applyEffect = EffectExecutor.applyEffect;
  get pendingRequiredTasks() {
    return this.tasks.some(
      (t) =>
        t.blocksClear &&
        (t.source === null ||
          this.enemies.some((e) => e.id === t.source && !e.dead)),
    );
  }
  readonly domainEvents = new EventJournal<DomainEvent>();
  readonly presentationCues = new EventJournal<PresentationCue>();
  roomVisit = 0;
  readonly campaign: Campaign;
  private readonly scheduler = new TaskScheduler();
  get tasks() {
    return this.scheduler.pending;
  }
  set tasks(tasks: ScheduledTask[]) {
    this.scheduler.replace(tasks);
  }
  readonly relicRules: RelicRules;
  readonly stats: import("../contracts/stats.ts").CombatStats;
  readonly content: SimulationContent;
  updateBossPhase = updateBossPhase;
  updateEnemyStatus = StatusSystem.updateEnemyStatus;
  bossDefinition() {
    const id = this.content.chapters[this.chapter || 0].bossId;
    const definition = id && this.content.bosses[id];
    if (!definition) throw new Error(`Missing boss definition ${id}`);
    return definition;
  }
  eliteProfile(e: Enemy) {
    return e.elite ? this.content.elites[e.elite] : undefined;
  }
  enemyProfile(e: Enemy) {
    return (this.content.enemies[e.type] || this.content.enemies.nib).behavior;
  }
  get bookBehavior() {
    const behavior = this.content.bookBehaviors[this.bookData.behavior];
    if (!behavior) throw new Error(`Missing behavior: ${this.book}`);
    return behavior;
  }
  waveCount = 3;
  assaultDirection = 0;
  runId = "";
  private activeStage = 0;
  routeOffers: readonly import("../contracts/content.ts").RouteDefinition[] =
    [];
  routeDestinations: Record<string, number> = {};
  get roomCount() {
    return this.campaign.at(this.stage || 0).definition.rooms.length;
  }
  get chapterName() {
    return this.campaign.at(this.stage || 0).definition.name;
  }
  get bossName() {
    return this.campaign.at(this.stage || 0).definition.bossName;
  }
  get nextRoomIsBoss() {
    return this.campaign.at(this.stage || 0).room.boss;
  }

  constructor(
    content: SimulationContent,
    events: GameEvents = {},
    feedback: FeedbackPort = silentFeedback,
  ) {
    this.content = content;
    this.campaign = new Campaign(content.chapters);
    this.relicRules = new RelicRules(content.relics);
    this.stats = this.relicRules.createStats(() => this.relics || {});
    this.events = events;
    this.state = "home";
    this.sound = feedback;
    this.renderDirty = true;
    this.options = {
      shake: 0.6,
      largeText: false,
      fx: 1,
      meaning: true,
      labelMeaning: false,
      reduceMotion: false,
      volume: 0.3,
      sfxVolume: 1,
      music: true,
      sound: true,
    };
    this.rng = random(1);
    this.fxRng = random(91);
    this.resetArrays();
    this.player = createPlayer();
    this.time = 0;
    this.visualTime = 0;
    this.shake = 0;
    this.hitStop = 0;
    this.counterSlowTime = 0;
    this.stopCooldown = 0;
    this.id = 0;
    this.entityScale = ENTITY_SCALE;
    this.arena = { l: 0, r: 1280, t: 0, b: 800 };
    this.aimKeys = {};
  }

  emit<K extends keyof GameEvents>(
    name: K,
    ...args: Parameters<NonNullable<GameEvents[K]>>
  ) {
    const handler = this.events[name] as
      ((...values: Parameters<NonNullable<GameEvents[K]>>) => void) | undefined;
    handler?.(...args);
  }

  setState(s: GameState) {
    this.renderDirty = true;
    if (s !== "playing") this.aimKeys = {};
    this.state = s;
    this.emit("state", s);
  }

  start(config: Config) {
    this.runId = globalThis.crypto?.randomUUID?.() ?? `run-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    this.domainEvents.reset();
    this.presentationCues.reset();
    this.roomVisit = 0;
    this.config = { ...config };
    this.rng = random(hash(config.seed || String(Date.now())));
    this.fxRng = random(hash(config.seed + "-effects"));
    this.pool = new WordPool(config.words, this.rng);
    this.mode = this.content.modes[config.mode] || this.content.modes.normal;
    this.book = this.content.books[config.book] ? config.book : "frost";
    this.bookData = this.content.books[this.book];
    this.level = 1;
    this.xp = 0;
    this.nextXP = 27;
    this.pending = 0;
    this.relics = {};
    this.stage = 0;
    this.chapter = 0;
    this.loopCount = 0;
    this.combo = 0;
    this.autofill = false;
    this.manual = 0;
    this.reflectionBoost = false;
    this.rescued = false;
    this.kills = 0;
    this.casts = 0;
    this.correct = 0;
    this.errors = 0;
    this.typedTotal = 0;
    this.dashes = 0;
    this.reflections = 0;
    this.maxCombo = 0;
    this.totalDamage = 0;
    this.elapsed = 0;
    this.wordStats = {};
    this.time = 0;
    this.id = 0;
    this.safeClock = 0;
    this.resonance = this.godMode ? 100 : 0;
    this.ultimateTime = 0;
    this.ultimates = 0;
    this.perfectDodges = 0;
    this.grazes = 0;
    this.wallHits = 0;
    this.overloads = 0;
    this.perfectWords = 0;
    this.bookCounter = 0;
    this.chargePulse = 0;
    this.rerolls = 2;
    this.focusId = null;
    this.spiritTime = 0;
    this.awakenedSpirits = 0;
    this.spiritShoot = 0;
    this.ultTick = 0;
    this.upgradeAt = 0;
    this.hitStop = 0;
    this.counterSlowTime = 0;
    this.stopCooldown = 0;
    this.shake = 0;
    this.hitFlash = 0;
    this.aimKeys = {};
    this.precisionTime = 0;
    this.bloodPaidStage = null;
    this.resetArrays();
    this.player = {
      x: 640,
      y: 490,
      r: 7,
      hp: this.mode.hp,
      maxHp: this.mode.hp,
      shield: 0,
      invuln: 0,
      dash: 2,
      maxDash: 2,
      vx: 0,
      vy: 0,
      recoil: 0,
      lean: 0,
      dashState: null,
      parryTime: 0,
      parryCooldown: 0,
      parrySuccess: false,
    };
    this.cancel(false);
    this.sound.init();
    this.beginRoom({ type: "normal" });
  }

  beginRoom(route?: import("../contracts/game.ts").Route) {
    this.activeStage = this.stage;
    EncounterDirector.beginRoom.call(this, route);
  }
  updateEncounter = EncounterDirector.updateEncounter;
  finishEncounter = EncounterDirector.finishEncounter;

  wordFor = Targeting.wordFor;

  spawnEnemy = EnemySystem.spawnEnemy;

  spawnBoss = EnemySystem.spawnBoss;

  spawnNode = EnemySystem.spawnNode;

  targets = Targeting.targets;

  priority = Targeting.priority;

  input = Targeting.input;

  cycle = Targeting.cycle;

  clickTarget = Targeting.clickTarget;

  cancel = Targeting.cancel;

  cast = CastSystem.cast;

  afterCast = CastSystem.afterCast;

  applyCold = StatusSystem.applyCold;

  chain = StatusSystem.chain;

  damage = DamageSystem.damage;

  kill = DamageSystem.kill;

  explode = DamageSystem.explode;

  gainXP = DamageSystem.gainXP;

  heal = DamageSystem.heal;

  payBloodPrice = DamageSystem.payBloodPrice;

  triggerNode = EnemySystem.triggerNode;

  clearBullets = ProjectileSystem.clearBullets;

  hurt = DamageSystem.hurt;

  findSafe = MovementSystem.findSafe;

  dodge = MovementSystem.dodge;
  parry = DefenseSystem.parry;
  parryContact = DefenseSystem.parryContact;
  reflectBullet = DefenseSystem.reflectBullet;
  parryFeedback = DefenseSystem.parryFeedback;
  counterHit = DefenseSystem.counterHit;
  inAttackRange = inAttackRange;

  fire = ProjectileSystem.fire;

  bullet = ProjectileSystem.bullet;

  laser = ProjectileSystem.laser;

  bossAttack = EnemySystem.bossAttack;

  update(dt: number) {
    if (this.state !== "playing") return;
    const realDt = dt,
      precisionDt = Math.min(dt, this.precisionTime);
    dt -= precisionDt * 0.9;
    dt = Math.min(dt, counterWorldDelta(this.counterSlowTime, realDt));
    this.counterSlowTime = Math.max(0, this.counterSlowTime - realDt);
    this.elapsed += realDt;
    this.time += dt;
    this.roomTime += dt;
    this.sound.ambient(dt, this.content.chapters[this.chapter].ambience ?? 1);
    this.pressure = difficulty(
      this.mode,
      this.stage,
      this.roomTime,
      this.roomMod === "elite",
      this.campaign.at(this.stage),
    );
    const p = this.player;
    p.invuln = Math.max(0, p.invuln - realDt);
    p.parryCooldown = Math.max(0, p.parryCooldown - realDt);
    p.dash = Math.min(p.maxDash, p.dash + realDt / this.getDashCooldown());
    if (this.godMode) {
      p.dash = p.maxDash;
      this.resonance = 100;
    }
    p.recoil *= Math.exp(-dt * 13);
    this.chargePulse = Math.max(0, this.chargePulse - dt * 5);
    this.stopCooldown = Math.max(0, this.stopCooldown - dt);
    if (this.decoy) this.decoy.life -= dt;
    this.updatePlayer(realDt, precisionDt);
    this.precisionTime = Math.max(0, this.precisionTime - realDt);
    if (precisionDt > 0 && this.precisionTime === 0)
      for (const k of ["w", "a", "s", "d"]) delete this.aimKeys[k];
    this.scheduler.tick(
      this.time,
      (id) => this.enemies.some((e) => e.id === id && this.canEnemyAct(e)),
      () => this.roomEnded,
    );
    this.updateEncounter(dt);
    this.updateFields(dt);
    this.updateEnemies(dt);
    this.resolveBodies(dt);
    this.updateShots(dt);
    this.updateBullets(dt);
    this.updateHazards(dt);
    p.parryTime = Math.max(0, p.parryTime - realDt);
    this.updateSpirits(dt);
    for (const n of this.nodes) {
      n.age += dt;
      if (n.age > n.life && this.target !== n) n.dead = true;
    }
    if (this.ultimateTime > 0) {
      this.ultimateTime = Math.max(0, this.ultimateTime - dt);
      this.ultTick -= dt;
      this.bookBehavior.tick?.(this);
    }
    this.bullets = this.bullets.filter((b) => !b.dead);
    this.shots = this.shots.filter((b) => !b.dead);
    this.lasers = this.lasers.filter((l) => !l.dead);
    this.blasts = this.blasts.filter((b) => !b.dead);
    this.enemies = this.enemies.filter((e) => !e.dead);
    this.nodes = this.nodes.filter((n) => !n.dead);
    if (this.target?.dead) this.cancel();
    this.safeClock -= dt;
    if (this.safeClock <= 0) {
      const d = dodgeDirection(this.aimKeys);
      this.safePoint = d.x || d.y ? this.findSafe() : null;
      this.safeClock = 0.18;
    }
    if (this.finishEncounter(dt)) return;
    this.postCombat();
  }

  postCombat = RewardSystem.postCombat;

  upgradeChoices = RewardSystem.upgradeChoices;

  canUpgrade = RewardSystem.canUpgrade;

  chooseUpgrade = RewardSystem.chooseUpgrade;

  completeRoom = RewardSystem.completeRoom;

  chooseRoute = RewardSystem.chooseRoute;

  pause() {
    if (this.state !== "playing") return;
    this.aimKeys = {};
    this.setState("paused");
    this.emit("pause");
  }

  resume() {
    if (this.state !== "paused") return;
    this.setState("playing");
    this.emit("resume");
  }

  end(win: boolean, reason: "defeat" | "abandoned" = "defeat") {
    if (this.state === "result" || this.state === "home") return;
    this.lastWin = win;
    this.cancel(false);
    this.setState("result");
    this.sound.result(win);
    this.emit("result", {
      schemaVersion: 2,
      runId: this.runId,
      settlementId: `${this.runId}:${this.loopCount}`,
      endedAt: new Date().toISOString(),
      outcome: win ? "victory" : reason,
      chapterName: this.content.chapters[this.chapter].name,
      room: this.roomNumber + 1,
      roomCount: this.campaign.at(this.activeStage).definition.rooms.length,
      roomId: this.campaign.at(this.activeStage).room.id,
      bossRoom: this.bossRoom,
      bossName: this.bossRoom ? this.bossName : undefined,
      bossPhase: this.boss?.phase,
      wave: this.wave,
      waveCount: this.waveCount,
      level: this.level,
      damage: Math.round(this.totalDamage),
      hp: Math.max(0, this.player.hp),
      maxHp: this.player.maxHp,
      godMode: this.godMode,
      version: "0.6.1",
      win,
      chapter: this.chapter + 1,
      stage: this.activeStage,
      loop: this.loopCount,
      kills: this.kills,
      casts: this.casts,
      correct: this.correct,
      errors: this.errors,
      accuracy: this.correct / Math.max(1, this.typedTotal),
      wpm: this.correct / 5 / (Math.max(1, this.elapsed) / 60),
      elapsed: this.elapsed,
      maxCombo: this.maxCombo,
      dashes: this.dashes,
      reflections: this.reflections,
      ultimates: this.ultimates,
      perfectDodges: this.perfectDodges,
      grazes: this.grazes,
      wallHits: this.wallHits,
      overloads: this.overloads,
      relics: { ...this.relics },
      words: Object.fromEntries(Object.entries(this.wordStats).map(([word, stat]) => [word, { ...stat }])),
      seed: this.config.seed,
      book: this.book,
      mode: this.config.mode,
      vocab: this.config.vocabTitle,
    });
  }

  home() {
    this.setState("home");
    this.resetArrays();
    this.cancel(false);
    this.ultimateTime = 0;
    this.hitStop = 0;
    this.counterSlowTime = 0;
  }

  spiritPosition = SummonSystem.spiritPosition;

  sparks = PresentationSystem.sparks;

  ring = PresentationSystem.ring;

  line = PresentationSystem.line;

  floating = PresentationSystem.floating;

  updateVisual = PresentationSystem.updateVisual;

  resetArrays() {
    WordReservations.cancel(this.shots ?? [], this.enemies ?? []);
    this.particlePool ??= [];
    for (const p of this.particles || [])
      if (this.particlePool.length < 760) this.particlePool.push(p);
    this.enemies = [];
    this.nodes = [];
    this.bullets = [];
    this.shots = [];
    this.fields = [];
    this.blasts = [];
    this.tasks = [];
    this.corpses = [];
    this.spirits = [];
    this.fx = [];
    this.particles = [];
    this.lasers = [];
    this.trails = [];
    this.decals = [];
  }

  releaseKey = Targeting.releaseKey;

  damageMultiplier() {
    return this.relicRules.damageMultiplier(this);
  }

  schedule(
    delay: number,
    fn: () => void,
    source: number | null = null,
    options: { blocksClear?: boolean } = {},
  ) {
    this.scheduler.schedule(this.time, delay, fn, source, options);
  }

  nearest(origin: Point, exclude = new Set<number>(), radius = Infinity) {
    return this.enemies
      .filter((e) => !e.dead && !exclude.has(e.id) && dist(e, origin) < radius)
      .sort((a, b) => dist(a, origin) - dist(b, origin))[0];
  }

  launchShot = ProjectileSystem.launchShot;

  releaseShot = ProjectileSystem.releaseShot;

  strike = StatusSystem.strike;

  conduct = StatusSystem.conduct;

  crossSlash = StatusSystem.crossSlash;

  strikeDown = StatusSystem.strikeDown;

  impulse = MovementSystem.impulse;

  pull = MovementSystem.pull;

  addResonance = CastSystem.addResonance;

  ultimate = CastSystem.ultimate;

  getDashCooldown = MovementSystem.getDashCooldown;

  finishDodge = MovementSystem.finishDodge;

  makeBlast = ProjectileSystem.makeBlast;

  enemyAttack = EnemySystem.enemyAttack;

  allowedEnemies() {
    const room = this.campaign.at(this.stage).room;
    return [
      ...(room.easyEnemies && this.mode.rank < room.easyEnemies.belowRank
        ? room.easyEnemies.pool
        : room.enemies),
    ];
  }

  updatePlayer = MovementSystem.updatePlayer;

  addField = StatusSystem.addField;

  updateFields = StatusSystem.updateFields;

  updateEnemies = EnemySystem.updateEnemies;

  resolveBodies = MovementSystem.resolveBodies;

  updateShots = ProjectileSystem.updateShots;

  updateBullets = ProjectileSystem.updateBullets;

  updateHazards = ProjectileSystem.updateHazards;

  updateSpirits = SummonSystem.updateSpirits;

  rerollUpgrade = RewardSystem.rerollUpgrade;

  continueLoop = RewardSystem.continueLoop;

  arc = PresentationSystem.arc;

  burst = PresentationSystem.burst;

  impact = PresentationSystem.impact;

  makeDebris = PresentationSystem.makeDebris;

  invalidate() {
    this.renderDirty = true;
  }
  destroy() {
    this.destroyed = true;
    this.events = {};
    this.resetArrays();
    this.domainEvents.reset();
    this.presentationCues.reset();
  }
}
