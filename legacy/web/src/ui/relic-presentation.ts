import type { Relic, RelicRarity } from "../contracts/content.ts";
import type { CombatCapability } from "../contracts/combat-weave.ts";
import { relicConnections } from "../shared/combat-capabilities.ts";

export const capabilityNames: Readonly<Record<CombatCapability, string>> = {
  cold: "寒气与冰晶",
  heat: "热量",
  conduction: "连锁传递",
  carrier: "保存法术",
  guard: "防御",
  release: "释放",
  recovery: "回收",
};

export function relicRelationLabel(
  relic: Relic,
  capabilities: readonly CombatCapability[],
): string {
  return relicConnections(relic, capabilities)
    .map((capability) => capabilityNames[capability])
    .join(" · ");
}

export const RELIC_RARITIES = {
  common: { label: "普通", order: 0 },
  rare: { label: "稀有", order: 1 },
  curse: { label: "诅咒", order: 2 },
  awaken: { label: "觉醒", order: 3 },
} as const satisfies Record<RelicRarity, { label: string; order: number }>;

export const relicRarity = (relic: Pick<Relic, "rarity">): RelicRarity =>
  relic.rarity ?? "common";

// Sort a copy for display only: reward pools retain their seeded draw order.
// Stable sorting preserves the catalog's order within each rarity.
export function sortRelicsByRarity(relics: readonly Relic[]): Relic[] {
  return [...relics].sort(
    (a, b) =>
      RELIC_RARITIES[relicRarity(a)].order -
      RELIC_RARITIES[relicRarity(b)].order,
  );
}

import { describeRelic as describe } from "../shared/relic-values.ts";
import { ValueRules } from "../shared/ValueRules.ts";
import { combatValues } from "../content/combat-values.ts";
import { BOOKS } from "../content/catalog.ts";
import { previewDefaults } from "../content/preview-defaults.ts";
import type { RelicPreview } from "../shared/relic-values.ts";
const rules = new ValueRules(combatValues);
export const describeRelic = (relic: Relic, definitions: readonly Relic[], game?: RelicPreview, formulas = false, candidate = false) =>
  describe(relic, definitions, rules, BOOKS, previewDefaults, game, formulas, candidate);
