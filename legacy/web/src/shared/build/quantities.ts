import type { BuildDiagnostic, Decision, ResourceId } from '../../contracts/build-resources.ts';
import type { CounterId, NumericDefinition, Quantity, QuantityUnit } from '../../contracts/build-rules.ts';
import { counterRanges } from './conditions.ts';

export interface QuantityRange { readonly unit: QuantityUnit; readonly min: number; readonly max: number }
export interface QuantityState {
  readonly numerics: Readonly<Record<string, number>>;
  readonly balances: Readonly<Partial<Record<ResourceId, number>>>;
  readonly counters: Readonly<Partial<Record<CounterId, number>>>;
}
const units: readonly QuantityUnit[] = ['ratio', 'count', 'ticks', 'distance', 'power', 'work', 'cold', 'heat', 'charge', 'opportunity'];
const resources: readonly ResourceId[] = ['power', 'work', 'cold', 'heat', 'charge', 'opportunity'];

export function analyzeQuantity(quantity: Quantity, numerics: Readonly<Record<string, NumericDefinition>>, definitionId?: string): Decision<QuantityRange> {
  const errors: BuildDiagnostic[] = [];
  const fail = (code: 'INVALID_QUANTITY' | 'INVALID_UNIT', path: string, message: string): undefined => {
    errors.push({ code, definitionId, path, message }); return undefined;
  };
  const visit = (q: Quantity, path: string, depth: number): QuantityRange | undefined => {
    if (!q || typeof q !== 'object' || Array.isArray(q) || depth > 32) return fail('INVALID_QUANTITY', path, 'Invalid or excessively nested quantity');
    if ('value' in q) {
      if (Object.keys(q).length !== 2 || !units.includes(q.unit) || !Number.isFinite(q.value) || Math.abs(q.value) > Number.MAX_SAFE_INTEGER) return fail('INVALID_QUANTITY', path, 'Invalid constant');
      return { unit: q.unit, min: q.value, max: q.value };
    }
    if (Object.keys(q).length !== 1) return fail('INVALID_QUANTITY', path, 'Quantity must have one expression');
    if ('stat' in q) {
      const stat = Object.hasOwn(numerics, q.stat) ? numerics[q.stat] : undefined;
      return stat ? { unit: stat.unit, min: stat.min, max: stat.max } : fail('INVALID_QUANTITY', path, `Unknown numeric ${q.stat}`);
    }
    if ('balance' in q) return resources.includes(q.balance) ? { unit: q.balance, min: 0, max: 1024 * 1_000_000_000 } : fail('INVALID_UNIT', path, 'Unknown resource');
    if ('counter' in q) {
      const range = Object.hasOwn(counterRanges, q.counter) ? counterRanges[q.counter] : undefined;
      return range ? { unit: q.counter === 'healthShare' ? 'ratio' : q.counter === 'reserveQ' ? 'power' : 'count', min: range[0], max: range[1] }
        : fail('INVALID_QUANTITY', path, 'Unknown counter');
    }
    const op = Object.keys(q)[0] as 'add' | 'subtract' | 'multiply' | 'divide' | 'min' | 'max';
    if (!['add', 'subtract', 'multiply', 'divide', 'min', 'max'].includes(op)) return fail('INVALID_QUANTITY', path, 'Unknown operator');
    const args = (q as unknown as Record<string, Quantity[]>)[op];
    if (!Array.isArray(args) || args.length !== 2) return fail('INVALID_QUANTITY', path, 'Binary expression requires two operands');
    const a = visit(args[0], `${path}.${op}[0]`, depth + 1), b = visit(args[1], `${path}.${op}[1]`, depth + 1);
    if (!a || !b) return undefined;
    let range: QuantityRange;
    if (op === 'multiply') {
      if (a.unit !== 'ratio' && b.unit !== 'ratio') return fail('INVALID_UNIT', path, 'Multiply requires a dimensionless factor');
      const products = [a.min * b.min, a.min * b.max, a.max * b.min, a.max * b.max];
      range = { unit: a.unit === 'ratio' ? b.unit : a.unit, min: Math.min(...products), max: Math.max(...products) };
    } else if (op === 'divide') {
      if (b.unit !== 'ratio') return fail('INVALID_UNIT', path, 'Divide requires a dimensionless divisor');
      if (b.min <= 0 && b.max >= 0) return fail('INVALID_QUANTITY', path, 'Divisor may be zero');
      const values = [a.min / b.min, a.min / b.max, a.max / b.min, a.max / b.max];
      range = { unit: a.unit, min: Math.min(...values), max: Math.max(...values) };
    } else {
      if (a.unit !== b.unit) return fail('INVALID_UNIT', path, `${op} operands have different units`);
      range = { unit: a.unit,
        min: op === 'add' ? a.min + b.min : op === 'subtract' ? a.min - b.max : Math[op](a.min, b.min),
        max: op === 'add' ? a.max + b.max : op === 'subtract' ? a.max - b.min : Math[op](a.max, b.max) };
    }
    return !Number.isFinite(range.min) || !Number.isFinite(range.max) || Math.max(Math.abs(range.min), Math.abs(range.max)) > Number.MAX_SAFE_INTEGER
      ? fail('INVALID_QUANTITY', path, 'Expression exceeds supported range') : range;
  };
  const range = visit(quantity, 'quantity', 0);
  return range && !errors.length ? { ok: true, value: range } : { ok: false, errors };
}

/** Missing state is an execution error, not a free zero-cost operation. */
export function evaluateQuantity(q: Quantity, state: QuantityState): number {
  let result: number;
  if ('value' in q) result = q.value;
  else if ('stat' in q) result = state.numerics[q.stat];
  else if ('balance' in q) result = state.balances[q.balance] ?? 0;
  else if ('counter' in q) result = state.counters[q.counter]!;
  else if ('add' in q) result = evaluateQuantity(q.add[0], state) + evaluateQuantity(q.add[1], state);
  else if ('subtract' in q) result = evaluateQuantity(q.subtract[0], state) - evaluateQuantity(q.subtract[1], state);
  else if ('multiply' in q) result = evaluateQuantity(q.multiply[0], state) * evaluateQuantity(q.multiply[1], state);
  else if ('divide' in q) result = evaluateQuantity(q.divide[0], state) / evaluateQuantity(q.divide[1], state);
  else if ('min' in q) result = Math.min(evaluateQuantity(q.min[0], state), evaluateQuantity(q.min[1], state));
  else result = Math.max(evaluateQuantity(q.max[0], state), evaluateQuantity(q.max[1], state));
  if (!Number.isFinite(result) || Math.abs(result) > Number.MAX_SAFE_INTEGER) throw new Error('INVALID_QUANTITY: runtime expression exceeds supported range');
  return result;
}
