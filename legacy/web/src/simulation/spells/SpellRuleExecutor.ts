import type { BuildDiagnostic, Decision, ResourceId } from '../../contracts/build-resources.ts';
import type { RuleEventResult, RuleExecutionContext, RuleExecutionOutcome, RuleOperationResult, SpellRuleEvent, SpellRuleWorld } from '../../contracts/build-execution.ts';
import type { CompiledRuleProgram, ConditionState, CounterId, Quantity, RuleDefinition } from '../../contracts/build-rules.ts';
import type { SpellObject } from '../../contracts/build-runtime.ts';
import { counterRanges, evaluateCondition } from '../../shared/build/conditions.ts';
import { eventStages } from '../../shared/build/operations.ts';
import { evaluateQuantity } from '../../shared/build/quantities.ts';
import { mergeCompatible } from '../../shared/build/spell-merge.ts';
import { multiplyResourceQ, SpellResourceRuntime } from './SpellResourceRuntime.ts';

const resources: readonly ResourceId[] = ['power', 'work', 'cold', 'heat', 'charge', 'opportunity'];
const terminalErrors = new Set(['INVALID_QUANTITY', 'INVALID_UNIT', 'INVALID_RESOURCE_TRANSACTION', 'INVALID_DEFINITION', 'UNKNOWN_DEFINITION', 'RESOURCE_LIMIT', 'RECEIPT_CONFLICT']);
const processingOperations = new Set(['Allocate', 'Store', 'Heat', 'Fracture', 'Merge', 'Convert', 'Field', 'Copy', 'Ongoing']);
const fail = (ruleId: string, message: string): Decision<never> => ({ ok: false,
  errors: [{ code: 'INVALID_RESOURCE_TRANSACTION', definitionId: ruleId, message }] });

/** Indexed event execution. Rules receive the object's frozen build, not the latest menu state. */
export class SpellRuleExecutor {
  private readonly conditions = new WeakMap<CompiledRuleProgram, ConditionState>();
  private readonly claims = new Map<string, number>();
  private readonly completed = new Map<string, { readonly signature: string; readonly program: CompiledRuleProgram; readonly result: RuleEventResult }>();
  private executing = false;
  readonly runtime: SpellResourceRuntime;
  private readonly world: SpellRuleWorld;
  constructor(runtime: SpellResourceRuntime, world: SpellRuleWorld) { this.runtime = runtime; this.world = world; }

  execute(event: SpellRuleEvent): RuleEventResult {
    const program = event.subject.program;
    const signature = JSON.stringify({ ...event, subject: { ...event.subject, program: undefined },
      counters: Object.entries(event.counters).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0) });
    const previous = this.completed.get(event.id);
    if (previous) return previous.signature === signature && previous.program === program ? previous.result : Object.freeze({
      eventId: event.id, program, outcomes: [], errors: [{ code: 'RECEIPT_CONFLICT' as const, message: 'Event replay changed its original facts' }] });
    const outcomes: RuleExecutionOutcome[] = [], errors: BuildDiagnostic[] = [];
    const claimedClosing = new Set<number>();
    const result = (): RuleEventResult => Object.freeze({ eventId: event.id, program,
      outcomes: Object.freeze(outcomes.map(outcome => Object.freeze(outcome))), errors: Object.freeze(errors.map(error => Object.freeze(error))) });
    const actual = this.runtime.getObject(event.subject.id);
    if (this.executing || !event.id || !Number.isSafeInteger(event.tick) || event.tick < event.subject.createdAtTick
      || !eventStages[event.event]?.includes(event.stage) || actual?.program !== program
      || actual.rootReceiptId !== event.subject.rootReceiptId || actual.kind !== event.subject.kind) {
      errors.push({ code: 'INVALID_RULE_ORDER', message: 'Events require a valid tick and a non-reentrant stage boundary' });
      return result();
    }
    for (const [key, value] of Object.entries(event.counters)) {
      const range = Object.hasOwn(counterRanges, key) ? counterRanges[key as CounterId] : undefined;
      if (!range || !Number.isFinite(value) || value! < range[0] || value! > range[1]) {
        errors.push({ code: 'INVALID_CONDITION_CONTEXT', message: `Invalid event counter ${key}` }); return result();
      }
    }
    this.executing = true;
    try {
      ruleLoop: for (const rule of program.byEvent[event.event] ?? []) {
        const definition = rule.definition;
        if (definition.stage !== event.stage || definition.targetKind !== event.subject.kind) continue;
        const skip = (reason: RuleExecutionOutcome['reason']) => outcomes.push({ ruleId: definition.id, status: 'skipped', reason });
        if (event.subject.derived && (definition.inherit === 'never'
          || (definition.inherit === 'shape' && !event.subject.inheritedShape))) { skip('inheritance'); continue; }
        let object = this.runtime.getObject(event.unspentObjectId ?? event.subject.id);
        const op = definition.operation;
        const selector = op.op === 'Allocate' ? op.sourceLot : op.op === 'Recover' ? op.remainingSelector
          : op.op === 'Attach' ? op.lotSelector : op.op === 'Copy' && op.templateSelector === 'storedSpell' ? 'stored' : 'self';
        if (selector !== 'self' && selector !== 'unspent' && selector !== 'reserve') {
          const kind = selector === 'stored' ? 'shell' : selector === 'ongoing' ? 'status' : 'reserve';
          object = this.runtime.active(kind).find(candidate => candidate.rootReceiptId === event.subject.rootReceiptId
            && (kind !== 'shell' || candidate.state === 'stored'));
          if (!object) { skip('resources'); continue; }
        }
        if (op.op === 'Guard') {
          object = this.runtime.active('shell').filter(candidate => candidate.program === program && candidate.state === 'stored'
            && candidate.letter?.reward !== 'guard' && event.tick < candidate.expiresAtTick && this.runtime.balance(candidate.id, 'power') > 0)
            .sort((a, b) => (op.selectionOrder === 'oldest' ? 1 : -1) * (a.createdAtTick - b.createdAtTick || a.id - b.id))[0];
        }
        if (!object || (object.state === 'closed' && op.op !== 'Mark')) { skip('closed'); continue; }
        // Only a release in this boundary claims its closing remainder. An older flight may now be ending.
        if (claimedClosing.has(object.id)) { skip('closed'); continue; }
        const inspected = op.op === 'Guard' ? object : event.subject;
        const condition = { ...this.buildCondition(program), properties: { ...inspected.properties, shape: inspected.shape,
          ...(event.endReason ? { endReason: event.endReason } : {}),
          ageTicks: event.tick - inspected.createdAtTick, remainingTicks: Math.max(0, inspected.expiresAtTick - event.tick) }, counters: event.counters };
        if (!evaluateCondition(definition.when, condition)) { skip('condition'); continue; }
        const claimKey = this.claimKey(definition, event);
        if (claimKey === undefined) {
          errors.push({ code: 'INVALID_RULE_ORDER', definitionId: definition.id, message: 'Enemy-projectile rule lacks an authoritative projectile receipt' }); break;
        }
        const current = object;
        const quantity = (value: Quantity) => evaluateQuantity(value, { numerics: program.numerics, counters: event.counters,
          balances: Object.fromEntries(resources.map(resource => [resource,
            op.op === 'Attach' && op.lotSelector === 'reserve' && resource !== 'work' && resource !== 'opportunity'
              ? this.runtime.availableReserveQ(current.id, resource) : this.runtime.balance(resource === 'work' ? 0 : current.id, resource)])) });
        const context: RuleExecutionContext = { event, rule, object, condition, quantity };
        let limit: number;
        try {
          const operationLimit = op.op === 'Transfer' ? this.integer(quantity(op.maxHops)) : op.op === 'Copy' ? this.integer(quantity(op.maxCopies)) : definition.repeat.limit;
          limit = Math.min(definition.repeat.limit, operationLimit);
        } catch (error) {
          outcomes.push({ ruleId: definition.id, status: 'failed' });
          errors.push({ code: 'INVALID_QUANTITY', definitionId: definition.id, message: error instanceof Error ? error.message : String(error) });
          break;
        }
        const used = claimKey ? this.claims.get(claimKey) ?? 0 : 0;
        if (used >= limit) { skip('limit'); continue; }
        const attempts = op.op === 'Copy' ? limit - used : 1;
        for (let attempt = 0; attempt < attempts; attempt++) {
          let applied: Decision<RuleOperationResult>;
          try {
            const costs = definition.resourceCost.map(cost => ({ ownerId: cost.resource === 'work' ? 0 : object.id,
              resource: cost.resource, quantityQ: this.integer(Math.ceil(quantity(cost.amount))) }));
            // Supply is the input adapter's atomic receipt transaction. It cannot charge itself.
            applied = op.op === 'Mark' ? this.apply(context) : op.op === 'Supply'
              ? costs.length ? fail(definition.id, 'Supply cannot charge an unissued receipt') : this.apply(context)
              : this.runtime.executePaid({ objectId: object.id, ruleId: definition.id,
                portionLimit: definition.repeat.unit === 'lot' ? limit : undefined,
                processingUses: processingOperations.has(op.op) ? 1 : 0, costs }, () => this.apply(context));
          } catch (error) {
            applied = { ok: false, errors: [{ code: 'INVALID_QUANTITY', definitionId: definition.id, message: error instanceof Error ? error.message : String(error) }] };
          }
          if (!applied.ok) {
            const code = applied.errors[0]?.code;
            if (terminalErrors.has(code) && !(code === 'RESOURCE_LIMIT' && (op.op === 'Copy' || op.op === 'Store' || op.op === 'Ongoing'))) {
              outcomes.push({ ruleId: definition.id, status: 'failed' }); errors.push(...applied.errors.map(error => ({ ...error, definitionId: definition.id }))); break ruleLoop;
            }
            skip(code === 'DUPLICATE_CLAIM' ? 'limit' : code === 'RESOURCE_LIMIT' ? 'capacity' : code === 'STALE_RESOURCE_OWNER' ? 'closed' : 'resources');
            break;
          }
          if (claimKey) this.claims.set(claimKey, (this.claims.get(claimKey) ?? 0) + 1);
          if (event.unspentObjectId === object.id && (applied.value.flight?.object.id === object.id
            || (op.op === 'Release' && applied.value.objects.some(candidate => candidate.id === object.id && candidate.targetWaitUsed))))
            claimedClosing.add(object.id);
          outcomes.push(Object.freeze({ ruleId: definition.id, status: 'applied', result: applied.value }));
        }
      }
    } finally { this.executing = false; }
    const finished = result();
    this.completed.set(event.id, { signature, program, result: finished });
    return finished;
  }

  private buildCondition(program: CompiledRuleProgram): ConditionState {
    let state = this.conditions.get(program);
    if (!state) {
      state = { mainBook: program.mainBook, allocated: new Set(program.allocated), owned: program.owned, modes: program.modes,
        permits: new Set(program.permits), buildCapabilities: new Set(program.capabilities), talentCapabilities: new Set(program.talentCapabilities) };
      this.conditions.set(program, state);
    }
    return state;
  }
  private claimKey(rule: RuleDefinition, event: SpellRuleEvent): string | undefined {
    switch (rule.repeat.unit) {
      case 'lot': return '';
      case 'receipt': return `receipt:${event.subject.rootReceiptId}:${rule.id}`;
      case 'object': return `object:${event.subject.id}:${rule.id}`;
      case 'enemyProjectile': return event.projectile ? `projectile:${event.projectile.id}:${rule.id}` : undefined;
    }
  }
  private integer(value: number): number {
    if (!Number.isFinite(value) || value < 0 || value > Number.MAX_SAFE_INTEGER) throw new Error('Invalid nonnegative quantity');
    return Math.floor(value);
  }
  private apply(context: RuleExecutionContext): Decision<RuleOperationResult> {
    const { event, rule, object, quantity: q } = context, op = rule.definition.operation;
    const n = (value: Quantity) => this.integer(q(value));
    const missing = (): Decision<never> => ({ ok: false, errors: [{ code: 'INSUFFICIENT_RESOURCE', message: 'No eligible operation input' }] });
    switch (op.op) {
      case 'Supply': return this.world.supply(context, op);
      case 'Mark': return this.world.mark(context, op);
      case 'Ongoing': {
        if (op.action === 'delay') return event.sourceObjectId === undefined ? missing()
          : this.runtime.delayOngoing(object.id, event.sourceObjectId, n(op.coldCost), n(op.extraTicks), n(op.maxDelayTicks), event.tick);
        const advanced = this.runtime.advanceOngoing(object.id, n(op.applications), event.tick);
        return advanced.ok ? { ok: true, value: { objects: [], transaction: advanced.value.transaction, damage: advanced.value } } : advanced;
      }
      case 'Allocate': {
        return this.runtime.allocate(object.id, op.shares, op.remainderPolicy, {
          resourceShares: op.resourceShares, shape: op.shape, applications: op.applications ? n(op.applications) : undefined });
      }
      case 'Store':
        if (this.runtime.storedCount(event.tick) >= n(op.capacityUnits))
          return op.onNoCapacity === 'lose' ? this.runtime.discard(object.id) : missing();
        return this.runtime.createFinite({ kind: 'shell', fromObjectId: object.id, share: op.share ? q(op.share) : 1,
          retention: op.retention ? q(op.retention) : 1, tick: event.tick,
          delayTicks: n(op.releaseDelayTicks), lifeTicks: n(op.lifeTicks), applications: object.remainingApplications,
          properties: { material: op.shellArchetype, integrity: 1 } }, n(op.capacityUnits));
      case 'Attach': {
        const target = this.runtime.getObject(event.targetObjectId ?? event.subject.id);
        if (op.reserveBurst && event.counters.targetPowerRatio === undefined) return missing();
        if (op.lotSelector === 'reserve') return target && target.kind === 'spell' && op.resource !== 'work' && op.resource !== 'opportunity'
          ? this.runtime.useReserve(target.id, op.resource, n(op.amount), op.reserveShare ? q(op.reserveShare) : 1,
            op.reserveLimit ? n(op.reserveLimit) : undefined, op.reserveBurst ? {
              targetPowerRatio: event.counters.targetPowerRatio!, minimumTargetRatio: q(op.reserveBurst.minimumTargetRatio),
              share: q(op.reserveBurst.share), totalLimitQ: n(op.reserveBurst.totalLimit), cooldownManuals: n(op.reserveBurst.cooldownManuals),
            } : undefined) : missing();
        return target && target.kind === op.targetSelector ? this.runtime.attach(object.id, target.id, op.resource, n(op.amount)) : missing();
      }
      case 'Convert': {
        const rate = q(op.rate), [digits, exponent = '0'] = rate.toString().split('e');
        const shift = (digits.split('.')[1] ?? '').length - Number(exponent);
        let numerator = BigInt(digits.replace('.', '')), denominator = 1n;
        if (shift >= 0) denominator = 10n ** BigInt(shift); else numerator *= 10n ** BigInt(-shift);
        let a = numerator, b = denominator;
        while (b) [a, b] = [b, a % b];
        numerator /= a; denominator /= a;
        if (numerator > BigInt(Number.MAX_SAFE_INTEGER) || denominator > BigInt(Number.MAX_SAFE_INTEGER))
          return fail(rule.definition.id, 'Conversion rate exceeds exact supported precision');
        return this.runtime.convert(object.id, op.fromComponent, op.toComponent, q(op.share), Number(numerator), Number(denominator), rule.definition.id);
      }
      case 'Copy': {
        return this.runtime.copy(object.id, n(op.workCost), q(op.fundedPowerFactor), op.inheritMask, op.storage ? {
          material: op.storage.shellArchetype, capacity: n(op.storage.capacityUnits), tick: event.tick,
          delayTicks: n(op.storage.releaseDelayTicks), lifeTicks: n(op.storage.lifeTicks),
        } : undefined);
      }
      case 'Merge': {
        const wait = n(op.waitTicks), maxInputs = n(op.maxInputs), inputs: SpellObject[] = [];
        const eligible = (candidate: SpellObject) => mergeCompatible(object, candidate)
          && this.runtime.ledger.getOwnedLots(candidate.id).every(lot => lot.remainingUses > 0
            && (rule.definition.repeat.unit !== 'lot' || (lot.ruleClaims[`rule:${rule.definition.id}`] ?? 0) < rule.definition.repeat.limit));
        if (!eligible(object)) return missing();
        let ready = Math.max(event.tick, object.readyAtTick), expiry = object.expiresAtTick;
        for (const candidate of [object, ...this.runtime.active(object.kind).filter(item => item.id !== object.id).sort((a, b) => a.id - b.id)]) {
          if (!eligible(candidate)) continue;
          const nextReady = Math.max(ready, candidate.readyAtTick), nextExpiry = Math.min(expiry, candidate.expiresAtTick);
          if (nextReady + wait >= nextExpiry) continue;
          inputs.push(candidate); ready = nextReady; expiry = nextExpiry;
          if (inputs.length === maxInputs) break;
        }
        return inputs.length >= 2 && inputs[0].id === object.id
          ? this.runtime.merge(inputs.map(item => item.id), wait, event.tick, op.outputPolicy) : missing();
      }
      case 'Transfer': {
        const distance = q(op.maxDistance), cost = n(op.hopCost);
        let target = this.world.selectTarget(object, op.targetPolicy, distance);
        const indirect = !target ? this.world.selectRelay?.(object, op.targetPolicy, distance, cost, event.tick) : undefined;
        target ??= indirect?.target;
        if (!target) return this.noTarget(context, op.onNoTarget);
        const transferred = indirect ? this.runtime.transferAlong(object.id, target.id, target, distance, cost, indirect.relays, event.tick)
          : this.runtime.transfer(object.id, target.id, target, distance, cost);
        return transferred.ok && transferred.value.objects[0].state === 'flight'
          ? { ok: true, value: { ...transferred.value, relayedFields: transferred.value.objects.filter(object => object.kind === 'field'),
            flight: { object: transferred.value.objects[0], target, from: object.position,
            ...(indirect ? { via: indirect.relays.map(relay => relay.position) } : {}) } } } : transferred;
      }
      case 'Heat': {
        const source = this.runtime.getObject(event.sourceObjectId ?? -1);
        const shell = op.shellSelector === 'self' ? object : this.runtime.active('shell').filter(item => item.id !== source?.id
          && item.state === 'stored' && event.tick < item.expiresAtTick)
          .sort((a, b) => Math.hypot(a.position.x - object.position.x, a.position.y - object.position.y)
            - Math.hypot(b.position.x - object.position.x, b.position.y - object.position.y) || a.id - b.id)[0];
        if (!source || !shell) return missing();
        const room = Math.max(0, (shell.program.numerics['heat.capacityQ'] ?? Number.MAX_SAFE_INTEGER) - this.runtime.balance(shell.id, 'heat'));
        const amount = Math.min(n(op.amount), this.runtime.balance(source.id, 'heat'), room);
        if (!amount) return missing();
        const heated = this.runtime.heat(source.id, shell.id, amount, n(op.threshold), event.tick, op.heatMode);
        return heated.ok ? { ok: true, value: { objects: [heated.value.shell], transaction: heated.value.transaction,
          ...(heated.value.escrow ? { closure: { subject: heated.value.shell, escrow: heated.value.escrow,
            reason: op.heatMode === 'fracture' ? 'fracture' as const : 'thermal' as const } } : {}) } } : heated;
      }
      case 'Fracture': {
        const radius = object.program.numerics['fracture.reach'] ?? 260;
        const nearest = this.world.selectTarget(object, op.allocationPattern === 'aimed' ? 'original' : 'nearest', radius);
        const targets = op.allocationPattern === 'aimed' || !this.world.targetsWithin ? nearest ? [nearest] : []
          : [...this.world.targetsWithin(object.position, radius)].sort((a, b) => Math.atan2(a.y - object.position.y, a.x - object.position.x)
            - Math.atan2(b.y - object.position.y, b.x - object.position.x) || a.id - b.id);
        const result = this.runtime.fracture(object.id, n(op.integrityCost), n(op.maxPieces), event.tick, rule.definition.id);
        return result.ok ? { ok: true, value: { ...result.value, destinations: result.value.objects.map((piece, index) => ({
          objectId: piece.id, target: targets.length ? targets[index % targets.length] : undefined })) } } : result;
      }
      case 'Release': {
        const target = this.world.selectTarget(object, op.targetPolicy);
        if (!target) return this.noTarget(context, op.onNoTarget);
        const dispatched = this.runtime.dispatch(object.id, target.id, event.tick, this.world.flightLifeTicks);
        return dispatched.ok ? { ok: true, value: { ...dispatched.value, flight: { object: dispatched.value.objects[0], target } } } : dispatched;
      }
      case 'Recover': {
        const recovered = this.runtime.recover(object.id, op.resource ?? 'power', op.share ? q(op.share) : 1,
          q(op.retention), this.integer(object.program.numerics[op.capacityKey]), op.reuseAfter);
        // Moving leftovers into reserve does not schedule their former owner for another attack.
        return recovered.ok ? { ok: true, value: { objects: [], transaction: recovered.value.transaction } } : recovered;
      }
      case 'Guard': {
        if (!event.projectile?.reflectable) return missing();
        const share = q(op.reserveShare), required = Math.ceil(event.projectile.powerQ * q(op.powerPerBlockedUnit));
        const inputs = [object], maxInputs = op.maxInputs ? n(op.maxInputs) : 1;
        let maximum = multiplyResourceQ(this.runtime.balance(object.id, 'power'), share);
        const eligible = (candidate: SpellObject) => mergeCompatible(object, candidate) && event.tick >= candidate.createdAtTick
          && event.tick < candidate.expiresAtTick && this.runtime.ledger.getOwnedLots(candidate.id).every(lot => lot.remainingUses >= 1);
        if (maxInputs > 1 && maximum < required && eligible(object)) {
          const candidates = this.runtime.active('shell').filter(candidate => candidate.id !== object.id && eligible(candidate))
            .sort((a, b) => (op.selectionOrder === 'oldest' ? 1 : -1) * (a.createdAtTick - b.createdAtTick || a.id - b.id));
          for (const candidate of candidates) {
            const available = multiplyResourceQ(this.runtime.balance(candidate.id, 'power'), share);
            if (!available) continue;
            inputs.push(candidate); maximum += available;
            if (inputs.length >= maxInputs || maximum >= required) break;
          }
        }
        const requested = Math.min(maximum, required);
        if (!requested) return missing();
        if (inputs.length > 1) {
          const guarded = this.runtime.guardTogether(inputs.map(input => input.id), event.projectile.id, requested, share, event.tick);
          return guarded.ok ? { ok: true, value: { ...guarded.value,
            blockedPowerQ: Math.min(event.projectile.powerQ, Math.floor(guarded.value.blockedPowerQ / q(op.powerPerBlockedUnit))) } } : guarded;
        }
        const guarded = this.runtime.guard(object.id, event.projectile.id, requested);
        return guarded.ok ? { ok: true, value: { objects: [object], transaction: guarded.value.transaction,
          blockedPowerQ: Math.min(event.projectile.powerQ, Math.floor(guarded.value.blockedPowerQ / q(op.powerPerBlockedUnit))) } } : guarded;
      }
      case 'Field':
        return this.runtime.createFinite({ kind: 'field', fromObjectId: object.id, share: op.share ? q(op.share) : 1,
          resourceShares: op.resourceShares, tick: event.tick, position: event.hitTarget ?? object.position,
          field: { shape: op.shape, radius: q(op.radius), allocation: op.lotAllocation, onFinish: op.onFinish,
            ...(op.shape === 'trail' ? { from: object.position } : {}) },
          delayTicks: 0, lifeTicks: n(op.lifeTicks), applications: n(op.maxApplications) }, 64);
    }
  }
  private noTarget(context: RuleExecutionContext, policy: 'waitOnce' | 'recover' | 'lose'): Decision<RuleOperationResult> {
    if (policy === 'lose') return this.runtime.discard(context.object.id);
    if (policy === 'waitOnce') return this.runtime.waitForTarget(context.object.id, context.event.tick, this.world.flightLifeTicks);
    // A recovery request leaves the money with its current owner for an owned Recover rule.
    return { ok: false, errors: [{ code: 'INSUFFICIENT_RESOURCE', message: 'No target; unspent resources remain available to recovery rules' }] };
  }
}
