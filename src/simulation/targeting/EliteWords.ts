import { WordPool } from "../../vocabulary/index.ts";
import type { CombatTarget } from "../../combat/model.ts";
import type { EliteDefinition } from "../../contracts/content.ts";
import type { CombatRuntime } from "../Runtime.ts";

export type EnemyWordContext = Pick<
  CombatRuntime,
  "targets" | "config" | "mode" | "chapter" | "loopCount" | "pool" | "rng"
>;
type WordPreference = EliteDefinition["wordPreference"];
type WordTarget = { word: string; dead?: boolean };
type PoolIndex = {
  pool: WordPool;
  members: Set<string>;
  groups: { key: string; length: number; initial: string; count: number }[];
};
const cache = new WeakMap<WordPool, { all: PoolIndex; punctuated: PoolIndex | null }>();

function indexPool(pool: WordPool): PoolIndex {
  const counts = new Map<string, PoolIndex["groups"][number]>();
  for (const entry of pool.words) {
    const length = entry.word.length, initial = entry.word[0];
    const key = `${length}:${initial}`;
    const group = counts.get(key);
    if (group) group.count++;
    else counts.set(key, { key, length, initial, count: 1 });
  }
  return { pool, members: new Set(pool.words.map((entry) => entry.word)), groups: [...counts.values()] };
}

/** Compare the same four fallback tiers used by WordPool, without scanning its words. */
function selectionTier(
  index: PoolIndex,
  targets: WordTarget[],
  recent: readonly string[],
  min: number,
  max: number,
) {
  const live = targets.filter((target) => !target.dead);
  const initials = new Set(live.map((target) => target.word[0]));
  const counts = (words: Iterable<string>) => {
    const result = new Map<string, number>();
    for (const word of new Set(words)) {
      if (!index.members.has(word)) continue;
      const key = `${word.length}:${word[0]}`;
      result.set(key, (result.get(key) ?? 0) + 1);
    }
    return result;
  };
  const used = counts(live.map((target) => target.word));
  const recentCounts = counts(recent);
  let tier = Infinity;
  for (const group of index.groups) {
    if (group.length < min || group.length > max) continue;
    if (!initials.has(group.initial)) {
      if (group.count > (recentCounts.get(group.key) ?? 0)) return 0;
      tier = Math.min(tier, 1);
    } else {
      tier = Math.min(tier, group.count > (used.get(group.key) ?? 0) ? 2 : 3);
    }
  }
  return tier;
}

export function choosePreferredWord(
  pool: WordPool,
  targets: WordTarget[],
  min: number,
  max: number,
  preference: WordPreference,
  rng: () => number,
) {
  if (preference !== "punctuated") return pool.choose(targets, min, max);
  let entry = cache.get(pool);
  if (!entry) {
    const words = pool.words.filter((word) => /['-]/.test(word.word));
    entry = {
      all: indexPool(pool),
      punctuated: words.length && words.length < pool.words.length
        ? indexPool(new WordPool(words, pool.rng))
        : null,
    };
    cache.set(pool, entry);
  }
  const preferred = entry.punctuated;
  if (!preferred) return pool.choose(targets, min, max);
  const tier = selectionTier(preferred, targets, pool.recent, min, max);
  if (
    !Number.isFinite(tier) ||
    tier > selectionTier(entry.all, targets, pool.recent, min, max) ||
    rng() >= 0.5
  ) return pool.choose(targets, min, max);
  // The two pools share recency as well as the same seeded RNG.
  preferred.pool.recent.splice(0, preferred.pool.recent.length, ...pool.recent);
  const choice = preferred.pool.choose(targets, min, max);
  pool.recent.push(choice.word);
  if (pool.recent.length > 15) pool.recent.shift();
  return choice;
}

export function chooseEnemyWord(
  context: EnemyWordContext,
  extra = false,
  exclude: CombatTarget | null = null,
  preference?: WordPreference,
) {
  const list = context.targets().filter((target) => target !== exclude);
  const max = context.config.progressive
    ? Math.min(
        24,
        context.mode.baseLen +
          context.chapter * (context.mode.rank < 2 ? 1 : 2) +
          context.loopCount +
          (extra ? 1 : 0),
      )
    : 24;
  const range = context.config.progressive && context.rng() < 0.28
    ? [1, context.mode.baseLen]
    : [1, max];
  return choosePreferredWord(context.pool, list, range[0], range[1], preference, context.rng);
}
