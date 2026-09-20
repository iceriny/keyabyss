import type { CombatStats } from "../contracts/stats.ts";
export function summonCapacity(
  summons: boolean,
  stats: CombatStats,
  ultimateTime: number,
) {
  return (
    (summons ? 3 : 0) +
    (stats.summonStacks || 0) +
    (stats.summonBond && !summons && !stats.summonStacks ? 1 : 0) +
    (stats.summonLegion ? 3 : 0) +
    (summons && ultimateTime > 0 ? 4 : 0)
  );
}
