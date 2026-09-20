import type { Enemy, SpellOptions, Field } from "../../combat/model.ts";
import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<
  CombatRuntime,
  | "stats"
  | "damageMultiplier"
  | "damage"
  | "enemies"
  | "burst"
  | "addField"
  | "applyBurn"
  | "igniteExplosion"
  | "roomEnded"
>;

export function applyBurn(
  this: Context,
  enemy: Enemy,
  stacks = 1,
  spreadDepth = 0,
) {
  if (enemy.dead) return;
  const previous = enemy.burn;
  enemy.burn = {
    life: 3 + this.stats.burnDuration,
    stacks: Math.min(
      this.stats.inferno ? 5 : 3,
      (previous?.life && previous.life > 0 ? previous.stacks : 0) + stacks,
    ),
    tick: previous && previous.life > 0 ? previous.tick : 0.5,
    damage: Math.max(
      previous?.damage ?? 0,
      6 * this.damageMultiplier() * (1 + 0.3 * this.stats.burnPower),
    ),
    spreadDepth: previous
      ? Math.min(previous.spreadDepth, spreadDepth)
      : spreadDepth,
  };
}
export function tickBurn(this: Context, enemy: Enemy, dt: number) {
  const burn = enemy.burn;
  if (!burn || enemy.dead) return;
  const active = Math.min(dt, burn.life);
  burn.life -= dt;
  burn.tick -= active;
  while (burn.tick <= 1e-8 && !enemy.dead) {
    burn.tick += 0.5;
    this.damage(enemy, burn.damage * burn.stacks, burn.spreadDepth + 1, false);
  }
  if (burn.life <= 0 && !enemy.dead) enemy.burn = undefined;
}
export function igniteExplosion(
  this: Context,
  x: number,
  y: number,
  radius: number,
  damage: number,
  exclude: Enemy | null = null,
  depth = 0,
  stacks = 1,
) {
  this.burst(x, y, radius, "#ff9a43", "flame");
  for (const enemy of [...this.enemies]) {
    if (
      enemy === exclude ||
      enemy.dead ||
      Math.hypot(enemy.x - x, enemy.y - y) > radius
    )
      continue;
    this.applyBurn(enemy, stacks, depth);
    this.damage(enemy, damage, depth + 1, false);
  }
}
export function fireImpact(
  this: Context,
  enemy: Enemy,
  damage: number,
  options: SpellOptions,
) {
  const radius = (options.empowered ? 115 : 55) + 25 * this.stats.fireRadius;
  this.igniteExplosion(
    enemy.x,
    enemy.y,
    radius,
    damage * (options.empowered ? 0.5 : 0.22),
    enemy,
    options.depth ?? 0,
    options.empowered ? 2 : 1,
  );
  if (options.empowered) this.addField("fire", enemy.x, enemy.y, radius, 3.2);
}
export function spreadBurn(this: Context, enemy: Enemy) {
  const burn = enemy.burn;
  if (
    !burn ||
    !this.stats.burnSpread ||
    burn.spreadDepth >= 2 ||
    this.roomEnded
  )
    return;
  const targets = this.enemies
    .filter(
      (e) =>
        !e.dead &&
        Math.hypot(e.x - enemy.x, e.y - enemy.y) <
          130 + 25 * this.stats.burnSpread,
    )
    .sort(
      (a, b) =>
        Math.hypot(a.x - enemy.x, a.y - enemy.y) -
        Math.hypot(b.x - enemy.x, b.y - enemy.y),
    )
    .slice(0, 2 + this.stats.burnSpread);
  for (const target of targets)
    this.applyBurn(target, Math.min(2, burn.stacks), burn.spreadDepth + 1);
  if (targets.length) this.burst(enemy.x, enemy.y, 80, "#ffad5e", "flame");
}
export function tickFireField(this: Context, field: Field, dt: number) {
  // A discrete half-second cadence independent of render density.
  const pulses =
    Math.floor((field.age + 1e-8) / 0.5) -
    Math.floor((Math.max(0, field.age - dt) + 1e-8) / 0.5);
  if (pulses <= 0) return;
  for (const enemy of this.enemies)
    if (
      !enemy.dead &&
      Math.hypot(enemy.x - field.x, enemy.y - field.y) <= field.r
    )
      this.applyBurn(enemy, Math.min(3, pulses), 0);
}
