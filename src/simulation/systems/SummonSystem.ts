import {
  beginFlight,
  flightPoint,
  orbitPoint,
} from "../../shared/spirit-flight.ts";
import type { Point } from "../../combat/model.ts";
import * as C from "../../shared/math.ts";

const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);

import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<
  CombatRuntime,
  | "content"
  | "combatValue"
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
  return orbitPoint(this.player, this.time, i, n, this.content.spiritFlight);
}

export function updateSpirits(this: Context, dt: number) {
  this.spiritTime = Math.max(0, this.spiritTime - dt);
  const capacity = this.combatValue("summon.capacity");
  this.awakenedSpirits =
    this.spiritTime > 0 ? Math.min(this.awakenedSpirits, capacity) : 0;
  const count =
    this.spiritTime > 0
      ? this.bookBehavior.summons
        ? this.awakenedSpirits
        : capacity
      : 0;
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
    const profile = this.content.spiritFlight;
    if (s.mode === "orbit" && s.cooldown <= 0) {
      const marked = this.enemies.find(
        (e) => !e.dead && e.id === this.focusId && e.mark > 0,
      );
      const target = marked || this.nearest(s, new Set(), 450);
      if (target) {
        s.targetId = target.id;
        beginFlight(s, "dive", target, profile);
      }
    }
    const target = this.enemies.find((e) => !e.dead && e.id === s.targetId);
    if (s.mode === "dive" && !target) beginFlight(s, "return", orbit, profile);
    const px = s.x,
      py = s.y;
    let hit = false;
    if (s.flight) {
      const f = s.flight;
      if (s.mode === "dive" && target) f.end = { x: target.x, y: target.y };
      if (s.mode === "return") {
        f.end = orbit;
        const next = orbitPoint(
          this.player,
          this.time + 0.05,
          s.i,
          count,
          profile,
        );
        f.arrival = {
          x: (((next.x - orbit.x) / 0.05) * f.duration) / 3,
          y: (((next.y - orbit.y) / 0.05) * f.duration) / 3,
        };
      }
      const from = Math.min(1, f.elapsed / f.duration);
      f.elapsed = Math.min(f.duration, f.elapsed + dt);
      const to = f.elapsed / f.duration;
      const steps = Math.max(1, Math.ceil((to - from) / 0.08));
      let previous = { x: s.x, y: s.y };
      for (let i = 1; i <= steps; i++) {
        const progress = from + ((to - from) * i) / steps;
        const q = flightPoint(
          f,
          s.mode === "cross" ? progress ** 1.6 : progress,
        );
        if (
          s.mode === "dive" &&
          target &&
          C.segmentDistance(
            previous.x,
            previous.y,
            q.x,
            q.y,
            target.x,
            target.y,
          ) <
            target.r + 10
        )
          hit = true;
        s.x = q.x;
        s.y = q.y;
        previous = q;
        if (hit) break;
      }
      if (dt > 0) {
        s.vx = (s.x - px) / dt;
        s.vy = (s.y - py) / dt;
      }
      if (hit && target) {
        this.strike(
          target,
          this.combatValue("summon.damage", {
            marked: Number(target.mark > 0),
          }),
          {
            kind: "blade",
            from: { x: px, y: py },
            direct: false,
            depth: 1,
          },
        );
        s.cooldown =
          this.bookBehavior.summons && this.ultimateTime > 0 ? 0.24 : 0.55;
        beginFlight(s, "return", orbit, profile);
      } else if (to >= 1) {
        if (s.mode === "return") {
          s.mode = "orbit";
          s.flight = undefined;
        } else {
          s.cooldown = Math.max(s.cooldown, 0.2);
          beginFlight(s, "return", orbit, profile);
        }
      }
    } else {
      const next = orbitPoint(
        this.player,
        this.time + 0.05,
        s.i,
        count,
        profile,
      );
      const response = 1 - Math.exp(-profile.orbit.response * dt);
      s.vx +=
        ((next.x - orbit.x) / 0.05 + (orbit.x - s.x) * 3 - s.vx) * response;
      s.vy +=
        ((next.y - orbit.y) / 0.05 + (orbit.y - s.y) * 3 - s.vy) * response;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    if (Math.hypot(s.vx, s.vy) > 1) s.angle = Math.atan2(s.vy, s.vx);
    const last = s.trail[s.trail.length - 1];
    if (!last || dist(last, s) >= 3) s.trail.push({ x: s.x, y: s.y });
    if (s.trail.length > profile.trailPoints) s.trail.shift();
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
