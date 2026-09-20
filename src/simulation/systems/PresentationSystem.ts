import { createParticle } from "../../combat/model.ts";
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
  | "presentationCues"
  | "roomVisit"
  | "arc"
  | "bookData"
  | "burst"
  | "corpses"
  | "decals"
  | "fx"
  | "fxRng"
  | "hitFlash"
  | "hitStop"
  | "kickX"
  | "kickY"
  | "options"
  | "particlePool"
  | "particles"
  | "shake"
  | "sound"
  | "sparks"
  | "stopCooldown"
  | "trails"
  | "visualTime"
>;

export function sparks(
  this: Context,
  x: number,
  y: number,
  n: number,
  color: string,
  speed = 90,
  kind = "spark",
) {
  const count = Math.round(n * this.options.fx);
  for (let i = 0; i < count && this.particles.length < 760; i++) {
    const a = this.fxRng() * TAU,
      v = (0.35 + this.fxRng() * 0.65) * speed,
      life = 0.25 + this.fxRng() * 0.45;
    const particle = this.particlePool.pop() || createParticle();
    particle.x = x;
    particle.y = y;
    particle.px = x;
    particle.py = y;
    particle.vx = Math.cos(a) * v;
    particle.vy = Math.sin(a) * v;
    particle.life = life;
    particle.max = life;
    particle.color = color;
    particle.r = 1.4 + this.fxRng() * 2.6;
    particle.angle = a;
    particle.spin = (this.fxRng() - 0.5) * 8;
    particle.kind = kind;
    this.particles.push(particle);
  }
}

export function ring(
  this: Context,
  x: number,
  y: number,
  r: number,
  color: string,
  life = 0.4,
) {
  if (this.fx.length < 320)
    this.fx.push({ type: "ring", x, y, r, color, life, max: life });
}

export function line(
  this: Context,
  a: Point,
  b: Point,
  color: string,
  life = 0.3,
) {
  this.arc(a, b, color, 3, life);
}

export function floating(
  this: Context,
  x: number,
  y: number,
  text: string,
  color: string,
  size = 15,
) {
  if (
    this.fx.length < 300 &&
    this.fx.filter((f) => f.type === "text").length < 65
  )
    this.fx.push({
      type: "text",
      x,
      y,
      text,
      color,
      size,
      life: 0.77,
      max: 0.77,
    });
}

export function updateVisual(this: Context, dt: number) {
  this.visualTime += dt;
  this.shake = Math.max(0, this.shake - dt * 24);
  this.hitFlash = Math.max(0, (this.hitFlash || 0) - dt);
  this.kickX = (this.kickX || 0) * Math.exp(-dt * 14);
  this.kickY = (this.kickY || 0) * Math.exp(-dt * 14);
  for (const f of this.fx) f.life -= dt;
  for (const p of this.particles) {
    p.life -= dt;
    p.px = p.x;
    p.py = p.y;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vx *= Math.exp(-dt * 2.3);
    p.vy *= Math.exp(-dt * 2.3);
    p.angle += p.spin * dt;
  }
  for (const d of this.corpses) {
    d.life -= dt;
    d.x += d.vx * dt;
    d.y += d.vy * dt;
    d.z += d.vz * dt;
    d.vz -= 580 * dt;
    d.angle += d.spin * dt;
    if (d.z < 0) {
      d.z = 0;
      if (d.bounces < 2) {
        d.vz = Math.abs(d.vz) * 0.33;
        d.bounces++;
        d.spin *= 0.5;
      } else {
        d.vz = 0;
        d.spin *= Math.exp(-dt * 8);
      }
      d.vx *= 0.7;
      d.vy *= 0.7;
    }
    const friction = d.z > 0 ? 1.2 : 7;
    d.vx *= Math.exp(-dt * friction);
    d.vy *= Math.exp(-dt * friction);
  }
  for (const d of this.decals) d.life -= dt;
  for (const t of this.trails) t.life -= dt;
  let live = 0;
  for (const particle of this.particles) {
    if (particle.life > 0) this.particles[live++] = particle;
    else if (this.particlePool.length < 760) this.particlePool.push(particle);
  }
  this.particles.length = live;
  this.fx = this.fx.filter((f) => f.life > 0);
  this.trails = this.trails.filter((t) => t.life > 0);
  this.corpses = this.corpses.filter((d) => d.life > 0);
  this.decals = this.decals.filter((d) => d.life > 0);
}

export function arc(
  this: Context,
  a: Point,
  b: Point,
  color: string,
  width = 4,
  life = 0.32,
) {
  if (this.fx.length < 320)
    this.fx.push({
      type: "arc",
      x: a.x,
      y: a.y,
      tx: b.x,
      ty: b.y,
      color,
      width,
      life,
      max: life,
      seed: Math.floor(this.fxRng() * 999999),
    });
}

export function burst(
  this: Context,
  x: number,
  y: number,
  r: number,
  color: string,
  kind = "impact",
) {
  if (this.fx.length >= 320) return;
  const effect = {
    type: "burst",
    x,
    y,
    r,
    color,
    kind,
    life: kind === "ultimate" ? 0.9 : kind === "parry" ? 0.65 : 0.45,
    max: kind === "ultimate" ? 0.9 : kind === "parry" ? 0.65 : 0.45,
    seed: Math.floor(this.fxRng() * 999999),
  } as const;
  this.fx.push(effect);
  this.presentationCues.publish({
    type: "burst",
    room: this.roomVisit,
    effect: Object.freeze({ ...effect }),
  });
}

export function impact(
  this: Context,
  x: number,
  y: number,
  kind: string,
  power = 1,
  from: Point | null = null,
) {
  const color =
    kind === "ice" || kind === "frost"
      ? "#adeaff"
      : kind === "storm"
        ? "#ffe5a0"
        : kind === "blade" || kind === "paper"
          ? "#dac1ff"
          : kind === "wall"
            ? "#f5d19c"
            : this.bookData.color;
  this.sparks(
    x,
    y,
    (kind === "blade" ? 5 : 11) * power,
    color,
    (kind === "ice" ? 230 : 150) * power,
    kind === "ice"
      ? "shard"
      : kind === "paper" || kind === "blade"
        ? "chip"
        : "spark",
  );
  this.burst(
    x,
    y,
    (kind === "blade" ? 26 : 38) * power,
    color,
    kind === "ice" ? "shard" : "impact",
  );
  this.shake = Math.max(this.shake, Math.min(8, 2.4 * power));
  if (from) {
    const d = Math.hypot(x - from.x, y - from.y) || 1;
    this.kickX = (-(x - from.x) / d) * power * 2;
    this.kickY = (-(y - from.y) / d) * power * 2;
  }
  if (this.stopCooldown <= 0 && kind !== "blade") {
    this.hitStop = Math.max(this.hitStop, power > 1.3 ? 0.045 : 0.021);
    this.stopCooldown = 0.19;
  }
  this.sound.impact(kind, power, { x, y });
}

export function makeDebris(this: Context, e: Enemy, color: string) {
  const count = e.boss ? 16 : 5;
  for (let i = 0; i < count && this.corpses.length < 130; i++) {
    const a = this.fxRng() * TAU,
      v = 65 + this.fxRng() * 145;
    this.corpses.push({
      x: e.x,
      y: e.y,
      z: 5,
      vz: 95 + this.fxRng() * 145,
      vx: (e.ix || 0) * 0.35 + Math.cos(a) * v,
      vy: (e.iy || 0) * 0.35 + Math.sin(a) * v,
      r: (e.boss ? 9 : 4) + this.fxRng() * 8,
      angle: a,
      spin: (this.fxRng() - 0.5) * 12,
      life: 1.8 + this.fxRng(),
      max: 2.8,
      color,
      bounces: 0,
      ice: e.freeze > 0,
    });
  }
}
