import type { Enemy, SpellOptions, Field } from "../../combat/model.ts";
import type { CombatRuntime } from "../Runtime.ts";
import type { SpellPacket } from '../../contracts/combat-weave.ts';
let burnSequence = 0;
const MAX_CONTRIBUTIONS = 24;
type Context = Pick<
  CombatRuntime,
  | "combatValue"
  | "stats"
  | "damageMultiplier"
  | "damage"
  | "enemies"
  | "burst"
  | "addField"
  | "applyBurn"
  | "igniteExplosion"
  | "roomEnded"
  | "weave"
>;

function settleContributions(ctx: Context, enemy: Enemy) {
  const burn = enemy.burn;
  if (!burn?.contributions) return;
  for (let i = burn.contributions.length - 1; i >= 0; i--) {
    const contribution = burn.contributions[i];
    if (contribution.balance > 1e-8 && contribution.life > 0) continue;
    if (contribution.balance > 1e-8)
      ctx.weave.settleExpiredBurn(ctx, contribution.balance, contribution.recoverable,
        contribution.recoveryRate, contribution);
    contribution.balance = 0;
    burn.contributions.splice(i, 1);
  }
  if (!burn.contributions.length) { enemy.burn = undefined; return; }
  burn.life = Math.max(0, ...burn.contributions.map(c => c.life));
  burn.stacks = Math.min(ctx.stats.inferno ? 5 : 3, burn.contributions.length);
  burn.damage = Math.min(ctx.combatValue('burn.damage'), burn.contributions.reduce((sum, c) => sum + c.rate, 0) / 2);
  burn.spreadDepth = Math.min(...burn.contributions.map(c => c.spreadDepth));
}

export function applyBurn(
  this: Context,
  enemy: Enemy,
  stacks = 1,
  spreadDepth = 0,
  source?: SpellPacket,
  sourceShare = 1,
) {
  if (enemy.dead) return;
  settleContributions(this, enemy);
  const previous = enemy.burn;
  const duration = Math.max(0, this.combatValue('burn.duration'));
  const share = source ? Math.min(2, Math.max(0, source.lastHitPower / Math.max(1, source.root.basePower))) *
    Math.max(0, Math.min(1, sourceShare)) : 1;
  const rate = Math.max(0, this.combatValue('burn.damage') * Math.max(0, stacks) * 2 * share);
  if (duration <= 0 || rate <= 0) return;
  const contributions = previous?.contributions ?? [];
  if (contributions.length >= MAX_CONTRIBUTIONS) { this.weave.recordRejectedBurn(rate * duration, source); return; }
  contributions.push({ id: ++burnSequence, rootId: source?.rootId ?? null,
    packetId: source?.id ?? null, source: source?.source ?? 'ambient',
    sourceIds: source?.root.sourceIds,
    recoverable: !!source && source.source !== 'recovered' && source.program.recoveryEligible,
    recoveryRate: source?.program.recoveryRate ?? 0,
    balance: rate * duration, rate, life: duration, spreadDepth });
  enemy.burn = {
    life: Math.max(...contributions.map(c => c.life)),
    stacks: Math.min(this.stats.inferno ? 5 : 3, contributions.length),
    tick: previous?.tick ?? .5,
    damage: Math.min(rate / 2, contributions.reduce((sum, c) => sum + c.rate, 0) / 2),
    spreadDepth: Math.min(...contributions.map(c => c.spreadDepth)),
    contributions,
  };
}
/** The same atomic balance claim serves death, expiry and manual extraction. */
export function consumeBurnBalance(burn: NonNullable<Enemy['burn']>, fraction: number, recoverableOnly = false, weighted = false): number {
  let claimed = 0;
  for (const contribution of burn.contributions ?? []) {
    if (recoverableOnly && !contribution.recoverable) continue;
    const amount = contribution.balance * Math.max(0, Math.min(1, fraction));
    contribution.balance -= amount;
    claimed += weighted ? amount * contribution.recoveryRate : amount;
  }
  return claimed;
}
export function tickBurn(this: Context, enemy: Enemy, dt: number) {
  const burn = enemy.burn;
  if (!burn || enemy.dead) return;
  const contributions = burn.contributions;
  if (!contributions) { enemy.burn = undefined; return; }
  const active = contributions.map(c => c.life > 0);
  burn.tick -= dt;
  while (burn.tick <= 1e-8 && !enemy.dead) {
    burn.tick += 0.5;
    const due = contributions.map((c, i) => active[i] ? Math.min(c.balance, c.rate * .5) : 0);
    const requested = due.reduce((sum, value) => sum + value, 0);
    const cap = Math.max(0, this.combatValue('burn.damage') * 2.5);
    const scale = requested > 0 ? Math.min(1, cap / requested) : 0;
    let applied = 0;
    for (let i = 0; i < contributions.length; i++) {
      const spent = due[i] * scale;
      contributions[i].balance = Math.max(0, contributions[i].balance - spent);
      applied += spent;
    }
    if (applied > 0) this.damage(enemy, applied, burn.spreadDepth + 1, false);
  }
  for (const c of contributions) c.life = Math.max(0, c.life - dt);
  settleContributions(this, enemy);
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
  source?: SpellPacket,
  sourceBudgetShare = 1,
) {
  this.burst(x, y, radius, "#ff9a43", "flame");
  const targets = this.enemies.filter(enemy => enemy !== exclude && !enemy.dead &&
    Math.hypot(enemy.x - x, enemy.y - y) <= radius);
  for (const enemy of targets) {
    this.applyBurn(enemy, stacks, depth, source, source ? sourceBudgetShare / targets.length : 1);
    this.damage(enemy, damage, depth + 1, false);
  }
}
export function fireImpact(
  this: Context,
  enemy: Enemy,
  damage: number,
  options: SpellOptions,
) {
  const radius = this.combatValue("fire.radius", { empowered: Number(!!options.empowered) });
  this.igniteExplosion(
    enemy.x,
    enemy.y,
    radius,
    damage * (options.empowered ? 0.5 : 0.22),
    enemy,
    options.depth ?? 0,
    options.empowered ? 2 : 1,
    options.weave,
    options.burnSplashShare ?? 1,
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
          this.combatValue("burn.spreadRadius"),
    )
    .sort(
      (a, b) =>
        Math.hypot(a.x - enemy.x, a.y - enemy.y) -
        Math.hypot(b.x - enemy.x, b.y - enemy.y),
    )
    .slice(0, this.combatValue("burn.spreadTargets"));
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
