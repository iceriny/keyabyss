/** Explicit capability vocabulary shared by combat systems. No concrete session implementation. */
import type { ScheduledTask } from "./TaskScheduler.ts";
import type { RelicRules } from "./RelicRules.ts";
import type { Campaign } from "./progression/Campaign.ts";
import type {
  Config,
  Settings,
  BookId,
  Mode,
  Book,
  GameState,
  GameEvents,
  Relic,
  Route,
} from "../contracts/game.ts";
import type { WordPool as WordPoolType } from "../vocabulary/index.ts";
import type { difficulty } from "./progression/difficulty.ts";
import type { SimulationContent } from "../contracts/SimulationContent.ts";
import type {
  Point,
  Arena,
  Enemy,
  RuneNode,
  CombatTarget,
  Player,
  Bullet,
  BulletOptions,
  Laser,
  Blast,
  Shot,
  SpellOptions,
  Field,
  Particle,
  Debris,
  Decal,
  Trail,
  Spirit,
  VisualEffect,
} from "../combat/model.ts";
import type { FeedbackPort } from "../contracts/feedback.ts";
export interface WorldState {
  afterUpgrade: "route" | "clear" | "play" | null;
  aimKeys: Record<string, boolean>;
  arena: Arena;
  godMode: boolean;
  canEnemyAct(enemy: Enemy): boolean;
  activateGodMode(): void;
  autofill: boolean;
  blasts: Blast[];
  bloodPaidStage: number | null;
  book: BookId;
  bookCounter: number;
  bookData: Book;
  boss: Enemy | null;
  bossRoom: boolean;
  bullets: Bullet[];
  castError: boolean;
  casts: number;
  chapter: number;
  chargePulse: number;
  clearDelay: number;
  combo: number;
  config: Config;
  corpses: Debris[];
  correct: number;
  dashes: number;
  decals: Decal[];
  decoy:
    | (Point & {
        life: number;
      })
    | null;
  destroyed: boolean;
  elapsed: number;
  enemies: Enemy[];
  entityScale: number;
  errors: number;
  events: GameEvents;
  fields: Field[];
  focusId: number | null;
  fx: VisualEffect[];
  fxRng: () => number;
  grazes: number;
  hitFlash: number;
  hitStop: number;
  counterSlowTime: number;
  id: number;
  kickX: number;
  kickY: number;
  kills: number;
  lasers: Laser[];
  lastWin: boolean;
  level: number;
  loopCount: number;
  manual: number;
  maxCombo: number;
  mode: Mode;
  nextXP: number;
  nodeClock: number;
  nodes: RuneNode[];
  options: Settings;
  overloads: number;
  particles: Particle[];
  pending: number;
  perfectDodges: number;
  perfectWords: number;
  player: Player;
  pool: WordPoolType;
  precisionTime: number;
  prefix: string;
  pressure: ReturnType<typeof difficulty>;
  queuedRoute: Route;
  reflectionBoost: boolean;
  reflections: number;
  relics: Record<string, number>;
  renderDirty: boolean;
  rerolls: number;
  rescued: boolean;
  resonance: number;
  rng: () => number;
  roomDuration: number;
  roomEnded: boolean;
  roomKills: number;
  roomMod: string;
  roomNumber: number;
  roomQuota: number;
  roomTime: number;
  safeClock: number;
  safePoint: Point | null;
  shake: number;
  shots: Shot[];
  sound: FeedbackPort;
  spawnClock: number;
  spawned: number;
  spiritShoot: number;
  spiritTime: number;
  awakenedSpirits: number;
  spirits: Spirit[];
  stage: number;
  state: GameState;
  stopCooldown: number;
  target: CombatTarget | null;
  time: number;
  totalDamage: number;
  trails: Trail[];
  typedTotal: number;
  ultTick: number;
  ultimateTime: number;
  ultimates: number;
  upgradeAt: number;
  visualTime: number;
  wallHits: number;
  wave: number;
  assaultDirection: number;
  waveRest: number;
  waveWaiting: boolean;
  wordStats: Record<
    string,
    {
      done: number;
      errors: number;
      meaning?: string;
    }
  >;
  xp: number;
  particlePool: Particle[];
}
export interface CombatSimulation extends WorldState {}
export interface CombatRuntime extends WorldState {
  parry(): void;
  parryFeedback(): void;
  parryContact(enemy: Enemy): boolean;
  reflectBullet(bullet: Bullet): void;
  counterHit(enemy: Enemy, damage?: number): void;
  inAttackRange(enemy: Enemy): boolean;
  applyBurn(enemy: Enemy, stacks?: number, spreadDepth?: number): void;
  igniteExplosion(
    x: number,
    y: number,
    radius: number,
    damage: number,
    exclude?: Enemy | null,
    depth?: number,
    stacks?: number,
  ): void;
  fireImpact(enemy: Enemy, damage: number, options: SpellOptions): void;
  tickBurn(enemy: Enemy, dt: number): void;
  spreadBurn(enemy: Enemy): void;
  tickFireField(field: Field, dt: number): void;
  effectSource(entity?: number): import("../contracts/effects.ts").EffectSource;
  applyEffect(
    request: import("../contracts/effects.ts").EffectRequest,
  ): boolean;
  readonly pendingRequiredTasks: boolean;
  readonly domainEvents: import("./EventJournal.ts").EventJournal<
    import("../contracts/events.ts").DomainEvent
  >;
  readonly presentationCues: import("./EventJournal.ts").EventJournal<
    import("../contracts/events.ts").PresentationCue
  >;
  roomVisit: number;
  updateEncounter(dt: number): void;
  finishEncounter(dt: number): boolean;
  readonly stats: import("../contracts/stats.ts").CombatStats;
  bossDefinition(): import("../contracts/content.ts").BossDefinition;
  updateBossPhase(enemy: Enemy): void;
  readonly campaign: Campaign;
  get tasks(): ScheduledTask[];
  set tasks(tasks: ScheduledTask[]);
  readonly relicRules: RelicRules;
  readonly content: SimulationContent;
  updateEnemyStatus(e: Enemy, dt: number): void;
  eliteProfile(
    e: Enemy,
  ): import("../contracts/content.ts").EliteDefinition | undefined;
  enemyProfile(e: Enemy): import("../contracts/content.ts").EnemyProfile;
  get bookBehavior(): import("../content-sdk/BookBehavior.ts").BookBehavior;
  waveCount: number;
  routeOffers: readonly import("../contracts/content.ts").RouteDefinition[];
  routeDestinations: Record<string, number>;
  get roomCount(): number;
  get chapterName(): string;
  get bossName(): string;
  get nextRoomIsBoss(): boolean;
  emit<K extends keyof GameEvents>(
    name: K,
    ...args: Parameters<NonNullable<GameEvents[K]>>
  ): void;
  setState(s: GameState): void;
  start(config: Config): void;
  beginRoom(route?: Route): void;
  wordFor(
    extra?: boolean,
    exclude?: CombatTarget | null,
  ): import("../contracts/game.ts").Word;
  spawnEnemy(
    type: string,
    x?: number,
    y?: number,
    small?: boolean,
    force?: boolean,
  ): Enemy | null;
  spawnBoss(): void;
  spawnNode(kind?: "rune" | "ink", source?: Enemy | null): RuneNode | null;
  targets(): (Enemy | RuneNode)[];
  priority(t: CombatTarget): number;
  input(key: string): boolean;
  cycle(direction?: number): void;
  clickTarget(x: number, y: number, targetId?: number): void;
  cancel(notify?: boolean): void;
  cast(t: CombatTarget, perfect?: boolean, auto?: boolean): void;
  afterCast(t: CombatTarget, perfect: boolean): void;
  applyCold(e: Enemy, amount?: number | null): void;
  chain(origin: Enemy, dmg: number, count: number): void;
  damage(
    e: Enemy,
    dmg: number,
    depth?: number,
    direct?: boolean,
    from?: Point | null,
  ): void;
  kill(e: Enemy, depth?: number): void;
  explode(
    x: number,
    y: number,
    r: number,
    dmg: number,
    except?: Enemy | null,
    depth?: number,
    color?: string,
    cold?: boolean,
  ): void;
  gainXP(n: number): void;
  heal(n: number): void;
  payBloodPrice(): void;
  triggerNode(n: RuneNode): void;
  clearBullets(x: number, y: number, r: number): number;
  hurt(amount: number, source?: Point | null): void;
  findSafe():
    | {
        x: number;
        y: number;
        manual: boolean;
      }
    | {
        x: number;
        y: number;
      };
  dodge(): void;
  fire(e: Enemy, pattern?: string, extra?: BulletOptions): void;
  bullet(
    x: number,
    y: number,
    a: number,
    speed: number,
    color: string,
    extra?: BulletOptions,
  ): {
    heavy?: boolean;
    curve?: number;
    accel?: number;
    source?: number;
    speed?: number;
    x: number;
    y: number;
    px: number;
    py: number;
    vx: number;
    vy: number;
    r: number;
    life: number;
    age: number;
    dead: boolean;
    color: string;
    grazed: boolean;
  } | null;
  laser(e: Enemy | null, boss?: boolean): void;
  bossAttack(b: Enemy): void;
  update(dt: number): void;
  postCombat(cleared?: boolean): void;
  upgradeChoices(): import("../contracts/rewards.ts").RewardChoice[];
  canUpgrade(r: Pick<Relic, "id" | "max"> & Partial<Relic>): boolean;
  chooseUpgrade(id: string): void;
  completeRoom(): void;
  chooseRoute(route: Route): void;
  pause(): void;
  resume(): void;
  end(win: boolean, reason?: "defeat" | "abandoned"): void;
  home(): void;
  spiritPosition(
    i: number,
    n: number,
  ): {
    x: number;
    y: number;
  };
  sparks(
    x: number,
    y: number,
    n: number,
    color: string,
    speed?: number,
    kind?: string,
  ): void;
  ring(x: number, y: number, r: number, color: string, life?: number): void;
  line(a: Point, b: Point, color: string, life?: number): void;
  floating(
    x: number,
    y: number,
    text: string,
    color: string,
    size?: number,
  ): void;
  updateVisual(dt: number): void;
  resetArrays(): void;
  releaseKey(key: string): void;
  damageMultiplier(): number;
  schedule(
    delay: number,
    fn: () => void,
    source?: number | null,
    options?: { blocksClear?: boolean },
  ): void;
  nearest(origin: Point, exclude?: Set<number>, radius?: number): Enemy;
  launchShot(
    from: Point,
    target: Enemy | undefined,
    kind: string,
    dmg: number,
    opts?: SpellOptions,
  ): void;
  releaseShot(s: Shot): void;
  strike(e: Enemy, dmg: number, opts?: SpellOptions): void;
  conduct(e: Enemy): void;
  crossSlash(target: Enemy | null, dmg: number): void;
  strikeDown(e: Enemy, dmg: number): void;
  impulse(e: Enemy, from: Point, force: number): void;
  pull(x: number, y: number, r: number, force: number): void;
  addResonance(n: number): void;
  ultimate(): void;
  getDashCooldown(): number;
  finishDodge(): void;
  makeBlast(
    x: number,
    y: number,
    r: number,
    warning?: number,
    source?: number | null,
    ring?: boolean,
  ): void;
  enemyAttack(e: Enemy): void;
  allowedEnemies(): string[];
  updatePlayer(dt: number, precisionDt?: number): void;
  addField(
    kind: string,
    x: number,
    y: number,
    r: number,
    life: number,
    ultimate?: boolean,
  ): void;
  updateFields(dt: number): void;
  updateEnemies(dt: number): void;
  resolveBodies(dt: number): void;
  updateShots(dt: number): void;
  updateBullets(dt: number): void;
  updateHazards(dt: number): void;
  updateSpirits(dt: number): void;
  rerollUpgrade(): void;
  continueLoop(): void;
  arc(a: Point, b: Point, color: string, width?: number, life?: number): void;
  burst(x: number, y: number, r: number, color: string, kind?: string): void;
  impact(
    x: number,
    y: number,
    kind: string,
    power?: number,
    from?: Point | null,
  ): void;
  makeDebris(e: Enemy, color: string): void;
  invalidate(): void;
  destroy(): void;
}
