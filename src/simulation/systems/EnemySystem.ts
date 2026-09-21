import { clearArena } from "../../shared/arena.ts";
import { AMBUSH_CHANCE, assaultEntry } from "../../shared/assault.ts";
import type { EnemyActionContext } from "../../content-sdk/EnemyBehavior.ts";

import { enemyDefaults } from "../../combat/model.ts";
import type { Point, Enemy, RuneNode } from "../../combat/model.ts";
import * as C from "../../shared/math.ts";

const { clamp, pick, random, hash } = C;
const W = 1280,
  H = 800,
  TAU = Math.PI * 2,
  ENTITY_SCALE = 0.66;
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);

import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<
  CombatRuntime,
  | "canEnemyAct"
  | "inAttackRange"
  | "parryContact"
  | "eliteProfile"
  | "updateEnemyStatus"
  | "stats"
  | "bossDefinition"
  | "updateBossPhase"
  | keyof EnemyActionContext
  | "addResonance"
  | "applyCold"
  | "arc"
  | "arena"
  | "blasts"
  | "boss"
  | "bossAttack"
  | "bossName"
  | "burst"
  | "chapter"
  | "clearBullets"
  | "content"
  | "damage"
  | "decoy"
  | "emit"
  | "enemies"
  | "enemyAttack"
  | "enemyProfile"
  | "explode"
  | "fields"
  | "fire"
  | "floating"
  | "gainXP"
  | "hurt"
  | "id"
  | "impact"
  | "impulse"
  | "laser"
  | "lasers"
  | "loopCount"
  | "makeBlast"
  | "mode"
  | "nodes"
  | "player"
  | "pressure"
  | "reflectionBoost"
  | "reflections"
  | "relics"
  | "ring"
  | "rng"
  | "roomEnded"
  | "schedule"
  | "sound"
  | "spawnEnemy"
  | "stage"
  | "target"
  | "wallHits"
  | "wave"
  | "assaultDirection"
  | "wordFor"
>;

export function spawnEnemy(
  this: Context,
  type: string,
  x?: number,
  y?: number,
  small = false,
  force = false,
) {
  if (
    this.roomEnded ||
    (!force &&
      this.enemies.filter((e) => !e.dead && !e.boss).length >=
        (this.pressure?.cap || 10))
  )
    return null;
  const t = this.content.enemies[type] || this.content.enemies.nib,
    w = this.wordFor(!!t.behavior.longWord);
  let approachDirection: number | undefined;
  let ambush = false;
  if (x == null) {
    ambush = !small && this.rng() < AMBUSH_CHANCE;
    approachDirection = ambush
      ? (this.assaultDirection + 1 + Math.floor(this.rng() * 7)) % 8
      : this.assaultDirection;
    ({ x, y } = assaultEntry(this.arena, approachDirection, this.rng()));
  }
  y ??= this.arena.t + 28;
  const eliteRoll = this.rng();
  const elite =
    !small &&
    t.behavior.eliteEligible !== false &&
    !(this.stage === 0 && this.wave === 1) &&
    Object.keys(this.content.elites).length > 0 &&
    eliteRoll < (this.pressure?.elite || 0)
      ? pick(Object.keys(this.content.elites), this.rng)
      : null;
  const traits = elite ? this.content.elites[elite] : undefined;
  const health =
    t.hp *
    (this.pressure?.health || 1) *
    (small ? 0.57 : 1) *
    (traits?.health ?? 1);
  const e: Enemy = {
    ...enemyDefaults(),
    approachDirection,
    ambush,
    id: ++this.id,
    type,
    countsForClear: t.behavior.countsForClear !== false,
    ...w,
    x: clamp(x, this.arena.l + 20, this.arena.r - 20),
    y: clamp(y, this.arena.t + 20, this.arena.b - 20),
    px: x,
    py: y,
    r: t.r * (small ? 0.73 : 1) * ENTITY_SCALE,
    hp: health,
    maxHp: health,
    speed: t.speed * (small ? 1.18 : 1),
    mass: (t.mass || 1) * (small ? 0.55 : 1) * (traits?.mass ?? 1),
    vx: 0,
    vy: 0,
    ix: 0,
    iy: 0,
    angle: 0,
    tilt: 0,
    squash: 0,
    dead: false,
    age: 0,
    grace: this.mode.rank >= 2 ? 0.78 : 1.12,
    shoot: (0.72 + this.rng() * 0.6) * this.mode.window,
    chill: 0,
    freeze: 0,
    flash: 0,
    small,
    phase: this.rng() * TAU,
    elite,
    stun: 0,
    impactTime: 0,
    collisionCD: 0,
    poise: 0,
    conduct: 0,
    dot: 0,
    dotStacks: 0,
    dotTick: 1,
    mark: 0,
    windup: 0,
    charge: 0,
    mirror: 1,
    mirrortime: 5,
    spawnCount: 0,
  };
  this.enemies.push(e);
  this.ring(e.x, e.y, e.r + 16, t.color, 0.65);
  return e;
}

export function spawnBoss(this: Context) {
  const w = this.wordFor(true),
    hp =
      this.bossDefinition().health[this.mode.rank] *
      Math.pow(
        this.bossDefinition().growth,
        this.chapter + this.loopCount * this.content.chapters.length,
      ) *
      (this.pressure.trialHealth || 1);
  const b: Enemy = {
    ...enemyDefaults(),
    id: ++this.id,
    type: "boss",
    bossId: this.bossDefinition().id,
    boss: true,
    ...w,
    x: 640,
    y: 245,
    r: 54 * ENTITY_SCALE,
    hp,
    maxHp: hp,
    age: 0,
    grace: 2.2,
    shoot: 2.6,
    freeze: 0,
    chill: 0,
    flash: 0,
    phase: 1,
    phaseBefore: 1,
    towerSpawned: false,
    mass: 9,
    vx: 0,
    vy: 0,
    ix: 0,
    iy: 0,
    squash: 0,
    tilt: 0,
    stun: 0,
    conduct: 0,
    poise: 0,
    mark: 0,
    dot: 0,
    dotStacks: 0,
    dotTick: 1,
    collisionCD: 0,
    impactTime: 0,
    attackIndex: 0,
  };
  this.enemies.push(b);
  this.boss = b;
}

export function spawnNode(
  this: Context,
  kind: "rune" | "ink" = "rune",
  source: Enemy | null = null,
) {
  if (this.roomEnded) return null;
  if (this.nodes.filter((n) => !n.dead).length >= 3) return null;
  const w = this.wordFor(false);
  let x = this.arena.l + 110 + this.rng() * (this.arena.r - this.arena.l - 220),
    y = this.arena.t + 100 + this.rng() * (this.arena.b - this.arena.t - 180);
  if (source) {
    x = clamp(
      (source.x + this.player.x) * 0.5 + (this.rng() - 0.5) * 120,
      this.arena.l + 60,
      this.arena.r - 60,
    );
    y = clamp(
      (source.y + this.player.y) * 0.5,
      this.arena.t + 60,
      this.arena.b - 60,
    );
  }
  const safe = clearArena(this.arena, 32);
  x = clamp(x, safe.l, safe.r);
  y = clamp(y, safe.t, safe.b);
  const node: RuneNode = {
    boss: false,
    type: "node",
    hp: 0,
    maxHp: 0,
    grace: 0,
    pendingHits: 0,
    wordPending: false,
    phaseLock: 0,
    id: ++this.id,
    kind,
    ...w,
    x,
    y,
    r: 13,
    dead: false,
    age: 0,
    life: kind === "rune" ? 15 : 24,
    source: source?.id || null,
    phase: this.rng() * TAU,
  };
  this.nodes.push(node);
  return node;
}

export function bossAttack(this: Context, b: Enemy) {
  if (!this.canEnemyAct(b)) return;
  b.attackIndex++;
  const phase = b.phase,
    index = b.attackIndex;
  this.content.bossBehaviors[this.bossDefinition().behavior](this, b);
  if (
    phase >= 2 &&
    this.enemies.filter(
      (e) => !e.dead && !e.boss && !this.enemyProfile(e).stationary,
    ).length <
      2 + this.mode.rank
  ) {
    this.spawnEnemy(this.bossDefinition().reinforcement);
  }
  b.shoot = Math.max(1.45, (phase === 3 ? 2.5 : 3.2) * this.pressure.attack);
}

export function enemyAttack(this: Context, e: Enemy) {
  if (!this.canEnemyAct(e) || !this.inAttackRange(e)) return;
  const profile = this.enemyProfile(e),
    action = this.content.enemyActions[profile.attack];
  if (!action) throw new Error(`Unknown enemy attack ${profile.attack}`);
  action(this, e);
  if (this.eliteProfile(e)?.echoDelay && !profile.chargeSpeed)
    this.schedule(
      this.eliteProfile(e)!.echoDelay!,
      () => {
        if (!e.dead) this.fire(e, "fan", { speed: 0.88 });
      },
      e.id,
    );
  e.shoot =
    (profile.cooldown ?? 3 + this.rng() * 1.2) *
    this.pressure.attack *
    (this.eliteProfile(e)?.cooldown ?? 1);
}

export function updateEnemies(this: Context, dt: number) {
  const p = this.player,
    a = this.arena,
    slowBook = this.target && this.stats.aimingSlow ? 0.82 : 1;
  const binders = this.enemies.filter(
    (e) =>
      this.canEnemyAct(e) && this.enemyProfile(e).hasteAura && e.grace <= 0,
  );
  for (const e of this.enemies) {
    if (e.dead) continue;
    this.updateEnemyStatus(e, dt);
    if (e.dead) continue;
    const canAct = this.canEnemyAct(e);
    if (!canAct) {
      e.windup = 0;
      e.charge = 0;
      e.shoot = Math.max(e.shoot, 0.65);
    }
    let sf = slowBook * (e.freeze > 0 ? (e.boss ? 0.64 : 0.04) : 1);
    if (this.fields.some((f) => f.kind === "frost" && dist(e, f) < f.r))
      sf *= 0.55;
    if (binders.some((b) => b !== e && dist(e, b) < 220)) sf *= 1.18;
    sf *= this.eliteProfile(e)?.speed ?? 1;
    if (canAct && this.enemyProfile(e).mirror) {
      e.mirrortime -= dt;
      if (e.mirrortime <= 0) {
        e.mirror = 1;
        e.mirrortime = 6;
      }
    }
    let tx = 0,
      ty = 0;
    if (e.boss) {
      if (canAct) this.updateBossPhase(e);
      tx =
        (640 +
          Math.sin(e.age * 0.32) * this.bossDefinition().movementRadius -
          e.x) *
        1.5;
      ty = (260 + Math.cos(e.age * 0.44) * 24 - e.y) * 1.5;
      if (e.grace <= 0) {
        e.shoot -= dt * sf;
        if (e.shoot <= 0) this.bossAttack(e);
      }
    } else if (e.grace <= 0) {
      const pursuit = this.decoy && this.decoy.life > 0 ? this.decoy : p;
      const safe = clearArena(a, 30);
      const target = canAct
        ? pursuit
        : {
            x: clamp(pursuit.x, safe.l, safe.r),
            y: clamp(pursuit.y, safe.t, safe.b),
          };
      const dx = target.x - e.x,
        dy = target.y - e.y,
        d = Math.hypot(dx, dy) || 1;
      const profile = this.enemyProfile(e),
        ranged = profile.ranged;
      let speed =
        (canAct && (!this.enemyProfile(e).stationary || this.inAttackRange(e))
          ? e.speed
          : Math.max(65, e.speed)) *
        this.pressure.speed *
        sf;
      if (e.stun > 0) speed = 0;
      if (e.windup > 0) {
        e.windup -= dt * sf;
        speed = 0;
        if (e.windup <= 0 && e.freeze <= 0) {
          e.charge = 0.53;
          const dd = Math.hypot(e.aimX - e.x, e.aimY - e.y) || 1;
          e.cx = (e.aimX - e.x) / dd;
          e.cy = (e.aimY - e.y) / dd;
          this.sound.charge(e);
        }
      }
      if (e.charge > 0) {
        e.charge -= dt;
        tx =
          e.cx *
          (profile.chargeSpeed || 465) *
          Math.min(1.35, this.pressure.speed);
        ty =
          e.cy *
          (profile.chargeSpeed || 465) *
          Math.min(1.35, this.pressure.speed);
        if (e.charge <= 0) e.stun = 0.6;
      } else if (
        !this.enemyProfile(e).stationary ||
        !canAct ||
        !this.inAttackRange(e)
      ) {
        const direction =
          !canAct || (profile.stationary && !this.inAttackRange(e))
            ? 1
            : ranged
              ? d > Math.min(275, (profile.attackRange ?? 310) * 0.88)
                ? 1
                : d < Math.min(190, (profile.attackRange ?? 310) * 0.6)
                  ? -0.6
                  : 0
              : 1;
        tx = (dx / d) * speed * direction;
        ty = (dy / d) * speed * direction;
        if (profile.weave) {
          tx += (-dy / d) * Math.sin(e.age * 2.3 + e.phase) * speed * 0.75;
          ty += (dx / d) * Math.sin(e.age * 2.3 + e.phase) * speed * 0.75;
        }
        if (
          canAct &&
          this.enemyProfile(e).pullAura &&
          d < 230 &&
          !p.dashState
        ) {
          p.vx += (-dx / d) * dt * 45;
          p.vy += (-dy / d) * dt * 45;
        }
      }
      if (
        canAct &&
        this.inAttackRange(e) &&
        e.stun <= 0 &&
        e.windup <= 0 &&
        e.charge <= 0
      ) {
        e.shoot -= dt * sf;
        if (e.shoot <= 0) this.enemyAttack(e);
      }
    }
    const lerp = 1 - Math.exp(-dt * (e.charge > 0 ? 25 : 5));
    e.vx += (tx - e.vx) * lerp;
    e.vy += (ty - e.vy) * lerp;
    e.px = e.x;
    e.py = e.y;
    e.x += (e.vx + e.ix) * dt;
    e.y += (e.vy + e.iy) * dt;
    const drag = (e.counterPushTime || 0) > 0 ? 2.8 : 4.4;
    e.ix *= Math.exp(-dt * drag);
    e.iy *= Math.exp(-dt * drag);
    e.tilt = clamp((e.vx + e.ix) * 0.00055, -0.24, 0.24);
    const wallX = e.x < a.l + e.r * 0.7 || e.x > a.r - e.r * 0.7,
      wallY = e.y < a.t + e.r * 0.7 || e.y > a.b - e.r * 0.7;
    if (wallX || wallY) {
      const velocity = wallX ? Math.abs(e.ix + e.vx) : Math.abs(e.iy + e.vy);
      if (wallX) {
        e.ix = -e.ix * 0.43;
        e.vx *= -0.25;
      }
      if (wallY) {
        e.iy = -e.iy * 0.43;
        e.vy *= -0.25;
      }
      if (e.charge > 0) {
        e.charge = 0;
        e.stun = 0.85;
      }
      if (
        velocity > 155 &&
        e.impactTime > 0 &&
        !e.counterPushTime &&
        e.collisionCD <= 0 &&
        !e.boss
      ) {
        this.wallHits++;
        e.collisionCD = 0.4;
        this.damage(
          e,
          (7 + velocity * 0.022) * (this.stats.impulsePower ? 2 : 1),
          1,
          false,
        );
        this.impact(e.x, e.y, "wall", 1.1);
        this.floating(e.x, e.y - 40, "撞击", "#ffdaa1", 12);
      }
    }
    e.x = clamp(e.x, a.l + e.r * 0.7, a.r - e.r * 0.7);
    e.y = clamp(e.y, a.t + e.r * 0.7, a.b - e.r * 0.7);
    if (
      this.canEnemyAct(e) &&
      e.grace <= 0 &&
      !e.counterPushTime &&
      dist(e, p) < e.r + p.r
    ) {
      if (this.parryContact(e)) continue;
      this.hurt(
        (this.enemyProfile(e).contactDamage ?? 12) * this.pressure.damage,
        e,
      );
      this.impulse(e, p, 220);
      if (
        !!this.enemyProfile(e).chargeDrain &&
        p.invuln < this.mode.iframe * 0.99
      )
        p.dash = Math.max(
          0,
          p.dash - dt * (this.enemyProfile(e).chargeDrain ?? 0),
        );
    }
  }
}

export function triggerNode(this: Context, n: RuneNode) {
  this.sound.pickup(n);
  n.dead = true;
  this.gainXP(3);
  this.addResonance(5);
  this.burst(
    n.x,
    n.y,
    n.kind === "rune" ? 220 : 165,
    n.kind === "rune" ? "#93f4d0" : "#ffcc83",
    "shock",
  );
  if (n.kind === "rune") {
    this.reflections++;
    const count = this.clearBullets(n.x, n.y, 245);
    const dmg =
      (30 + Math.min(count, 22) * 4) * (this.stats.reflectPower ? 1.6 : 1);
    const targets = this.enemies
      .filter((e) => !e.dead)
      .sort((a, b) => dist(a, n) - dist(b, n))
      .slice(0, 4);
    for (const e of targets) {
      this.arc(n, e, "#a8f8d8", 5, 0.45);
      this.impulse(e, n, 240);
      this.applyCold(e);
      this.damage(e, dmg, 0, false, n);
    }
    if (this.stats.reflectPower) this.reflectionBoost = true;
    this.floating(n.x, n.y - 38, "反制 ×" + count, "#a7f3d0", 19);
    this.lasers = this.lasers.filter((l) => l.warning <= 0);
    this.blasts = this.blasts.filter((b) => b.warning <= 0);
    this.sound.reflect(n);
  } else {
    this.clearBullets(n.x, n.y, 170);
    this.explode(n.x, n.y, 180, 95, null, 0, "#f9ca86");
    this.floating(n.x, n.y - 34, "爆墨", "#f8d29b", 20);
    this.sound.impact("blast", 1.5, n);
  }
}
