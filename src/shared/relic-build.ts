import type { Relic } from "../contracts/content.ts";
import type { ValueDefinitions } from "../contracts/values.ts";
import {
  combatStats,
  type CombatStats,
  type CombatStat,
} from "../contracts/stats.ts";
import type { DamageModifier } from "../contracts/relic-rules.ts";

export function collectValues(
  base: ValueDefinitions,
  relics: readonly Relic[],
): ValueDefinitions {
  const result = { ...base };
  for (const relic of relics)
    for (const [id, value] of Object.entries(relic.values ?? {})) {
      if (id in result) throw new Error(`Duplicate formula: ${id}`);
      result[id] = value;
    }
  for (const relic of relics)
    (relic.hooks ?? []).forEach((hook, index) => {
      for (const [field, value] of Object.entries(hook.effect))
        if (typeof value === "number") {
          const key = `${relic.id}.hook.${index}.${field}`;
          if (key in result) throw new Error(`Duplicate formula: ${key}`);
          result[key] =
            field === "amount" &&
            (hook.effect.kind === "heal" || hook.effect.kind === "shield")
              ? {
                  op: "mul",
                  args: [
                    value,
                    { input: `rank.${relic.id}`, label: `${relic.name}层数` },
                  ],
                }
              : value;
        }
    });
  for (const relic of relics)
    if (relic.damageModifiers?.length) {
      const terms = relic.damageModifiers.map((rule, index) => ({
        when: {
          input: `modifier.${relic.id}.${index}`,
          label:
            rule.belowHealth === undefined
              ? `持有${relic.name}`
              : `持有${relic.name}且生命低于最大生命×${rule.belowHealth}`,
        },
        yes: rule.perStack
          ? {
              op: "pow" as const,
              args: [
                rule.factor,
                { input: `rank.${relic.id}`, label: `${relic.name}层数` },
              ],
            }
          : rule.factor,
        no: 1,
      }));
      const key = `${relic.id}.damageMultiplier`;
      if (key in result) throw new Error(`Duplicate formula: ${key}`);
      result[key] = terms.length === 1 ? terms[0] : { op: "mul", args: terms };
    }
  return Object.freeze(result);
}
export function damageModifierValue(
  rule: DamageModifier,
  stacks: number,
  player: { hp: number; maxHp: number },
) {
  return !stacks ||
    (rule.belowHealth !== undefined &&
      player.hp >= player.maxHp * rule.belowHealth)
    ? 1
    : Math.pow(rule.factor, rule.perStack ? stacks : 1);
}
export function relicMultiplier(
  definitions: readonly Relic[],
  levels: Readonly<Record<string, number>>,
  player: { hp: number; maxHp: number },
) {
  return definitions
    .flatMap((r) =>
      (r.damageModifiers ?? []).map((rule) => ({ id: r.id, rule })),
    )
    .sort(
      (a, b) => a.rule.priority - b.rule.priority || a.id.localeCompare(b.id),
    )
    .reduce(
      (result, { id, rule }) =>
        result * damageModifierValue(rule, levels[id] || 0, player),
      1,
    );
}
export function buildStats(
  definitions: readonly Relic[],
  levels: Readonly<Record<string, number>>,
): CombatStats {
  return Object.fromEntries(
    combatStats.map((stat) => [
      stat,
      definitions.reduce(
        (sum, r) => sum + (levels[r.id] || 0) * (r.grants?.[stat] || 0),
        0,
      ),
    ]),
  ) as unknown as CombatStats;
}
export function wordModifierApplies(
  definitions: readonly Relic[],
  levels: Readonly<Record<string, number>>,
  stat: CombatStat,
  length: number,
) {
  return definitions.some(
    (r) =>
      !!levels[r.id] &&
      !!r.grants?.[stat] &&
      (r.minWordLength === undefined || length >= r.minWordLength) &&
      (r.maxWordLength === undefined || length <= r.maxWordLength),
  );
}
