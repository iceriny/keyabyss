import type { Point, Enemy, SpellOptions } from "../../combat/model.ts";
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
  | "applyBurn"
  | "fireImpact"
  | "tickBurn"
  | "tickFireField"
  | "combatValue"
  | "stats"
  | "addField"
  | "applyCold"
  | "arc"
  | "book"
  | "bookBehavior"
  | "burst"
  | "chapter"
  | "clearBullets"
  | "conduct"
  | "damage"
  | "damageMultiplier"
  | "enemies"
  | "explode"
  | "fields"
  | "floating"
  | "fx"
  | "fxRng"
  | "impact"
  | "impulse"
  | "kill"
  | "nearest"
  | "overloads"
  | "player"
  | "pull"
  | "relics"
  | "ring"
  | "sound"
  | "sparks"
  | "strike"
  | "totalDamage"
>;

export function applyCold(
  this: Context,
  e: Enemy,
  amount: number | null = null,
) {
  if (!e || e.dead) return;
  amount = amount ?? this.bookBehavior.cold + this.combatValue("cold.amount");
  if (!amount) return;
  e.chill = (e.chill || 0) + amount;
  if (e.chill >= 100) {
    e.chill = 0;
    e.freeze = Math.max(
      e.freeze || 0,
      this.combatValue("cold.duration", { boss: Number(e.boss) }),
    );
    e.windup = 0;
    if (!e.boss) e.charge = 0;
    this.ring(e.x, e.y, e.r + 15, "#a4e8ff", 0.4);
    this.sparks(e.x, e.y, 8, "#b5eaff", 85, "shard");
  }
}

export function conduct(this: Context, e: Enemy) {
  if (!e || e.dead) return;
  e.conduct = (e.conduct || 0) + 1;
  if (e.conduct < 3) return;
  e.conduct = 0;
  this.overloads++;
  const radius = this.stats.overloadPull ? 190 : 125,
    dmg =
      this.combatValue("overload.damage");
  if (this.stats.overloadPull) this.pull(e.x, e.y, radius + 50, 380);
  this.burst(e.x, e.y, radius, "#ffe1a1", "electric");
  this.damage(e, dmg, 1, false);
  this.explode(e.x, e.y, radius, dmg * 0.7, e, 1, "#fcd57b");
  if (this.stats.directConduction) this.clearBullets(e.x, e.y, 135);
  this.floating(e.x, e.y - 44, "过载", "#ffe3a4", 16);
  this.sound.overload(e);
}

export function chain(
  this: Context,
  origin: Enemy,
  dmg: number,
  count: number,
) {
  let from = origin,
    seen = new Set([origin.id]);
  for (let i = 0; i < count; i++) {
    const next = this.nearest(
      from,
      seen,
      this.combatValue("chain.radius"),
    );
    if (!next) break;
    seen.add(next.id);
    this.arc(from, next, "#ffdd94", 3.5, 0.34 + i * 0.015);
    this.strike(next, dmg, { from, kind: "storm", direct: false, depth: 1 });
    from = next;
    dmg *= this.combatValue("chain.retention");
  }
}

export function strike(
  this: Context,
  e: Enemy,
  dmg: number,
  opts: SpellOptions = {},
) {
  if (!e || e.dead) return;
  const frozen = e.freeze > 0;
  if (frozen) {
    dmg *= this.combatValue("frozen.multiplier");
    if (opts.empowered && opts.kind === "ice") dmg *= 1.25;
  }
  if (opts.kind === "fire")
    this.applyBurn(e, opts.empowered ? 2 : 1, opts.depth ?? 0);
  if (this.stats.execution && e.boss) dmg *= 1.15;
  if (opts.kind === "ice") this.applyCold(e, opts.direct ? 100 : 48);
  else if (this.stats.coldStacks) this.applyCold(e, this.combatValue("cold.amount"));
  if (opts.direct && this.stats.bleedStacks) {
    e.dot = 4;
    e.dotStacks = Math.min(3, (e.dotStacks || 0) + 1);
  }
  const origin = opts.from || this.player,
    force =
      (opts.kind === "ice"
        ? opts.empowered
          ? 530
          : 300
        : opts.kind === "blade"
          ? 190
          : 150) *
      this.combatValue("impulse.multiplier");
  this.impulse(e, origin, force);
  this.damage(e, dmg, opts.depth || 0, !!opts.direct, origin);
  if (opts.kind === "fire") this.fireImpact(e, dmg, opts);
  if (opts.kind === "storm" || (this.stats.directConduction && opts.direct))
    this.conduct(e);
  if (
    opts.direct &&
    this.stats.execution &&
    !e.dead &&
    !e.boss &&
    e.hp / e.maxHp < 0.18
  ) {
    this.floating(e.x, e.y - 44, "处决", "#ffc4af", 16);
    this.totalDamage += Math.max(0, e.hp);
    e.hp = 0;
    this.kill(e, 0);
  }
  if (opts.direct && (opts.kind === "ice" || this.stats.frostField))
    this.addField(
      "frost",
      e.x,
      e.y,
      (opts.empowered ? 114 : 75) + (this.stats.frostField ? 35 : 0),
      2.6 + (this.stats.frostField ? 3 : 0),
    );
  if (opts.direct && this.stats.gravityOnHit) {
    this.pull(e.x, e.y, 190, 260);
    this.burst(e.x, e.y, 175, "#aeb1ff", "implosion");
  }
  if (opts.direct && this.stats.hitExplosion)
    this.explode(
      e.x,
      e.y,
      this.combatValue("blast.radius"),
      this.combatValue("blast.damage", { hitDamage: dmg }),
      e,
      1,
      "#edba80",
    );
  if (opts.empowered && this.stats.empoweredFreeze && opts.kind === "ice")
    for (const n of this.enemies)
      if (!n.dead && dist(n, e) < 155) this.applyCold(n, 100);
  this.impact(
    e.x,
    e.y,
    opts.kind || this.book,
    opts.empowered || opts.critical ? 1.7 : 1,
    origin,
  );
}

export function crossSlash(this: Context, target: Enemy | null, dmg: number) {
  const t =
    target && !target.dead ? target : this.nearest(target || this.player);
  if (!t) return;
  this.fx.push({
    type: "slash",
    x: t.x,
    y: t.y,
    r: 92,
    angle: Math.PI * 0.25,
    color: "#ddc8ff",
    life: 0.42,
    max: 0.42,
  });
  this.strike(t, dmg, { kind: "paper", from: this.player, empowered: true });
  for (const e of this.enemies)
    if (!e.dead && e !== t && dist(e, t) < 95)
      this.damage(e, dmg * 0.45, 1, false);
}

export function strikeDown(this: Context, e: Enemy, dmg: number) {
  this.arc({ x: e.x - 28, y: e.y - 240 }, e, "#fff0bc", 9, 0.46);
  this.strike(e, dmg, {
    kind: "storm",
    from: { x: e.x, y: e.y - 100 },
    empowered: true,
    direct: false,
  });
}

export function addField(
  this: Context,
  kind: string,
  x: number,
  y: number,
  r: number,
  life: number,
  ultimate = false,
) {
  const nearby = this.fields.find(
    (f) => f.kind === kind && dist(f, { x, y }) < 45 && !f.ultimate,
  );
  if (nearby && !ultimate) {
    nearby.life = Math.max(nearby.life, life);
    nearby.max = Math.max(nearby.max, life);
    nearby.r = Math.max(nearby.r, r);
    return;
  }
  if (this.fields.length >= 14) this.fields.shift();
  this.fields.push({
    kind,
    x,
    y,
    r,
    life,
    max: life,
    age: 0,
    ultimate,
    seed: this.fxRng(),
  });
}

export function updateFields(this: Context, dt: number) {
  for (const f of this.fields) {
    const active = Math.min(dt, f.life);
    f.life -= dt;
    f.age += active;
    if (f.kind === "fire") this.tickFireField(f, active);
    if (f.kind === "gravity") this.pull(f.x, f.y, f.r, dt * 180);
  }
  this.fields = this.fields.filter((f) => f.life > 0);
}

export function updateEnemyStatus(this: Context, e: Enemy, dt: number) {
  this.tickBurn(e, dt);
  if (e.dead) return;
  e.age += dt;
  e.phaseLock = Math.max(0, (e.phaseLock || 0) - dt);
  e.flash = Math.max(0, e.flash - dt);
  e.freeze = Math.max(0, e.freeze - dt);
  e.grace = Math.max(0, e.grace - dt);
  e.stun = Math.max(0, e.stun - dt);
  e.mark = Math.max(0, e.mark - dt);
  e.squash *= Math.exp(-dt * 15);
  e.impactTime = Math.max(0, e.impactTime - dt);
  e.counterPushTime = Math.max(0, (e.counterPushTime || 0) - dt);
  e.collisionCD = Math.max(0, e.collisionCD - dt);
  if (e.dot > 0) {
    e.dot -= dt;
    e.dotTick -= dt;
    if (e.dotTick <= 0) {
      e.dotTick = 1;
      this.damage(e, this.combatValue("bleed.damage", { dotStacks: e.dotStacks }), 1, false);
    }
  } else e.dotStacks = 0;
}
