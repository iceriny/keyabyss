import { enemyInCombat } from "../../shared/arena.ts";
import { limitBossDamage } from "./PhaseController.ts";

import type { Point, Enemy } from "../../combat/model.ts";
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
  | "spreadBurn"
  | "eliteProfile"
  | "domainEvents"
  | "roomVisit"
  | "godMode"
  | "arena"
  | "combatValue"
  | "stats"
  | "bossDefinition"
  | "addResonance"
  | "applyCold"
  | "blasts"
  | "bloodPaidStage"
  | "bookBehavior"
  | "burst"
  | "cancel"
  | "clearBullets"
  | "clearDelay"
  | "combo"
  | "content"
  | "damage"
  | "damageMultiplier"
  | "decals"
  | "emit"
  | "end"
  | "enemies"
  | "enemyProfile"
  | "explode"
  | "fire"
  | "floating"
  | "fxRng"
  | "gainXP"
  | "hitFlash"
  | "hitStop"
  | "impulse"
  | "kill"
  | "kills"
  | "lasers"
  | "launchShot"
  | "level"
  | "makeBlast"
  | "makeDebris"
  | "mode"
  | "nextXP"
  | "nodes"
  | "pending"
  | "perfectWords"
  | "player"
  | "prefix"
  | "pressure"
  | "pull"
  | "relics"
  | "rescued"
  | "ring"
  | "roomEnded"
  | "roomKills"
  | "shake"
  | "shots"
  | "sound"
  | "sparks"
  | "spawnEnemy"
  | "stage"
  | "state"
  | "target"
  | "tasks"
  | "totalDamage"
  | "xp"
>;

export function damage(
  this: Context,
  e: Enemy,
  dmg: number,
  depth = 0,
  direct = false,
  from: Point | null = null,
) {
  if (!e || e.dead || !Number.isFinite(dmg) || dmg <= 0) return;
  if (e.boss)
    dmg = limitBossDamage(
      this.bossDefinition(),
      e,
      dmg,
      this.enemies,
      this.arena,
    );
  if (
    enemyInCombat(this.arena, e) &&
    this.enemyProfile(e).frontArmor &&
    e.freeze <= 0 &&
    e.stun <= 0
  ) {
    const a = from || this.player,
      front =
        ((a.x - e.x) * (this.player.x - e.x) +
          (a.y - e.y) * (this.player.y - e.y)) /
        Math.max(1, dist(a, e) * dist(this.player, e));
    if (front > 0.2) dmg *= 0.7;
  }
  if (
    enemyInCombat(this.arena, e) &&
    this.enemyProfile(e).mirror &&
    e.mirror > 0 &&
    e.freeze <= 0 &&
    direct
  ) {
    dmg *= 0.55;
    e.mirror = 0;
    this.burst(e.x, e.y, 65, "#dfc9ff", "shard");
    if (e.grace <= 0) this.fire(e, "fan");
  }
  if (e.freeze <= 0) dmg *= this.eliteProfile(e)?.unfrozenDamage ?? 1;
  this.totalDamage += Math.min(e.hp, dmg);
  e.hp -= dmg;
  this.domainEvents.publish({
    type: "damage",
    entity: e.id,
    amount: dmg,
    depth,
    direct,
  });
  e.flash = 0.14;
  e.squash = Math.min(0.36, (e.squash || 0) + 0.19);
  e.poise = (e.poise || 0) + dmg * 0.5;
  if (!e.boss && e.poise > e.maxHp * 0.78) {
    e.poise = 0;
    e.stun = 0.4;
    e.windup = 0;
    e.charge = 0;
  }
  this.floating(
    e.x + (this.fxRng() - 0.5) * 24,
    e.y - 20,
    String(Math.round(dmg)),
    direct ? "#fff0cf" : "#abc7d1",
    direct ? 18 : 12,
  );
  if (e.hp <= 0) this.kill(e, depth);
}

export function kill(this: Context, e: Enemy, depth = 0) {
  if (e.dead) return;
  e.dead = true;
  this.spreadBurn(e);
  this.domainEvents.publish({ type: "death", entity: e.id, depth });
  this.kills++;
  this.roomKills++;
  this.gainXP(
    (e.boss ? 45 : this.content.enemies[e.type]?.xp || 6) *
      (e.elite ? 1.55 : 1) *
      (this.pressure.trialXP || 1),
  );
  const color =
    e.freeze > 0
      ? "#a7e6ff"
      : e.boss
        ? "#f3d098"
        : this.content.enemies[e.type]?.color || "#adcac3";
  this.sparks(
    e.x,
    e.y,
    e.boss ? 60 : 16,
    color,
    e.boss ? 300 : 165,
    e.freeze > 0 ? "shard" : "chip",
  );
  this.burst(
    e.x,
    e.y,
    e.boss ? 165 : e.r + 30,
    color,
    e.freeze > 0 ? "shard" : "impact",
  );
  this.makeDebris(e, color);
  this.decals.push({ x: e.x, y: e.y, r: e.r * 0.85, color, life: 10 });
  if (this.decals.length > 32) this.decals.shift();
  this.sound.kill(e.boss, e);
  this.shake = Math.max(this.shake, e.boss ? 13 : 3.2);
  if (this.target === e) {
    if (this.stats.partialWordShield && this.prefix.length) {
      this.player.shield = Math.min(60, this.player.shield + 10);
      this.floating(
        this.player.x,
        this.player.y - 55,
        "护盾 +10",
        "#d5bffc",
        14,
      );
    }
    this.cancel();
  }
  if (e.mark > 0 && this.stats.summonedMark) this.addResonance(8);
  if (
    enemyInCombat(this.arena, e) &&
    this.enemyProfile(e).deathSplit &&
    !e.small &&
    depth < 2 &&
    !this.roomEnded
  ) {
    for (const spawn of this.enemyProfile(e).deathSpawns ?? [])
      this.spawnEnemy(spawn.enemy, e.x + spawn.x, e.y + spawn.y, true);
  }
  if (enemyInCombat(this.arena, e) && this.enemyProfile(e).deathVortex) {
    this.pull(e.x, e.y, 245, 470);
    this.explode(e.x, e.y, 155, 35, e, depth + 1, "#b6a2eb");
  }
  const deathBlast = this.eliteProfile(e)?.deathBlast;
  if (enemyInCombat(this.arena, e) && deathBlast && !this.roomEnded)
    this.makeBlast(
      e.x,
      e.y,
      deathBlast.radius,
      deathBlast.warning,
      null,
      false,
    );
  if (
    e.freeze > 0 &&
    (this.bookBehavior.shatter || this.stats.shatterStacks) &&
    depth < 3
  ) {
    this.explode(
      e.x,
      e.y,
      this.combatValue("shatter.radius"),
      this.combatValue("shatter.damage"),
      e,
      depth + 1,
      "#94dbff",
      true,
    );
    if (this.stats.deathFrostVolley && depth === 0) {
      const others = this.enemies
        .filter((n) => !n.dead)
        .sort((a, b) => dist(a, e) - dist(b, e))
        .slice(0, 6);
      for (const n of others)
        this.launchShot(e, n, "ice", 26 * this.damageMultiplier(), {
          direct: false,
          depth: 2,
          pierce: 0,
        });
    }
  }
  if (e.boss) {
    this.clearBullets(640, 400, 1800);
    for (const other of this.enemies)
      if (!other.dead) {
        other.dead = true;
        this.makeDebris(other, color);
      }
    this.nodes.forEach((n) => (n.dead = true));
    this.lasers = [];
    this.blasts = [];
    this.tasks = [];
    this.shots = [];
    this.clearDelay = 1.3;
    this.roomEnded = true;
    this.hitStop = 0.07;
    this.sound.reward();
  }
}

export function explode(
  this: Context,
  x: number,
  y: number,
  r: number,
  dmg: number,
  except: Enemy | null = null,
  depth = 0,
  color = "#e6c69d",
  cold = false,
) {
  this.ring(x, y, r, color, 0.5);
  this.burst(x, y, r * 0.55, color, cold ? "shard" : "shock");
  const near = this.enemies.filter(
    (e) => !e.dead && e !== except && Math.hypot(e.x - x, e.y - y) <= r + e.r,
  );
  for (const e of near) {
    if (cold) this.applyCold(e, 100);
    this.impulse(
      e,
      { x, y },
      (cold ? 160 : 210) * this.combatValue("impulse.multiplier"),
    );
    this.damage(e, dmg, depth, false, { x, y });
  }
}

export function heal(this: Context, n: number) {
  this.player.hp = Math.min(this.player.maxHp, this.player.hp + n);
  this.floating(
    this.player.x,
    this.player.y - 50,
    "+" + Math.round(n),
    "#a6d9ac",
    15,
  );
}

export function hurt(
  this: Context,
  amount: number,
  source: Point | null = null,
) {
  const p = this.player;
  if (p.invuln > 0 || this.state !== "playing" || this.roomEnded) return;
  amount *=
    this.combatValue("armor.multiplier");
  if (p.shield > 0) {
    const absorbed = Math.min(p.shield, amount);
    p.shield -= absorbed;
    amount -= absorbed;
  }
  p.hp -= amount;
  p.invuln = this.mode.iframe;
  this.combo = Math.floor(this.combo * 0.62);
  this.perfectWords = 0;
  this.shake = 10;
  this.hitFlash = 0.3;
  this.sound.hit();
  if (source) {
    const d = dist(p, source) || 1;
    p.vx += ((p.x - source.x) / d) * 125;
    p.vy += ((p.y - source.y) / d) * 125;
  }
  this.burst(p.x, p.y, 64, "#ff8899", "impact");
  this.floating(
    p.x,
    p.y - 52,
    amount > 0 ? "−" + Math.ceil(amount) : "格挡",
    "#ffc1b9",
    22,
  );
  if (p.hp <= 0) {
    if (this.godMode) {
      p.hp = p.maxHp;
      this.floating(p.x, p.y - 72, "GOD MODE · 回满", "#ffe5a1", 18);
    } else if (this.stats.lethalRescue && !this.rescued) {
      this.rescued = true;
      p.hp = this.combatValue("rescue.health");
      p.invuln = 3;
      this.clearBullets(p.x, p.y, 1800);
      this.lasers = [];
      this.blasts = [];
      this.explode(p.x, p.y, 1000, 80, null, 1, "#ffeab4");
      this.emit("toast", "未完待续 · 这一页还没写完");
    } else {
      p.hp = 0;
      this.end(false);
    }
  }
  this.emit("hud");
}

export function payBloodPrice(this: Context) {
  if (!this.stats.roomHealthCost || this.bloodPaidStage === this.stage) return;
  const p = this.player,
    cost = Math.min(this.combatValue("bloodprice.hook.0.amount"), Math.max(0, p.hp - 1));
  p.hp -= cost;
  this.bloodPaidStage = this.stage;
  this.floating(p.x, p.y - 55, "血契 −" + Math.round(cost), "#ffc1b9", 20);
  this.emit("toast", `血字契约 · 生命 −${Math.round(cost)} · 施法伤害 +40%`);
  this.emit("hud");
}

export function gainXP(this: Context, n: number) {
  this.xp += n * (this.stats.experienceBoost ? 1.35 : 1);
  while (this.xp >= this.nextXP) {
    this.xp -= this.nextXP;
    this.level++;
    this.pending++;
    this.nextXP = Math.round(this.nextXP * 1.13 + 4);
  }
}
