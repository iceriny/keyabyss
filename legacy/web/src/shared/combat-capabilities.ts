import {
  combatCapabilities,
  type CombatCapability,
} from "../contracts/combat-weave.ts";
import type { Book, Relic } from "../contracts/content.ts";

/** Capabilities are supplied by active content, never inferred from IDs. */
export function collectCapabilities(
  book: Book,
  relics: readonly Relic[],
  levels: Readonly<Record<string, number>>,
  extras: readonly CombatCapability[] = [],
): CombatCapability[] {
  const owned = new Set<CombatCapability>([
    ...(book.combat?.capabilities ?? []),
    ...extras,
  ]);
  for (const relic of relics)
    if ((levels[relic.id] ?? 0) > 0)
      for (const capability of relic.provides ?? []) owned.add(capability);
  return combatCapabilities.filter((capability) => owned.has(capability));
}

/** A provider can introduce a capability without requiring it beforehand. */
export function relicConnections(
  relic: Relic,
  owned: readonly CombatCapability[],
): CombatCapability[] {
  const related = new Set([...(relic.needs ?? []), ...(relic.modifies ?? [])]);
  return combatCapabilities.filter(
    (capability) => related.has(capability) && owned.includes(capability),
  );
}
