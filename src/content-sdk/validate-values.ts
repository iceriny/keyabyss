import type { Book, Relic } from "../contracts/content.ts";
import type { ValueDefinitions } from "../contracts/values.ts";
import { ValueRules } from "../shared/ValueRules.ts";
import { collectValues } from "../shared/relic-build.ts";

export function validateValues(
  base: ValueDefinitions,
  relics: readonly Relic[],
  books: readonly Book[],
) {
  const rules = new ValueRules(collectValues(base, relics));
  for (const r of relics) {
    for (const match of r.description?.template.matchAll(/\{([^{}]+)\}/g) ?? [])
      if (match[1] !== "description") rules.expression(match[1]);
    if (
      r.description?.wordLength !== undefined &&
      (!Number.isInteger(r.description.wordLength) ||
        r.description.wordLength <= 0)
    )
      throw new Error(`Invalid preview word length: ${r.id}`);
  }
  for (const book of books)
    for (const value of Object.values(book.castMultiplier))
      if (!Number.isFinite(value) || value <= 0)
        throw new Error(`Invalid cast multiplier: ${book.id}`);
  return rules;
}
