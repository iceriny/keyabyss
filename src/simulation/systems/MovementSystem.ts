import { DEFENSE, dodgeDirection } from "../../shared/defense.ts";
import type { BookAbilityContext } from "../../content-sdk/BookBehavior.ts";

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
  | "godMode"
  | "stats"
  | "addField"
  | "addResonance"
  | "aimKeys"
  | "arena"
  | "blasts"
  | "bookBehavior"
  | "bookData"
  | "bullets"
  | "burst"
  | "clearBullets"
  | "damage"
  | "dashes"
  | "emit"
  | "enemies"
  | "enemyProfile"
  | "findSafe"
  | "finishDodge"
  | "floating"
  | "impulse"
  | "lasers"
  | "mode"
  | "perfectDodges"
  | "player"
  | "precisionTime"
  | "pull"
  | "roomEnded"
  | "safePoint"
  | "sound"
  | "sparks"
  | "state"
  | "trails"
  | keyof BookAbilityContext
>;

export function findSafe(this: Context) {
  const p = this.player,
    a = this.arena;
  const { x: ax, y: ay } = dodgeDirection(this.aimKeys);
  if (!ax && !ay) {
    // Fixed candidate count: O(enemies + bullets + hazards), independent of vocabulary size.
    let best = { x: p.x, y: p.y, manual: false },
      bestScore = Infinity;
    for (let i = 0; i < 16; i++) {
      const angle = -Math.PI / 2 + (i * TAU) / 16;
      const q = {
        x: clamp(p.x + Math.cos(angle) * 172, a.l + 25, a.r - 25),
        y: clamp(p.y + Math.sin(angle) * 164, a.t + 28, a.b - 24),
        manual: false,
      };
      let score = Math.max(0, 150 - dist(p, q)) * 5;
      for (const e of this.enemies)
        if (!e.dead) score += 7000 / Math.max(8, dist(q, e) - e.r);
      for (const b of this.bullets)
        if (!b.dead && !b.reflected) {
          const d = C.segmentDistance(
            b.x,
            b.y,
            b.x + b.vx * 0.7,
            b.y + b.vy * 0.7,
            q.x,
            q.y,
          );
          score += d < b.r + 22 ? 500 : 100 / Math.max(10, d);
        }
      for (const l of this.lasers)
        if (
          !l.dead &&
          (l.vertical ? Math.abs(q.x - l.pos) : Math.abs(q.y - l.pos)) <
            l.width + 24
        )
          score += 700;
      for (const b of this.blasts)
        if (!b.dead && !b.fired && dist(q, b) < b.r + 24) score += 800;
      score += Math.hypot(q.x - (a.l + a.r) / 2, q.y - (a.t + a.b) / 2) * 0.025;
      if (score < bestScore) {
        best = q;
        bestScore = score;
      }
    }
    return best;
  }
  const n = Math.hypot(ax, ay) || 1;
  return {
    x: clamp(p.x + (ax / n) * 172, a.l + 25, a.r - 25),
    y: clamp(p.y + (ay / n) * 164, a.t + 28, a.b - 24),
    manual: true,
  };
}

export function dodge(this: Context) {
  const p = this.player;
  if (this.state !== "playing" || this.roomEnded || p.dashState) return;
  if (!this.godMode && p.dash < 1) {
    this.emit("toast", "闪避正在恢复 · 按空格弹反");
    return;
  }
  const near =
    this.bullets.some(
      (b) =>
        !b.dead &&
        !b.reflected &&
        dist(b, p) < 60 &&
        (p.x - b.x) * b.vx + (p.y - b.y) * b.vy > 0 &&
        C.segmentDistance(
          b.x,
          b.y,
          b.x + b.vx * 0.4,
          b.y + b.vy * 0.4,
          p.x,
          p.y,
        ) <
          b.r + 14,
    ) ||
    this.lasers.some(
      (l) =>
        !l.dead &&
        l.warning < 0.36 &&
        (l.vertical ? Math.abs(p.x - l.pos) : Math.abs(p.y - l.pos)) <
          l.width + 14,
    ) ||
    this.blasts.some(
      (b) => !b.dead && !b.fired && b.warning < 0.38 && dist(b, p) < b.r,
    );
  const q = this.findSafe(),
    from = { x: p.x, y: p.y };
  if (dist(q, p) < 8) {
    this.emit("toast", "此方向已到边界 · 换个方向闪避");
    return;
  }
  p.dash = this.godMode ? p.maxDash : p.dash - 1;
  p.invuln = Math.max(p.invuln, DEFENSE.dodgeInvulnerability);
  p.parryTime = 0;
  p.dashState = {
    x: p.x,
    y: p.y,
    tx: q.x,
    ty: q.y,
    time: 0,
    duration: 0.17,
    trail: 0,
  };
  p.vx = 0;
  p.vy = 0;
  this.dashes++;
  if (this.stats.precisionWindow) {
    this.precisionTime = 1.5;
    this.emit("toast", "停笔沙漏 · 世界减速 · 继续打字施法");
  }
  if (near) {
    this.perfectDodges++;
    this.addResonance(20);
    this.floating(p.x, p.y - 64, "极限闪避", "#f8e3a6", 21);
    this.sound.perfect();
  }
  this.sound.dash(this.player);
  this.burst(p.x, p.y, 48, this.bookData.color, "impact");
  this.bookBehavior.dash(this, from);
  if (this.stats.dashMagnet) {
    this.pull(p.x, p.y, 230, 320);
    this.addField("gravity", p.x, p.y, 190, 1.2);
  }
  this.safePoint = q;
  this.emit("hud");
}

export function getDashCooldown(this: Context) {
  return this.mode.dashCD * (this.stats.extraDash ? 0.72 : 1);
}

export function finishDodge(this: Context) {
  const p = this.player;
  this.sparks(p.x, p.y, 15, this.bookData.color, 120, "chip");
  if (this.stats.dashShock || this.stats.dashMagnet) {
    const radius = this.stats.dashShock ? 135 : 75;
    this.clearBullets(p.x, p.y, radius);
    this.burst(p.x, p.y, radius, this.bookData.color, "shock");
    for (const e of this.enemies)
      if (!e.dead && dist(e, p) < radius + 20) this.impulse(e, p, 400);
  }
}

export function updatePlayer(this: Context, dt: number, precisionDt = 0) {
  const p = this.player,
    a = this.arena;
  if (p.dashState) {
    const d = p.dashState;
    d.time += dt;
    const t = clamp(d.time / d.duration, 0, 1),
      q = 1 - Math.pow(1 - t, 3);
    p.x = d.x + (d.tx - d.x) * q;
    p.y = d.y + (d.ty - d.y) * q;
    d.trail -= dt;
    if (d.trail <= 0) {
      this.trails.push({
        x: p.x,
        y: p.y,
        life: 0.27,
        max: 0.27,
        angle: Math.atan2(d.ty - d.y, d.tx - d.x),
      });
      d.trail = 0.018;
    }
    if (t >= 1) {
      p.dashState = null;
      this.finishDodge();
    }
  } else {
    p.x = clamp(p.x + p.vx * dt, a.l + 20, a.r - 20);
    p.y = clamp(p.y + p.vy * dt, a.t + 25, a.b - 20);
    p.vx *= Math.exp(-dt * 9);
    p.vy *= Math.exp(-dt * 9);
  }
}

export function resolveBodies(this: Context, dt: number) {
  const enemies = this.enemies;
  for (let i = 0; i < enemies.length; i++)
    for (let j = i + 1; j < enemies.length; j++) {
      const a = enemies[i],
        b = enemies[j];
      if (a.dead || b.dead || a.grace > 0 || b.grace > 0) continue;
      let dx = b.x - a.x,
        dy = b.y - a.y,
        d = Math.hypot(dx, dy),
        r = a.r + b.r + 3;
      if (d >= r) continue;
      if (d < 0.01) {
        dx = 1;
        dy = 0;
        d = 1;
      }
      const nx = dx / d,
        ny = dy / d,
        ia = this.enemyProfile(a).stationary ? 0 : 1 / (a.mass || 1),
        ib = this.enemyProfile(b).stationary ? 0 : 1 / (b.mass || 1),
        sum = ia + ib;
      if (!sum) continue;
      const overlap = (r - d) * 0.72;
      a.x -= (nx * overlap * ia) / sum;
      a.y -= (ny * overlap * ia) / sum;
      b.x += (nx * overlap * ib) / sum;
      b.y += (ny * overlap * ib) / sum;
      const relative =
        (a.vx + a.ix - (b.vx + b.ix)) * nx + (a.vy + a.iy - (b.vy + b.iy)) * ny;
      if (relative > 40) {
        const impulse = (relative * 1.12) / sum;
        a.ix -= impulse * nx * ia;
        a.iy -= impulse * ny * ia;
        b.ix += impulse * nx * ib;
        b.iy += impulse * ny * ib;
        if (
          relative > 185 &&
          !a.counterPushTime &&
          !b.counterPushTime &&
          (a.impactTime > 0 || b.impactTime > 0) &&
          a.collisionCD <= 0 &&
          b.collisionCD <= 0
        ) {
          a.collisionCD = 0.4;
          b.collisionCD = 0.4;
          this.damage(
            b,
            (7 + relative * 0.018) * (this.stats.impulsePower ? 2 : 1),
            1,
            false,
          );
          this.burst((a.x + b.x) / 2, (a.y + b.y) / 2, 27, "#e6cf9f", "impact");
        }
      }
    }
  for (const e of this.enemies) {
    e.x = clamp(e.x, this.arena.l + e.r * 0.7, this.arena.r - e.r * 0.7);
    e.y = clamp(e.y, this.arena.t + e.r * 0.7, this.arena.b - e.r * 0.7);
  }
}

export function impulse(this: Context, e: Enemy, from: Point, force: number) {
  if (e.dead || this.enemyProfile(e).stationary) return;
  let dx = e.x - from.x,
    dy = e.y - from.y,
    d = Math.hypot(dx, dy) || 1;
  const k = force / Math.max(0.5, e.mass || 1);
  e.ix = clamp((e.ix || 0) + (dx / d) * k, -720, 720);
  e.iy = clamp((e.iy || 0) + (dy / d) * k, -720, 720);
  e.impactTime = 0.55;
}

export function pull(
  this: Context,
  x: number,
  y: number,
  r: number,
  force: number,
) {
  for (const e of this.enemies)
    if (!e.dead && !e.boss && !this.enemyProfile(e).stationary) {
      const d = Math.hypot(e.x - x, e.y - y);
      if (d > 18 && d < r) {
        e.ix += (((x - e.x) / d) * force) / (e.mass || 1);
        e.iy += (((y - e.y) / d) * force) / (e.mass || 1);
      }
    }
}
