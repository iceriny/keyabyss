import type { Relic } from "../contracts/content.ts";
import type { CombatCapability } from "../contracts/combat-weave.ts";
import type { CombatStats } from "../contracts/stats.ts";

const switches = new Set(['carrierGuard', 'carrierRelease', 'carrierRetain', 'carrierRelay', 'guardNewest', 'thermalRelease', 'mergePayload', 'copyInheritance', 'paperRecovery', 'missRecovery', 'markCarrier', 'markSpread', 'summonTransport', 'reservePersist', 'recoveryExtract']);
export function eligibleRelic(
  relic: Pick<Relic, "id" | "max"> & Partial<Relic>,
  context: {
    book: string;
    levels: Readonly<Record<string, number>>;
    shortest: number;
    longest: number;
    capabilities?: readonly CombatCapability[];
    definitions?: readonly Relic[];
    stats?: Partial<CombatStats>;
  },
) {
  const grants = Object.entries(relic.grants ?? {});
  const opensPath = context.definitions?.some(item => item.requires?.includes(relic.id) || item.requiresLevels?.[relic.id] || item.evolution?.from === relic.id);
  const duplicateSwitch = context.stats && !opensPath && grants.length > 0 && grants.every(([key, value]) => switches.has(key) && value! > 0 && (context.stats![key as keyof CombatStats] ?? 0) > 0);
  return (
    !relic.eventOnly &&
    !duplicateSwitch &&
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
