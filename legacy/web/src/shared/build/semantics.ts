import type { BookId } from '../../contracts/content-ids.ts';
import type { Decision } from '../../contracts/build-resources.ts';
import type { SemanticProfile } from '../../contracts/build-rules.ts';

export interface ConceptDefinition {
  readonly id: string;
  readonly aliases: readonly string[];
  readonly books: Readonly<Record<BookId, number>>;
}
export interface SemanticVocabulary {
  normalize(weights: Readonly<Record<string, number>>): Decision<Readonly<Record<string, number>>>;
  bookAffinity(weights: Readonly<Record<string, number>>): Decision<Readonly<Record<BookId, number>>>;
}

/** A caller injects the vocabulary so simulation/shared code has no global catalog dependency. */
export function createSemanticVocabulary(concepts: readonly ConceptDefinition[], bookIds: readonly BookId[]): SemanticVocabulary {
  if (!bookIds.length || new Set(bookIds).size !== bookIds.length) throw new Error('Invalid book dimensions');
  const aliases = new Map<string, string>(), definitions = new Map<string, ConceptDefinition>();
  for (const input of concepts) {
    if (!input.id || definitions.has(input.id) || Object.keys(input.books).length !== bookIds.length
        || bookIds.some(book => !Object.hasOwn(input.books, book))
        || Object.values(input.books).some(n => !Number.isFinite(n) || n < 0)
        || Math.abs(Object.values(input.books).reduce((a, b) => a + b, 0) - 1) > 1e-10) throw new Error(`Invalid concept: ${input.id}`);
    const definition = { id: input.id, aliases: [...input.aliases], books: { ...input.books } };
    definitions.set(input.id, definition);
    for (const alias of [input.id, ...input.aliases]) {
      if (!alias || aliases.has(alias)) throw new Error(`Ambiguous concept alias: ${alias}`);
      aliases.set(alias, input.id);
    }
  }
  const normalize: SemanticVocabulary['normalize'] = weights => {
    const normalized: Record<string, number> = {};
    let sum = 0;
    for (const [alias, value] of Object.entries(weights).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) {
      const id = aliases.get(alias);
      if (!id || !Number.isFinite(value) || value <= 0) return { ok: false, errors: [{ code: 'INVALID_DEFINITION', path: `concepts.${alias}`, message: 'Unknown concept or invalid positive weight' }] };
      normalized[id] = (normalized[id] ?? 0) + value; sum += value;
    }
    if (!Number.isFinite(sum) || sum <= 0) return { ok: false, errors: [{ code: 'INVALID_DEFINITION', path: 'concepts', message: 'At least one positive concept weight is required' }] };
    return { ok: true, value: Object.freeze(Object.fromEntries(Object.keys(normalized).sort().map(id => [id, normalized[id] / sum]))) };
  };
  return Object.freeze({ normalize, bookAffinity: (weights: Readonly<Record<string, number>>) => {
    const normalized = normalize(weights);
    if (!normalized.ok) return normalized;
    const books = Object.fromEntries(bookIds.map(book => [book, 0])) as Record<BookId, number>;
    for (const [id, weight] of Object.entries(normalized.value)) for (const book of Object.keys(books) as BookId[]) books[book] += definitions.get(id)!.books[book] * weight;
    return { ok: true as const, value: Object.freeze(books) };
  } });
}

function similarity(left: readonly string[], right: readonly string[]): number {
  const a = new Set(left), b = new Set(right);
  if (!a.size || !b.size) return 0;
  const intersection = [...a].filter(value => b.has(value)).length;
  return intersection / (a.size + b.size - intersection);
}

/** The same normalized groups feed both atlases. Growth/evolution edges remain separate decisions. */
export function semanticProximity(a: SemanticProfile, b: SemanticProfile): number {
  return .40 * similarity(a.operationKinds, b.operationKinds)
    + .25 * similarity(a.objectKinds, b.objectKinds)
    + .20 * Math.max(similarity(a.outputProperties, b.inputProperties), similarity(b.outputProperties, a.inputProperties))
    + .15 * similarity(a.tradeoffKinds, b.tradeoffKinds);
}
