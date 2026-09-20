import type { Relic } from "../../contracts/content.ts";
export function eligibleRelic(
  relic: Pick<Relic, "id" | "max"> & Partial<Relic>,
  context: {
    book: string;
    levels: Readonly<Record<string, number>>;
    shortest: number;
    longest: number;
  },
) {
  return (
    (context.levels[relic.id] || 0) < relic.max &&
    (!relic.book || relic.book === context.book) &&
    (!relic.requires || relic.requires.every((id) => context.levels[id])) &&
    (!relic.minWordLength || context.longest >= relic.minWordLength) &&
    (!relic.maxWordLength || context.shortest <= relic.maxWordLength)
  );
}
