import type { BuildErrorCode, Decision, ResourceId } from '../../contracts/build-resources.ts';
import type { RuleExecutionContext } from '../../contracts/build-execution.ts';
import type { CompiledRuleProgram, ConditionState, CounterId, OperationDefinition } from '../../contracts/build-rules.ts';
import type { ManualSpellInput, RuntimeMutation, SpellObject } from '../../contracts/build-runtime.ts';
import { evaluateCondition, counterRanges } from '../../shared/build/conditions.ts';
import { evaluateQuantity } from '../../shared/build/quantities.ts';
import { SpellResourceRuntime } from './SpellResourceRuntime.ts';

type Counters = Readonly<Partial<Record<CounterId, number>>>;
type Supply = Extract<OperationDefinition, { op: 'Supply' }>;
const resources: readonly ResourceId[] = ['power', 'work', 'cold', 'heat', 'charge', 'opportunity'];
const failure = (code: BuildErrorCode, message: string): Decision<never> => ({ ok: false, errors: [{ code, message }] });

/** Exact weighted split; a deterministic largest-remainder pass conserves even a one-Q receipt. */
function distribute(amount: number, weights: Supply['distributionWeights']): Partial<Record<ResourceId, number>> {
  const entries = resources.filter(id => (weights[id] ?? 0) > 0).map(id => {
    const [digits, exponent = '0'] = weights[id]!.toString().split('e');
    const shift = (digits.split('.')[1] ?? '').length - Number(exponent);
    return { id, numerator: BigInt(digits.replace('.', '')) * (shift < 0 ? 10n ** BigInt(-shift) : 1n),
      denominator: shift > 0 ? 10n ** BigInt(shift) : 1n };
  });
  if (!entries.length) throw new Error('Supply has no positive distribution weight');
  const denominator = entries.reduce((max, entry) => entry.denominator > max ? entry.denominator : max, 1n);
  const parts = entries.map(entry => ({ id: entry.id, weight: entry.numerator * (denominator / entry.denominator), quantity: 0, remainder: 0n }));
  const total = parts.reduce((sum, part) => sum + part.weight, 0n);
  for (const part of parts) {
    const product = BigInt(amount) * part.weight;
    part.quantity = Number(product / total); part.remainder = product % total;
  }
  let remainder = amount - parts.reduce((sum, part) => sum + part.quantity, 0);
  parts.sort((a, b) => a.remainder === b.remainder ? resources.indexOf(a.id) - resources.indexOf(b.id) : a.remainder > b.remainder ? -1 : 1);
  for (const part of parts) if (remainder > 0) { part.quantity++; remainder--; }
  return Object.fromEntries(parts.filter(part => part.quantity > 0).map(part => [part.id, part.quantity]));
}

/** Price all input suppliers first, then issue one atomic ledger receipt and acknowledge it at income stage. */
export class ManualSpellIncome {
  private readonly runtime: SpellResourceRuntime;
  private readonly receipts = new Map<string, { signature: string; program: CompiledRuleProgram; objectId: number;
    rules: ReadonlySet<string>; counters: Counters }>();
  constructor(runtime: SpellResourceRuntime) { this.runtime = runtime; }

  accept(input: ManualSpellInput, facts: Counters = {}): Decision<SpellObject> {
    const counters = { ...facts, humanCharacters: input.humanPositions.length, wordLength: input.wordLength };
    const multiplier = input.primaryMultiplier ?? 1;
    if (!Number.isFinite(multiplier) || multiplier <= 0 || multiplier > 256)
      return failure('INVALID_QUANTITY', 'Invalid primary input multiplier');
    for (const [key, value] of Object.entries(counters)) {
      const range = Object.hasOwn(counterRanges, key) ? counterRanges[key as CounterId] : undefined;
      if (!range || !Number.isFinite(value) || value! < range[0] || value! > range[1])
        return failure('INVALID_CONDITION_CONTEXT', 'Invalid manual input facts');
    }
    const signature = JSON.stringify({ id: input.id, wordLength: input.wordLength, wordSession: input.wordSession,
      humanPositions: [...input.humanPositions].sort((a, b) => a - b), shape: input.shape,
      position: { x: input.position.x, y: input.position.y }, targetId: input.targetId,
      tick: input.tick, lifeTicks: input.lifeTicks, applications: input.applications, processingUses: input.processingUses,
      multiplier, counters: Object.entries(counters).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0) });
    const prior = this.receipts.get(input.id);
    if (prior) return prior.signature === signature && prior.program === input.program
      ? { ok: true, value: this.runtime.getObject(prior.objectId)! }
      : failure('RECEIPT_CONFLICT', 'Manual income replay changed the input or build');
    const program = input.program;
    const condition: ConditionState = { mainBook: program.mainBook, allocated: new Set(program.allocated), owned: program.owned, modes: program.modes,
      permits: new Set(program.permits), buildCapabilities: new Set(program.capabilities), talentCapabilities: new Set(program.talentCapabilities),
      properties: { ageTicks: 0, remainingTicks: input.lifeTicks }, counters };
    let primaryPowerQ = 0;
    const auxiliary: Partial<Record<ResourceId, number>> = {}, applied = new Set<string>(), kinds = new Set<string>();
    try {
      for (const { definition } of program.byEvent['manual.complete'] ?? []) {
        const op = definition.operation;
        if (op.op !== 'Supply') continue;
        if (definition.stage !== 'income' || definition.resourceCost.length || definition.repeat.limit !== 1)
          return failure('INVALID_DEFINITION', 'Supply must run once at the atomic income boundary without fees');
        if (kinds.has(op.incomeKind)) return failure('INVALID_DEFINITION', 'Duplicate input supplier');
        kinds.add(op.incomeKind);
        if (!evaluateCondition(definition.when, condition)) continue;
        const perCharacter = evaluateQuantity(op.amountPerHumanCharacter, { numerics: program.numerics, counters,
          balances: Object.fromEntries(resources.map(id => [id, this.runtime.balance(0, id)])) });
        const amount = Math.floor(perCharacter * input.humanPositions.length * (op.incomeKind === 'primary' ? multiplier : 1));
        if (!Number.isSafeInteger(amount) || amount < 0 || amount > 1024 * 1_000_000_000)
          return failure('INVALID_QUANTITY', 'Manual income exceeds the finite input budget');
        if (op.incomeKind === 'primary') primaryPowerQ = amount;
        else Object.assign(auxiliary, distribute(amount, op.distributionWeights));
        applied.add(definition.id);
      }
    } catch (error) { return failure('INVALID_QUANTITY', error instanceof Error ? error.message : String(error)); }
    if (!applied.size) return failure('INSUFFICIENT_RESOURCE', 'No supplier accepts this input');
    const { work = 0, ...auxiliaryResourcesQ } = auxiliary;
    const result = this.runtime.acceptManual({ ...input, primaryPowerQ, auxiliaryWorkQ: work, auxiliaryResourcesQ });
    if (result.ok) this.receipts.set(input.id, { signature, program, objectId: result.value.id, rules: applied, counters: Object.freeze(counters) });
    return result;
  }

  supply(context: RuleExecutionContext, operation: Supply): Decision<RuntimeMutation> {
    const { event, rule, object } = context, receipt = this.receipts.get(object.rootReceiptId);
    if (!receipt || receipt.objectId !== object.id || receipt.program !== object.program || object.derived
      || event.event !== 'manual.complete' || event.stage !== 'income' || event.tick !== object.createdAtTick
      || rule.definition.operation !== operation || !receipt.rules.has(rule.definition.id)
      || Object.keys(receipt.counters).length !== Object.keys(event.counters).length
      || Object.entries(receipt.counters).some(([key, value]) => event.counters[key as CounterId] !== value))
      return failure('INVALID_RESOURCE_TRANSACTION', 'Supply requires its original paid human input');
    // No ready object here: lifecycle must finish ALL income rules before assembly/instant hits.
    return { ok: true, value: { objects: [], transaction: { createdLotIds: [], owners: [], facts: [] } } };
  }
}
