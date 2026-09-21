import { damageModifierValue, wordModifierApplies } from "../shared/relic-build.ts";
import { combatStats, type CombatStats } from "../contracts/stats.ts";
import type { Relic } from "../contracts/content.ts";
import type { DamageModifier, RelicHook } from "../contracts/relic-rules.ts";
import type { Player } from "../combat/model.ts";

export interface RelicContext {
  player: Player;
  relics: Record<string, number>;
  casts: number;
  perfectWords: number;
  bookData: { color: string };
  heal(amount: number): void;
  payBloodPrice(): void;
  ring(x: number, y: number, radius: number, color: string, life: number): void;
  clearBullets(x: number, y: number, radius: number): void;
  explode(
    x: number,
    y: number,
    radius: number,
    damage: number,
    exclude: null,
    depth: number,
    color: string,
  ): void;
  burst(
    x: number,
    y: number,
    radius: number,
    color: string,
    kind: string,
  ): void;
}

/** Index once at session construction; levels remain authoritative in the simulation. */
export class RelicRules {
  private readonly definitions: readonly Relic[];
  wordModifierApplies(levels: Readonly<Record<string, number>>, stat: import("../contracts/stats.ts").CombatStat, length: number) {
    return wordModifierApplies(this.definitions, levels, stat, length);
  }
  private readonly grants = new Map<string, { id: string; amount: number }[]>();
  createStats(levels: () => Record<string, number>): CombatStats {
    const descriptors: PropertyDescriptorMap = {};
    for (const stat of combatStats)
      descriptors[stat] = {
        enumerable: true,
        get: () => {
          let value = 0;
          for (const grant of this.grants.get(stat) ?? [])
            value += (levels()[grant.id] || 0) * grant.amount;
          return value;
        },
      };
    return Object.freeze(
      Object.defineProperties({}, descriptors),
    ) as CombatStats;
  }
  private readonly modifiers: { id: string; rule: DamageModifier }[];
  private readonly hooks: Record<
    RelicHook["phase"],
    { id: string; rule: RelicHook }[]
  > = { acquire: [], afterCast: [] };

  constructor(definitions: readonly Relic[]) {
    this.definitions = definitions;
    for (const definition of definitions)
      for (const [stat, amount] of Object.entries(definition.grants ?? {})) {
        const list = this.grants.get(stat) ?? [];
        list.push({ id: definition.id, amount });
        this.grants.set(stat, list);
      }
    this.modifiers = definitions.flatMap((d) =>
      (d.damageModifiers ?? []).map((rule) => ({ id: d.id, rule })),
    );
    for (const d of definitions)
      for (const rule of d.hooks ?? [])
        this.hooks[rule.phase].push({ id: d.id, rule });
    const order = (
      a: { id: string; rule: { priority: number } },
      b: { id: string; rule: { priority: number } },
    ) => a.rule.priority - b.rule.priority || a.id.localeCompare(b.id);
    this.modifiers.sort(order);
    this.hooks.acquire.sort(order);
    this.hooks.afterCast.sort(order);
  }

  damageMultiplier(context: Pick<RelicContext, "player" | "relics">) {
    let result = 1;
    for (const { id, rule } of this.modifiers) {
      const stacks = context.relics[id] || 0;
      result *= damageModifierValue(rule, stacks, context.player);
    }
    return result;
  }

  run(
    phase: RelicHook["phase"],
    context: RelicContext,
    options: { id?: string; perfect?: boolean } = {},
  ) {
    const groups = new Set<string>();
    for (const { id, rule } of this.hooks[phase]) {
      const stacks = context.relics[id] || 0;
      if (!stacks || (options.id !== undefined && options.id !== id)) continue;
      if (rule.perfectOnly && !options.perfect) continue;
      if (rule.every && context[rule.counter ?? "casts"] % rule.every !== 0)
        continue;
      if (rule.exclusiveGroup) {
        if (groups.has(rule.exclusiveGroup)) continue;
        groups.add(rule.exclusiveGroup);
      }
      const e = rule.effect,
        p = context.player;
      switch (e.kind) {
        case "heal":
          context.heal(e.amount * stacks);
          break;
        case "maxHealth":
          p.maxHp += e.amount;
          context.heal(e.heal);
          break;
        case "dashCharge":
          p.maxDash += e.amount;
          p.dash = Math.min(p.maxDash, p.dash + e.amount);
          break;
        case "bloodPrice":
          context.payBloodPrice();
          break;
        case "shield":
          p.shield = Math.min(e.cap, p.shield + e.amount * stacks);
          context.ring(p.x, p.y, 48, e.color, 0.5);
          break;
        case "pulse":
          context.clearBullets(p.x, p.y, e.radius);
          context.explode(
            p.x,
            p.y,
            e.radius,
            e.damage,
            null,
            0,
            context.bookData.color,
          );
          context.burst(p.x, p.y, e.radius, context.bookData.color, "shock");
          break;
      }
    }
  }
}
