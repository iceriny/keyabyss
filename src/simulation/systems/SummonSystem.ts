import { summonCapacity } from "../../shared/summons.ts";
import type { Point } from "../../combat/model.ts";
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
  | "stats"
  | "bookBehavior"
  | "bullets"
  | "damageMultiplier"
  | "enemies"
  | "focusId"
  | "nearest"
  | "player"
  | "sparks"
  | "spiritPosition"
  | "spiritTime"
  | "awakenedSpirits"
  | "spirits"
  | "strike"
  | "time"
  | "ultimateTime"
>;

export function spiritPosition(this: Context, i: number, n: number) {
  const a = this.time * 0.95 + (i / Math.max(1, n)) * TAU;
  return {
    x: this.player.x + Math.cos(a) * 67,
    y: this.player.y - 11 + Math.sin(a) * 45,
  };
}

export function updateSpirits(this: Context, dt: number) {
  this.spiritTime = Math.max(0, this.spiritTime - dt);
  const capacity = summonCapacity(this.bookBehavior.summons, this.stats, this.ultimateTime);
  this.awakenedSpirits = this.spiritTime > 0 ? Math.min(this.awakenedSpirits, capacity) : 0;
  const count = this.spiritTime > 0 ? (this.bookBehavior.summons ? this.awakenedSpirits : capacity) : 0;
  while (this.spirits.length < count) {
    const i = this.spirits.length;
    this.spirits.push({
      i,
      x: this.player.x,
      y: this.player.y - 30,
      vx: 0,
      vy: 0,
      mode: "orbit",
      life: 0,
      cooldown: i * 0.15,
      angle: 0,
      trail: [],
      block: 0,
    });
  }
  if (this.spirits.length > count) this.spirits.length = count;
  for (const s of this.spirits) {
    s.cooldown -= dt;
    s.block = Math.max(0, s.block - dt);
    const orbit = this.spiritPosition(s.i, count);
    if (s.mode === "orbit" && s.cooldown <= 0) {
      const marked = this.enemies.find(
        (e) => !e.dead && e.id === this.focusId && e.mark > 0,
      );
      const t = marked || this.nearest(s, new Set(), 450);
      if (t) {
        s.mode = "dive";
        s.targetId = t.id;
        s.life = 0.8;
      }
    }
    let target = this.enemies.find((e) => !e.dead && e.id === s.targetId),
      q = s.mode === "dive" && target ? target : orbit;
    if (s.mode === "dive" && !target) s.mode = "return";
    const dx = q.x - s.x,
      dy = q.y - s.y,
      d = Math.hypot(dx, dy) || 1,
      speed = s.mode === "dive" ? 790 : s.mode === "return" ? 650 : 190;
    s.vx += ((dx / d) * Math.min(speed, d * 6) - s.vx) * Math.min(1, dt * 13);
    s.vy += ((dy / d) * Math.min(speed, d * 6) - s.vy) * Math.min(1, dt * 13);
    const px = s.x,
      py = s.y;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    s.angle = Math.atan2(s.vy, s.vx);
    s.trail.push({ x: s.x, y: s.y });
    if (s.trail.length > 8) s.trail.shift();
    if (s.mode === "dive" && target) {
      s.life -= dt;
      if (
        C.segmentDistance(px, py, s.x, s.y, target.x, target.y) <
        target.r + 10
      ) {
        const damage =
          (12 + (this.stats.summonStacks || 0) * 3) *
          (1 + (this.stats.summonBond || 0) * 0.3) *
          this.damageMultiplier() *
          (target.mark > 0 ? 1.45 : 1);
        this.strike(target, damage, {
          kind: "blade",
          from: { x: px, y: py },
          direct: false,
          depth: 1,
        });
        s.mode = "return";
        s.cooldown =
          this.bookBehavior.summons && this.ultimateTime > 0 ? 0.24 : 0.55;
      } else if (s.life <= 0) {
        s.mode = "return";
        s.cooldown = 0.2;
      }
    }
    if (s.mode === "return" && dist(s, orbit) < 35) s.mode = "orbit";
    if (this.stats.summonedMark && s.block <= 0) {
      const b = this.bullets.find((b) => !b.dead && dist(b, s) < 22);
      if (b) {
        b.dead = true;
        s.block = 0.25;
        this.sparks(b.x, b.y, 5, "#ddc4ff", 90, "chip");
      }
    }
  }
}
