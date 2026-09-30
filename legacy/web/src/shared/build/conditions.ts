import type { BuildDiagnostic } from '../../contracts/build-resources.ts';
import type { Condition, ConditionContext, ConditionState, CounterId, PropertyId } from '../../contracts/build-rules.ts';

export const capabilities = ['cold', 'heat', 'charge', 'storage', 'fracture', 'transfer', 'copy',
  'guard', 'release', 'recover', 'ongoing', 'field', 'letters', 'letterStorage', 'transport', 'merge', 'summon'] as const;
export const propertyTypes: Readonly<Record<PropertyId, 'number' | 'string'>> = {
  material: 'string', shape: 'string', integrity: 'number', heat: 'number', ageTicks: 'number', remainingTicks: 'number', distance: 'number', endReason: 'string',
};
export const counterRanges: Readonly<Record<CounterId, readonly [number, number]>> = {
  humanCharacters: [0, 4096], wordLength: [1, 4096], healthShare: [0, 1],
  targetCount: [0, 65536], reserveQ: [0, 1024 * 1_000_000_000], wordErrors: [0, 1_000_000], matchedCharacters: [0, 72], targetPowerRatio: [0, 1_000_000],
};
const books = ['flame', 'storm', 'frost', 'spirit'];
const allowed: Record<ConditionContext, readonly string[]> = {
  purchase: ['all', 'any', 'not', 'mainBook', 'allocated', 'capability'],
  acquisition: ['all', 'any', 'not', 'mainBook', 'allocated', 'permit', 'owned', 'capability', 'counter'],
  runtime: ['all', 'any', 'not', 'mainBook', 'allocated', 'permit', 'owned', 'capability', 'mode', 'counter', 'objectProperty'],
};

/** Validate once at content/compilation boundaries, never in the per-frame rule loop. */
export function validateCondition(input: unknown, context: ConditionContext, definitionId?: string): BuildDiagnostic[] {
  const errors: BuildDiagnostic[] = [];
  const visit = (value: unknown, path: string, depth: number) => {
    const fail = (message: string) => errors.push({ code: 'INVALID_CONDITION_CONTEXT', definitionId, path, message });
    if (!value || typeof value !== 'object' || Array.isArray(value) || depth > 32) { fail('Invalid or excessively nested condition'); return; }
    const v = value as Record<string, unknown>;
    const keys = Object.keys(v);
    const variants = keys.filter(k => ['all', 'any', 'not', 'mainBook', 'allocated', 'permit', 'owned', 'capability', 'mode', 'counter', 'objectProperty'].includes(k));
    if (variants.length !== 1) { fail('Condition must have exactly one registered predicate'); return; }
    const kind = variants[0];
    if (!allowed[context].includes(kind)) { fail(`${kind} is unavailable in ${context}`); return; }
    const extras = kind === 'owned' ? ['minLevel'] : kind === 'capability' ? ['source'] : kind === 'mode' ? ['value']
      : kind === 'counter' || kind === 'objectProperty' ? ['comparison', 'value'] : [];
    if (keys.some(k => k !== kind && !extras.includes(k))) { fail('Unknown condition field'); return; }
    if (kind === 'all' || kind === 'any') {
      if (!Array.isArray(v[kind])) { fail(`${kind} requires a list`); return; }
      (v[kind] as unknown[]).forEach((child, i) => visit(child, `${path}.${kind}[${i}]`, depth + 1));
    } else if (kind === 'not') visit(v.not, `${path}.not`, depth + 1);
    else if (kind === 'mainBook') { if (!books.includes(v.mainBook as string)) fail('Unknown book'); }
    else if (kind === 'allocated') { if (typeof v.allocated !== 'string' || !v.allocated) fail('Missing talent ID'); }
    else if (kind === 'permit') { if (typeof v.permit !== 'string' || !/^permit:.+/.test(v.permit)) fail('Invalid permit ID'); }
    else if (kind === 'owned') {
      if (typeof v.owned !== 'string' || !v.owned || !Number.isSafeInteger(v.minLevel) || (v.minLevel as number) < 1) fail('Invalid asset level');
    } else if (kind === 'capability') {
      if (!(capabilities as readonly unknown[]).includes(v.capability) || !['build', 'talent'].includes(v.source as string)) fail('Unknown capability or source');
      else if (context === 'purchase' && v.source !== 'talent') fail('Purchases cannot depend on temporary build capabilities');
    } else if (kind === 'mode') {
      if (typeof v.mode !== 'string' || !v.mode || typeof v.value !== 'string' || !v.value) fail('Invalid mode predicate');
    } else if (kind === 'objectProperty') {
      const type = Object.hasOwn(propertyTypes, v.objectProperty as string) ? propertyTypes[v.objectProperty as PropertyId] : undefined;
      if (!type || typeof v.value !== type || !['eq', 'gte'].includes(v.comparison as string)
          || (type === 'string' && v.comparison !== 'eq') || (type === 'number' && !Number.isFinite(v.value))) fail('Unknown property, comparison, or value type');
    } else if (kind === 'counter') {
      if (!Object.hasOwn(counterRanges, v.counter as string) || !['gte', 'lte'].includes(v.comparison as string) || !Number.isFinite(v.value)) fail('Unknown counter or comparison');
      if (context === 'acquisition' && v.counter !== 'wordLength') fail('Acquisition may inspect vocabulary bounds, not transient combat counters');
    }
  };
  visit(input, 'condition', 0);
  return errors;
}

/** Input must already pass validateCondition. Missing transient data does not grant an effect. */
export function evaluateCondition(condition: Condition, state: ConditionState): boolean {
  return evaluateKnown(condition, state) === true;
}
function evaluateKnown(condition: Condition, state: ConditionState): boolean | undefined {
  if ('all' in condition) {
    const values = condition.all.map(c => evaluateKnown(c, state));
    return values.includes(false) ? false : values.includes(undefined) ? undefined : true;
  }
  if ('any' in condition) {
    const values = condition.any.map(c => evaluateKnown(c, state));
    return values.includes(true) ? true : values.includes(undefined) ? undefined : false;
  }
  if ('not' in condition) {
    const value = evaluateKnown(condition.not, state);
    return value === undefined ? undefined : !value;
  }
  if ('mainBook' in condition) return condition.mainBook === state.mainBook;
  if ('allocated' in condition) return state.allocated.has(condition.allocated);
  if ('permit' in condition) return state.permits.has(condition.permit);
  if ('mode' in condition) return state.modes?.[condition.mode] === undefined ? undefined : state.modes[condition.mode] === condition.value;
  if ('owned' in condition) return (state.owned[condition.owned] ?? 0) >= condition.minLevel;
  if ('capability' in condition) return (condition.source === 'talent' ? state.talentCapabilities : state.buildCapabilities).has(condition.capability);
  if ('objectProperty' in condition) {
    const value = state.properties?.[condition.objectProperty];
    return value === undefined ? undefined : condition.comparison === 'eq' ? value === condition.value : typeof value === 'number' && value >= Number(condition.value);
  }
  const value = state.counters?.[condition.counter];
  return value === undefined ? undefined : condition.comparison === 'gte' ? value >= condition.value : value <= condition.value;
}
