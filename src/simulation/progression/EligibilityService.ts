import type { Relic } from "../../contracts/content.ts";
import type { CombatCapability } from "../../contracts/combat-weave.ts";
export function eligibleRelic(
  relic: Pick<Relic, "id" | "max"> & Partial<Relic>,
  context: {
    book: string;
    levels: Readonly<Record<string, number>>;
    shortest: number;
    longest: number;
    capabilities?: readonly CombatCapability[];
    definitions?: readonly Relic[];
  },
) {
  return (
    (context.levels[relic.id] || 0) < relic.max &&
    (!relic.book || relic.book === context.book) &&
    (!relic.requires || relic.requires.every((id) => context.levels[id])) &&
    (!relic.requiresLevels ||
      Object.entries(relic.requiresLevels).every(
        ([id, level]) => (context.levels[id] ?? 0) >= level,
      )) &&
    (!relic.needs ||
      relic.needs.every((capability) => context.capabilities?.includes(capability))) &&
    (!relic.excludes || relic.excludes.every((id) => !context.levels[id])) &&
    !(context.definitions ?? []).some(
      (owned) => context.levels[owned.id] && owned.excludes?.includes(relic.id),
    ) &&
    (!relic.minWordLength || context.longest >= relic.minWordLength) &&
    (!relic.maxWordLength || context.shortest <= relic.maxWordLength)
  );
}
