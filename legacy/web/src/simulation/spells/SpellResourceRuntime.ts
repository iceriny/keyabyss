import { RESOURCE_SCALE, RESERVE_SPACE_UNITS } from '../../contracts/build-resources.ts';
import type { BuildErrorCode, Decision, FundedCreation, ReserveResource, ResourceClaim, ResourceId, ResourceLot, ResourceSpend, ResourceTransaction, ResourceTransactionResult } from '../../contracts/build-resources.ts';
import type { FiniteObjectRequest, ManualSpellReceipt, ResourceAllocationOptions, RuntimeDamageCommit, RuntimeFieldCommit, RuntimeLetterRedemption, RuntimeMutation, RuntimeReserveBurstPolicy, RuntimeReserveEntry, RuntimeReserveHandoff, RuntimeRulePayment, RuntimeSpellRelay, RuntimeTransportAssembly, SpellCloseResult, SpellObject, SpellLetterBinding, SpellLetterPlan, SpellWordSession, StoredCopyRequest } from '../../contracts/build-runtime.ts';
import { ResourceLedger } from './ResourceLedger.ts';
import { propertyTypes } from '../../shared/build/conditions.ts';
import { mergeCompatible } from '../../shared/build/spell-merge.ts';

const LIMIT = RESOURCE_SCALE * 1_000_000_000;
const resourceIds: readonly ResourceId[] = ['power', 'work', 'cold', 'heat', 'charge', 'opportunity'];
const WORK_OWNER = 0, RESERVE_OWNER = 1;
const integer = (value: number) => Number.isSafeInteger(value) && value >= 0;
const plainObject = (value: unknown): boolean => value !== null && typeof value === 'object'
  && !Array.isArray(value) && (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null);
const denseArray = (value: unknown): value is readonly number[] => Array.isArray(value)
  && Array.from({ length: value.length }, (_, index) => Object.hasOwn(value, index)).every(Boolean);
const point = (value: SpellObject['position']): SpellObject['position'] => ({ x: value.x, y: value.y });
const freeze = <T>(value: T): T => {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.values(value).forEach(freeze); Object.freeze(value);
  }
  return value;
};
class RuntimeError extends Error {
  readonly code: BuildErrorCode;
  constructor(code: BuildErrorCode, message: string) { super(message); this.code = code; }
}
function requireValue(value: unknown, message: string, code: BuildErrorCode = 'INVALID_RESOURCE_TRANSACTION'): asserts value {
  if (!value) throw new RuntimeError(code, message);
}
function unwrap<T>(result: Decision<T>): T {
  if (!result.ok) throw new RuntimeError(result.errors[0].code, result.errors.map(e => e.message).join('; '));
  return result.value;
}
function decide<T>(action: () => T): Decision<T> {
  try { return { ok: true, value: action() }; }
  catch (error) {
    if (error instanceof RuntimeError) return { ok: false, errors: [{ code: error.code, message: error.message }] };
    throw error;
  }
}

/** Decimal ratios are converted once to integers; large Q values never round upward accidentally. */
function fraction(value: number): readonly [bigint, bigint] {
  requireValue(Number.isFinite(value) && value >= 0 && value <= 1, 'Expected a fraction within [0,1]', 'INVALID_QUANTITY');
  const [digits, exponent = '0'] = value.toString().split('e');
  const decimalPlaces = (digits.split('.')[1] ?? '').length;
  const shift = decimalPlaces - Number(exponent);
  return shift >= 0 ? [BigInt(digits.replace('.', '')), 10n ** BigInt(shift)]
    : [BigInt(digits.replace('.', '')) * 10n ** BigInt(-shift), 1n];
}
export function multiplyResourceQ(quantityQ: number, share: number): number {
  requireValue(integer(quantityQ), 'Expected a nonnegative integer resource', 'INVALID_QUANTITY');
  const [n, d] = fraction(share);
  return Number(BigInt(quantityQ) * n / d);
}

/**
 * One room's authoritative objects. Every mutation spends/transfers ledger balances before
 * publishing immutable object state. Combat adapters consume hit/close results only once.
 */
export class SpellResourceRuntime {
  readonly ledger = new ResourceLedger(resourceIds.map(id => ({ id, maxQuantityQ: LIMIT,
    allowedOrigins: id === 'work' || id === 'opportunity' ? ['manual'] : ['manual', 'enemyProjectile', 'acquisition'] })));
  private readonly objects = new Map<number, SpellObject>();
  private readonly activeByKind = new Map<SpellObject['kind'], Set<number>>();
  private readonly manualReceipts = new Map<string, { signature: string; objectId: number; originalPowerQ: number; originalApplications: number; ordinal: number;
    program: ManualSpellReceipt['program']; session?: SpellWordSession; humanPositions: readonly number[] }>();
  private readonly projectileClaims = new Set<string>();
  private readonly reserves = new Map<number, Omit<RuntimeReserveEntry, 'quantityQ'>>();
  private readonly reserveUsedUnitsByManual = new Map<number, bigint>();
  private readonly reservePlans = new Map<number, { readonly signature?: string; readonly share: number; readonly totalLimitQ?: number;
    readonly burstTargetId?: number; readonly resourceLimitsQ?: Readonly<Partial<Record<ReserveResource, number>>> }>();
  private readonly reserveUsedByResource = new Map<number, Partial<Record<ReserveResource, number>>>();
  private readonly burstTargets = new Set<number>();
  private reserveCooldownUntilManual = 0;
  private importedCooldownManuals?: number;
  private exportedHandoff?: RuntimeReserveHandoff;
  private archivedReserves?: { readonly retention: number; readonly capacityQ: number; readonly result: ResourceTransactionResult };
  private importedHandoffId?: string;
  private objectSequence = 2;
  private transactionSequence = 0;
  private manualSequence = 0;
  private payment?: { readonly spends: readonly ResourceSpend[]; readonly claims: ResourceClaim[];
    readonly owners: number[]; readonly rule?: { readonly key: string; readonly limit: number; readonly uses: number }; committed: boolean };
  readonly room: number;

  constructor(room: number) {
    if (!integer(room)) throw new Error('Invalid room identifier');
    this.room = room;
    unwrap(this.ledger.commit({ id: 'runtime:accounts', expects: [], opens: [WORK_OWNER, RESERVE_OWNER] }));
  }

  getObject(id: number): SpellObject | undefined { return this.objects.get(id); }
  active(kind?: SpellObject['kind']): readonly SpellObject[] {
    const ids = kind ? [...(this.activeByKind.get(kind) ?? [])] : [...this.activeByKind.values()].flatMap(group => [...group]);
    return Object.freeze(ids.sort((a, b) => a - b).map(id => this.objects.get(id)!));
  }
  storedCount(tick: number): number {
    requireValue(integer(tick), 'Invalid storage time', 'INVALID_QUANTITY');
    return this.active('shell').filter(shell => shell.state === 'stored' && tick < shell.expiresAtTick).length;
  }
  get manualCount(): number { return this.manualSequence; }
  inputFor(objectId: number) {
    const object = this.objects.get(objectId), input = object && this.manualReceipts.get(object.rootReceiptId);
    return input && { session: input.session, humanPositions: input.humanPositions };
  }
  /** A single registered operation commits its effects, fees and lineage claims together. */
  executePaid<T>(payment: RuntimeRulePayment, operation: () => Decision<T>): Decision<T> {
    return decide(() => {
      requireValue(!this.payment, 'Rule transactions cannot be nested');
      this.live(payment.objectId);
      requireValue(payment.ruleId && integer(payment.processingUses) && payment.processingUses <= 1024
        && (payment.portionLimit === undefined || (integer(payment.portionLimit) && payment.portionLimit > 0)), 'Invalid rule payment');
      const costs = new Map<string, { ownerId: number; resource: ResourceId; quantityQ: number }>();
      for (const cost of payment.costs) {
        requireValue(integer(cost.ownerId) && resourceIds.includes(cost.resource) && integer(cost.quantityQ), 'Invalid operation fee');
        const key = `${cost.ownerId}:${cost.resource}`, total = (costs.get(key)?.quantityQ ?? 0) + cost.quantityQ;
        requireValue(integer(total), 'Operation fees exceed supported range', 'RESOURCE_LIMIT');
        costs.set(key, { ...cost, quantityQ: total });
      }
      const spends = [...costs.values()].flatMap(cost => this.funding(cost.ownerId, cost.resource, cost.quantityQ)
        .map(({ lot, quantityQ }) => ({ lotId: lot.lotId, quantityQ, reason: 'processing' as const })));
      const claims = payment.portionLimit !== undefined || payment.processingUses > 0
        ? this.ledger.getOwnedLots(payment.objectId).map(lot => ({ lotId: lot.lotId, key: `rule:${payment.ruleId}`,
          limit: payment.portionLimit ?? Number.MAX_SAFE_INTEGER, uses: payment.processingUses })) : [];
      for (const claim of claims) {
        const lot = this.ledger.getLot(claim.lotId)!;
        requireValue((lot.ruleClaims[claim.key] ?? 0) < claim.limit, 'Rule already processed this portion', 'DUPLICATE_CLAIM');
        requireValue(lot.remainingUses >= claim.uses, 'No processing allowance remains', 'INSUFFICIENT_RESOURCE');
      }
      const scope = { spends, claims, owners: [...new Set([payment.objectId, ...[...costs.values()].map(cost => cost.ownerId)])],
        rule: payment.portionLimit !== undefined || payment.processingUses > 0
          ? { key: `rule:${payment.ruleId}`, limit: payment.portionLimit ?? Number.MAX_SAFE_INTEGER, uses: payment.processingUses }
          : undefined, committed: false };
      this.payment = scope;
      try {
        const result = unwrap(operation());
        requireValue(scope.committed, 'A rule must commit an operation before claiming execution');
        return result;
      } finally { this.payment = undefined; }
    });
  }
  private registerProcessingOwners(ownerIds: readonly number[]): void {
    const payment = this.payment;
    if (!payment) return;
    requireValue(!payment.committed, 'A registered operation must use one resource transaction');
    const claimed = new Set(payment.claims.map(claim => claim.lotId));
    for (const ownerId of ownerIds) {
      if (!payment.owners.includes(ownerId)) payment.owners.push(ownerId);
      if (!payment.rule) continue;
      for (const lot of this.ledger.getOwnedLots(ownerId)) {
        if (claimed.has(lot.lotId)) continue;
        requireValue((lot.ruleClaims[payment.rule.key] ?? 0) < payment.rule.limit,
          'Rule already processed this portion', 'DUPLICATE_CLAIM');
        requireValue(lot.remainingUses >= payment.rule.uses,
          'No processing allowance remains', 'INSUFFICIENT_RESOURCE');
        payment.claims.push({ lotId: lot.lotId, ...payment.rule });
        claimed.add(lot.lotId);
      }
    }
  }
  private ownedLots(ownerId: number): readonly ResourceLot[] {
    const lots = this.ledger.getOwnedLots(ownerId), payment = this.payment;
    if (!payment || payment.committed) return lots;
    return lots.flatMap(lot => {
      const cost = payment.spends.filter(spend => spend.lotId === lot.lotId).reduce((sum, spend) => sum + spend.quantityQ, 0);
      const claim = payment.claims.find(item => item.lotId === lot.lotId);
      const quantityQ = lot.quantityQ - cost;
      return quantityQ > 0 ? [{ ...lot, quantityQ, remainingUses: lot.remainingUses - (claim?.uses ?? 0) }] : [];
    });
  }
  balance(ownerId: number, resource: ResourceId): number {
    return this.ownedLots(ownerId).filter(lot => lot.resource === resource).reduce((sum, lot) => sum + lot.quantityQ, 0);
  }
  reserveEntries(): readonly RuntimeReserveEntry[] {
    return Object.freeze([...this.reserves.values()].flatMap(entry => {
      const lot = this.ledger.getLot(entry.lotId);
      return lot && lot.quantityQ > 0 ? [freeze({ ...entry, quantityQ: lot.quantityQ })] : [];
    }));
  }
  reserveUsageQ(): number {
    return Number(this.reserveUsageUnits()) / 16;
  }
  private reserveUsageUnits(): bigint {
    return this.reserveEntries().reduce((sum, entry) => sum + BigInt(entry.quantityQ) * BigInt(RESERVE_SPACE_UNITS[entry.resource as ReserveResource]), 0n);
  }
  private reserveRoomUnits(capacityQ: number): bigint {
    const remaining = BigInt(capacityQ) * 16n - this.reserveUsageUnits();
    return remaining > 0n ? remaining : 0n;
  }
  private eligibleReserve(objectId: number, resource: ReserveResource): readonly { entry: RuntimeReserveEntry; lot: ResourceLot }[] {
    const object = this.objects.get(objectId);
    const receipt = object && this.manualReceipts.get(object.rootReceiptId);
    if (!object || object.state === 'closed' || object.derived || object.kind !== 'spell'
      || receipt?.objectId !== objectId || this.exportedHandoff || this.archivedReserves) return [];
    return this.reserveEntries().flatMap(entry => {
      if (entry.resource !== resource || entry.availableAfterManual > receipt.ordinal || entry.availableInRoom > this.room) return [];
      const lot = this.ledger.getLot(entry.lotId);
      return lot && lot.quantityQ > 0 && lot.remainingUses >= 1 ? [{ entry, lot }] : [];
    });
  }
  availableReserveQ(objectId: number, resource: ReserveResource): number {
    return this.eligibleReserve(objectId, resource).reduce((sum, { lot }) => sum + lot.quantityQ, 0);
  }

  /** Final room boundary: ordinary within-room leftovers never gain a carry-over permit. */
  exportReserves(): Decision<RuntimeReserveHandoff> {
    return decide(() => {
      requireValue(!this.payment, 'Room handoff cannot interrupt an operation');
      if (this.exportedHandoff) return this.exportedHandoff;
      requireValue(this.active().length === 0 && Number.isSafeInteger(this.room + 1), 'Finish room objects before exporting reserves');
      const entries = this.reserveEntries().filter(entry => entry.availableInRoom === this.room + 1);
      const resources = unwrap(this.ledger.exportHandoff(`room:${this.room}:reserve`, RESERVE_OWNER, entries.map(entry => entry.lotId)));
      const cooldownManuals = Math.max(0, this.reserveCooldownUntilManual - this.manualSequence);
      this.exportedHandoff = freeze({ fromRoom: this.room, toRoom: this.room + 1, resources,
        ...(cooldownManuals ? { cooldownManuals } : {}) });
      entries.forEach(entry => this.reserves.delete(entry.lotId));
      return this.exportedHandoff;
    });
  }

  importReserves(handoff: RuntimeReserveHandoff): Decision<ResourceTransactionResult> {
    return decide(() => {
      requireValue(!this.payment && !this.exportedHandoff && !this.archivedReserves, 'Cannot import into a finished room');
      requireValue(handoff && integer(handoff.fromRoom) && handoff.fromRoom + 1 === this.room
        && handoff.toRoom === this.room && handoff.resources?.id === `room:${handoff.fromRoom}:reserve`, 'Reserve belongs to a different room');
      requireValue(handoff.cooldownManuals === undefined || (integer(handoff.cooldownManuals) && handoff.cooldownManuals <= 64),
        'Invalid reserve cooldown', 'INVALID_QUANTITY');
      const replay = this.importedHandoffId === handoff.resources.id;
      requireValue(replay || (!this.importedHandoffId && this.manualSequence === 0 && this.active().length === 0), 'Import reserves before the first manual spell');
      if (replay) requireValue((handoff.cooldownManuals ?? 0) === this.importedCooldownManuals,
        'Reserve cooldown changed', 'RECEIPT_CONFLICT');
      const transaction = unwrap(this.ledger.importHandoff(handoff.resources, RESERVE_OWNER));
      if (!replay) {
        for (const lotId of transaction.createdLotIds) {
          const lot = this.ledger.getLot(lotId)!;
          // Word ordinals are local to a room. The first new human spell may use this remainder.
          this.reserves.set(lotId, { lotId, origin: lot.origin, resource: lot.resource,
            availableAfterManual: 1, availableInRoom: this.room });
        }
        this.importedHandoffId = handoff.resources.id;
        this.importedCooldownManuals = handoff.cooldownManuals ?? 0;
        this.reserveCooldownUntilManual = this.importedCooldownManuals;
      }
      return transaction;
    });
  }

  acceptManual(receipt: ManualSpellReceipt): Decision<SpellObject> {
    return decide(() => {
      requireValue(!this.payment && !this.exportedHandoff && !this.archivedReserves, 'Income requires an unfinished room outside an operation transaction');
      requireValue(receipt.id && integer(receipt.wordLength) && receipt.wordLength > 0 && receipt.wordLength <= 4096, 'Invalid word receipt');
      requireValue(receipt.humanPositions.length > 0 && new Set(receipt.humanPositions).size === receipt.humanPositions.length
        && receipt.humanPositions.every(position => integer(position) && position < receipt.wordLength), 'Human positions must be distinct actual word positions');
      if (receipt.wordSession) {
        this.validateSession(receipt.wordSession);
        requireValue(receipt.wordSession.word.replace(/ /g, '').length === receipt.wordLength, 'Word session length changed');
      }
      requireValue(integer(receipt.primaryPowerQ) && integer(receipt.auxiliaryWorkQ) && receipt.primaryPowerQ <= LIMIT && receipt.auxiliaryWorkQ <= LIMIT,
        'Invalid manual income', 'INVALID_QUANTITY');
      const materials = Object.entries(receipt.primaryMaterialsQ ?? {});
      requireValue(materials.every(([resource, quantity]) => ['cold', 'heat', 'charge'].includes(resource)
        && integer(quantity) && quantity <= LIMIT), 'Invalid native material income', 'INVALID_QUANTITY');
      const auxiliary = Object.entries(receipt.auxiliaryResourcesQ ?? {});
      requireValue(auxiliary.every(([resource, quantity]) => resource !== 'work' && resourceIds.includes(resource as ResourceId)
        && integer(quantity) && quantity <= LIMIT), 'Invalid auxiliary income allocation', 'INVALID_QUANTITY');
      requireValue(receipt.primaryPowerQ + receipt.auxiliaryWorkQ + materials.reduce((sum, [, q]) => sum + q, 0)
        + auxiliary.reduce((sum, [, q]) => sum + q, 0) > 0, 'Input has no funded income', 'INSUFFICIENT_RESOURCE');
      this.validateTime(receipt.tick, 0, receipt.lifeTicks, receipt.applications);
      requireValue(integer(receipt.processingUses) && receipt.processingUses > 0 && receipt.processingUses <= 1024, 'Invalid finite processing allowance');
      this.validatePosition(receipt.position);
      requireValue(Object.isFrozen(receipt.program), 'Runtime requires an immutable compiled program');
      requireValue(['shot', 'chain', 'pierce', 'burst', 'blade'].includes(receipt.shape), 'Unknown spell shape');
      const signature = JSON.stringify({ ...receipt, position: point(receipt.position), humanPositions: [...receipt.humanPositions].sort((a, b) => a - b),
        program: [receipt.program.version, receipt.program.revision, receipt.program.mainBook] });
      const previous = this.manualReceipts.get(receipt.id);
      if (previous) {
        requireValue(previous.signature === signature && previous.program === receipt.program, 'Manual receipt content changed', 'RECEIPT_CONFLICT');
        return this.objects.get(previous.objectId)!;
      }
      const id = this.objectSequence;
      const object: SpellObject = freeze({ id, kind: 'spell', rootReceiptId: receipt.id, program: receipt.program, book: receipt.program.mainBook,
        shape: receipt.shape, position: point(receipt.position), targetId: receipt.targetId, targetPolicy: 'original', properties: {},
        createdAtTick: receipt.tick, readyAtTick: receipt.tick, expiresAtTick: receipt.tick + receipt.lifeTicks,
        remainingApplications: receipt.applications, state: 'ready', derived: false, inheritedShape: true });
      const grants = [
        ...(receipt.primaryPowerQ ? [{ resource: 'power' as const, quantityQ: receipt.primaryPowerQ, remainingUses: receipt.processingUses }] : []),
        ...materials.filter(([, quantity]) => quantity > 0).map(([resource, quantityQ]) => ({ resource: resource as ResourceId,
          quantityQ, remainingUses: receipt.processingUses })),
        ...auxiliary.filter(([, quantity]) => quantity > 0).map(([resource, quantityQ]) => ({ resource: resource as ResourceId,
          ownerId: resource === 'opportunity' ? WORK_OWNER : id, quantityQ, remainingUses: receipt.processingUses })),
        ...(receipt.auxiliaryWorkQ ? [{ resource: 'work' as const, ownerId: WORK_OWNER, quantityQ: receipt.auxiliaryWorkQ, remainingUses: receipt.processingUses }] : []),
      ];
      unwrap(this.ledger.issue({ origin: { kind: 'manual', receiptId: receipt.id }, ownerId: id, grants }));
      this.publish(object); this.objectSequence++; this.manualSequence++;
      this.manualReceipts.set(receipt.id, { signature, objectId: id, originalPowerQ: receipt.primaryPowerQ,
        originalApplications: receipt.applications, ordinal: this.manualSequence, program: receipt.program,
        session: receipt.wordSession && freeze({ ...receipt.wordSession }), humanPositions: Object.freeze([...receipt.humanPositions]) });
      return object;
    });
  }

  /** A marking rule reserves already-earned auxiliary opportunities, never unfinished keystrokes. */
  markLetters(templateId: number, bindings: readonly SpellLetterBinding[], tick: number, lifeTicks: number,
    reward: 'power' | 'work' | 'guard', powerPerUnitQ: number, workFeeQ = 0, position?: SpellObject['position'],
    plan?: SpellLetterPlan): Decision<RuntimeMutation> {
    return decide(() => {
      requireValue(!this.payment && !this.exportedHandoff, 'Marking requires its own atomic opportunity transaction');
      const template = this.objects.get(templateId);
      requireValue(template && !template.derived && this.manualReceipts.has(template.rootReceiptId), 'Marking needs a real manual root');
      this.validatePosition(position ?? template.position);
      requireValue(['power', 'work', 'guard'].includes(reward) && integer(powerPerUnitQ) && powerPerUnitQ > 0
        && powerPerUnitQ <= 16 * RESOURCE_SCALE && integer(workFeeQ), 'Invalid letter reward', 'INVALID_QUANTITY');
      if (plan !== undefined) {
        const keys = ['storedShare', 'workShare', 'storedRetention', 'workRetention', 'capacity', 'delayTicks',
          'lifeTicks', 'inheritShape', 'opportunityCostQ', 'spread', 'maxPerWord'];
        requireValue(plainObject(plan) && Reflect.ownKeys(plan).length === keys.length
          && keys.every(key => Object.hasOwn(plan, key)) && reward === 'power'
          && Number.isFinite(plan.storedShare) && plan.storedShare >= 0 && plan.storedShare <= 1
          && Number.isFinite(plan.workShare) && plan.workShare >= 0 && plan.workShare <= 1
          && plan.storedShare + plan.workShare <= 1
          && Number.isFinite(plan.storedRetention) && plan.storedRetention >= 0 && plan.storedRetention <= 1
          && Number.isFinite(plan.workRetention) && plan.workRetention >= 0 && plan.workRetention <= 1
          && integer(plan.capacity) && plan.capacity >= 1 && plan.capacity <= 64
          && integer(plan.delayTicks) && plan.delayTicks >= 1
          && integer(plan.lifeTicks) && plan.lifeTicks >= 1 && plan.lifeTicks <= 72000
          && Number.isSafeInteger(tick + Math.max(plan.delayTicks, plan.lifeTicks))
          && integer(plan.opportunityCostQ) && plan.opportunityCostQ >= 1 && plan.opportunityCostQ <= 64 * RESOURCE_SCALE
          && integer(plan.maxPerWord) && plan.maxPerWord >= 1 && plan.maxPerWord <= 72
          && typeof plan.spread === 'boolean' && typeof plan.inheritShape === 'boolean',
        'Invalid letter plan', 'INVALID_QUANTITY');
      }
      this.validateTime(tick, 0, lifeTicks, 1);
      requireValue(tick >= template.createdAtTick && bindings.length > 0 && bindings.length <= 64
        && this.active('letter').length + bindings.length <= 72, 'Character opportunity capacity exceeded', 'RESOURCE_LIMIT');
      const occupied = new Set(this.active('letter').map(object => this.bindingKey(object.letter!.binding)));
      for (const binding of bindings) {
        this.validateBinding(binding);
        const key = this.bindingKey(binding);
        requireValue(!occupied.has(key), 'Word position already owns an opportunity', 'DUPLICATE_CLAIM'); occupied.add(key);
      }
      const funds = this.ledger.getOwnedLots(WORK_OWNER).filter(lot => lot.resource === 'opportunity' && lot.remainingUses > 0);
      let fundIndex = 0, fundUsed = 0;
      const creates: FundedCreation[] = [];
      const frozenPlan = plan && freeze({ ...plan });
      const originalApplications = this.manualReceipts.get(template.rootReceiptId)!.originalApplications;
      const letters = bindings.map((binding, index) => {
        const id = this.objectSequence + index;
        let left = plan?.opportunityCostQ ?? RESOURCE_SCALE;
        while (left > 0) {
          const lot = funds[fundIndex]; requireValue(lot, 'Insufficient earned character opportunities', 'INSUFFICIENT_RESOURCE');
          const amount = Math.min(left, lot.quantityQ - fundUsed);
          creates.push({ ownerId: id, resource: 'opportunity', funding: [{ lotId: lot.lotId, quantityQ: amount }],
            quantityQ: amount, remainingUses: lot.remainingUses - 1 });
          left -= amount; fundUsed += amount;
          if (fundUsed === lot.quantityQ) { fundIndex++; fundUsed = 0; }
        }
        return freeze({ ...template, id, kind: 'letter' as const, state: 'stored' as const, derived: true,
          position: point(position ?? template.position), targetId: binding.session.targetId, remainingApplications: 1, createdAtTick: tick, readyAtTick: tick,
          expiresAtTick: tick + lifeTicks, exitOf: undefined, field: undefined, status: undefined,
          letter: { binding: { session: { ...binding.session }, position: binding.position, character: binding.character },
            reward, powerPerUnitQ, templateApplications: originalApplications, ...(frozenPlan ? { plan: frozenPlan } : {}) } });
      });
      const spends = this.funding(WORK_OWNER, 'work', workFeeQ).map(({ lot, quantityQ }) => ({ lotId: lot.lotId, quantityQ, reason: 'processing' as const }));
      const transaction = this.commit({ expects: this.expect([WORK_OWNER]), opens: letters.map(letter => letter.id), creates, spends });
      letters.forEach(letter => this.publish(letter)); this.objectSequence += letters.length;
      return freeze({ objects: letters, transaction });
    });
  }

  /** Transfer invalidates the old binding and spends a finite routing use; lifetime is unchanged. */
  moveLetter(objectId: number, binding: SpellLetterBinding): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId); this.validateBinding(binding);
      requireValue(object.kind === 'letter' && object.letter && object.letter.binding.character === binding.character, 'Only the same letter opportunity can move');
      requireValue(!this.active('letter').some(other => this.bindingKey(other.letter!.binding) === this.bindingKey(binding)), 'Word position already owns an opportunity', 'DUPLICATE_CLAIM');
      const transaction = this.commit({ expects: this.expect([objectId]), transfers: this.ownedLots(objectId)
        .map(lot => ({ lotId: lot.lotId, toOwnerId: objectId, uses: 1 })) });
      const moved = freeze({ ...object, targetId: binding.session.targetId,
        letter: { ...object.letter, binding: { session: { ...binding.session }, position: binding.position, character: binding.character } } });
      this.publish(moved); return freeze({ objects: [moved], transaction });
    });
  }

  /** Completing a word redeems only positions actually accepted in that exact word session. */
  redeemLetters(objectId: number, tick: number): Decision<RuntimeLetterRedemption> {
    return decide(() => {
      const recipient = this.live(objectId), input = this.manualReceipts.get(recipient.rootReceiptId);
      requireValue(!recipient.derived && input?.session && input.objectId === objectId && integer(tick) && tick === recipient.createdAtTick,
        'Letter rewards require the current real manual receipt');
      const session = input.session;
      const letters = this.active('letter').filter(object => {
        const binding = object.letter!.binding;
        return object.createdAtTick <= tick && tick < object.expiresAtTick && binding.session.targetId === session.targetId
          && binding.session.revision === session.revision && binding.session.word === session.word
          && input.humanPositions.includes(binding.position);
      });
      requireValue(letters.length > 0, 'No manually matched character opportunity', 'INSUFFICIENT_RESOURCE');
      const creates: FundedCreation[] = [], spends: ResourceSpend[] = [], updates: SpellObject[] = [], closes: number[] = [];
      const pages: { source: SpellObject; planKey: string; object: SpellObject }[] = [];
      const activeShells = this.storedCount(tick)
        + letters.filter(letter => letter.letter?.reward === 'guard').length;
      const conversion = (to: 'power' | 'work', numerator: number, denominator: number): string => {
        const id = `letter:${to}:${numerator}:${denominator}`;
        this.ledger.registerConversion({ id, from: 'opportunity', to, numerator, denominator, origins: ['manual'] });
        return id;
      };
      const create = (lot: ResourceLot, sourceQ: number, ownerId: number, to: 'power' | 'work', outputQ: number,
        uses: number, numerator: number, denominator: number): void => {
        if (!sourceQ) return;
        if (!outputQ) { spends.push({ lotId: lot.lotId, quantityQ: sourceQ, reason: 'loss' }); return; }
        creates.push({ ownerId, resource: to, funding: [{ lotId: lot.lotId, quantityQ: sourceQ }],
          conversionId: conversion(to, numerator, denominator), quantityQ: outputQ, remainingUses: uses });
      };
      const pageKey = (letter: SpellObject): string => {
        const reward = letter.letter!, plan = reward.plan!;
        return JSON.stringify([letter.rootReceiptId, letter.shape, reward.templateApplications ?? 1,
          plan.storedShare, plan.workShare, plan.storedRetention, plan.workRetention, plan.capacity, plan.delayTicks,
          plan.lifeTicks, plan.inheritShape, plan.opportunityCostQ, plan.spread, plan.maxPerWord]);
      };
      for (const letter of letters) {
        const reward = letter.letter!, work = reward.reward === 'work', guard = reward.reward === 'guard';
        const plan = reward.plan;
        let page = plan && pages.find(group => group.source.rootReceiptId === letter.rootReceiptId
          && group.source.program === letter.program && group.source.shape === letter.shape
          && (group.source.letter?.templateApplications ?? 1) === (reward.templateApplications ?? 1)
          && group.planKey === pageKey(letter));
        for (const lot of this.ownedLots(letter.id)) {
          if (!plan) {
            const to = work ? 'work' : 'power', numerator = work ? 1 : reward.powerPerUnitQ;
            const denominator = work ? 1 : RESOURCE_SCALE;
            create(lot, lot.quantityQ, work ? WORK_OWNER : guard ? letter.id : objectId, to,
              Number(BigInt(lot.quantityQ) * BigInt(numerator) / BigInt(denominator)), lot.remainingUses, numerator, denominator);
            continue;
          }
          let workQ = multiplyResourceQ(lot.quantityQ, plan.workShare);
          let storedQ = multiplyResourceQ(lot.quantityQ, plan.storedShare);
          if (lot.remainingUses < 1) { workQ = 0; storedQ = 0; }
          if (!page && activeShells + pages.length >= Math.min(64, plan.capacity)) storedQ = 0;
          const directQ = lot.quantityQ - workQ - storedQ;
          if (workQ) {
            const kept = multiplyResourceQ(workQ, plan.workRetention);
            if (kept) create(lot, kept, WORK_OWNER, 'work', kept, lot.remainingUses - 1, 1, 1);
            if (workQ > kept) spends.push({ lotId: lot.lotId, quantityQ: workQ - kept, reason: 'loss' });
          }
          if (storedQ) {
            const gross = Number(BigInt(storedQ) * BigInt(reward.powerPerUnitQ) / BigInt(RESOURCE_SCALE));
            const kept = multiplyResourceQ(gross, plan.storedRetention);
            if (kept) {
              if (!page) {
                const id = this.objectSequence + pages.length;
                const inherit = plan.inheritShape;
                this.validateTime(tick, plan.delayTicks, plan.lifeTicks, inherit ? reward.templateApplications ?? 1 : 1);
                const object = freeze({ ...letter, id, kind: 'shell' as const, state: 'stored' as const,
                  derived: true, position: point(recipient.position), targetId: recipient.targetId,
                  shape: inherit ? letter.shape : 'shot' as const, inheritedShape: inherit,
                  remainingApplications: inherit ? reward.templateApplications ?? 1 : 1,
                  properties: { material: 'paper', integrity: 1 }, createdAtTick: tick,
                  readyAtTick: tick + plan.delayTicks, expiresAtTick: tick + plan.lifeTicks,
                  letter: undefined, field: undefined, status: undefined, exitOf: undefined });
                page = { source: letter, planKey: pageKey(letter), object }; pages.push(page);
              }
              create(lot, storedQ, page.object.id, 'power', kept, lot.remainingUses - 1, kept, storedQ);
            } else spends.push({ lotId: lot.lotId, quantityQ: storedQ, reason: 'loss' });
          }
          const direct = Number(BigInt(directQ) * BigInt(reward.powerPerUnitQ) / BigInt(RESOURCE_SCALE));
          create(lot, directQ, objectId, 'power', direct, lot.remainingUses, reward.powerPerUnitQ, RESOURCE_SCALE);
        }
        updates.push(freeze({ ...letter, kind: guard ? 'shell' as const : letter.kind,
          state: guard ? 'stored' as const : 'closed' as const, readyAtTick: guard ? letter.expiresAtTick + 1 : letter.readyAtTick }));
        if (!guard) closes.push(letter.id);
      }
      const transaction = this.commit({ expects: this.expect([objectId, WORK_OWNER, ...letters.map(letter => letter.id)]),
        opens: pages.map(page => page.object.id), creates, spends, closes });
      updates.forEach(object => this.publish(object)); pages.forEach(page => this.publish(page.object));
      this.objectSequence += pages.length;
      return freeze({ objects: [recipient, ...updates, ...pages.map(page => page.object)], transaction, matchedCount: letters.length });
    });
  }

  /** All children own integer portions; untouched and rounding remainder have explicit destinations. */
  allocate(objectId: number, shares: readonly number[], remainder: 'parent' | 'firstChild' | 'loss' = 'parent',
    options: ResourceAllocationOptions = {}): Decision<RuntimeMutation> {
    return decide(() => {
      const parent = this.live(objectId);
      requireValue(denseArray(shares) && shares.length > 0 && shares.length <= 64
        && shares.every(n => Number.isFinite(n) && n > 0 && n <= 1), 'Invalid split shares');
      const fractions = shares.map(fraction);
      const denominator = fractions.reduce((max, [, d]) => d > max ? d : max, 1n);
      const numerators = fractions.map(([n, d]) => n * (denominator / d));
      const numerator = numerators.reduce((a, b) => a + b, 0n);
      requireValue(numerator <= denominator, 'Split exceeds its source', 'INSUFFICIENT_RESOURCE');
      requireValue(['parent', 'firstChild', 'loss'].includes(remainder), 'Unknown remainder policy');
      requireValue(plainObject(options) && Object.keys(options).every(key => ['resourceShares', 'shape', 'applications'].includes(key)),
        'Invalid allocation options', 'INVALID_QUANTITY');
      requireValue(options.resourceShares === undefined || plainObject(options.resourceShares),
        'Invalid resource split shares', 'INVALID_QUANTITY');
      const resourceShares = new Map<ResourceId, { numerators: bigint[]; denominator: bigint; numerator: bigint }>();
      for (const [resource, values] of Object.entries(options.resourceShares ?? {})) {
        requireValue(resourceIds.includes(resource as ResourceId) && denseArray(values) && values.length === shares.length
          && values.every(value => Number.isFinite(value) && value >= 0 && value <= 1), 'Invalid resource split shares', 'INVALID_QUANTITY');
        const parts = values.map(fraction), denominator = parts.reduce((max, [, d]) => d > max ? d : max, 1n);
        const numerators = parts.map(([n, d]) => n * (denominator / d));
        const numerator = numerators.reduce((sum, n) => sum + n, 0n);
        requireValue(numerator <= denominator, 'Resource split exceeds its source', 'INSUFFICIENT_RESOURCE');
        resourceShares.set(resource as ResourceId, { numerators, denominator, numerator });
      }
      requireValue(options.shape === undefined || ['shot', 'chain', 'pierce', 'burst', 'blade'].includes(options.shape),
        'Unknown spell shape', 'INVALID_QUANTITY');
      requireValue(options.applications === undefined || (integer(options.applications) && options.applications >= 1 && options.applications <= 64),
        'Invalid application count', 'INVALID_QUANTITY');
      const lots = this.ownedLots(objectId), creates: FundedCreation[] = [], spends: ResourceSpend[] = [];
      const children = shares.map((_, i) => freeze({ ...parent, id: this.objectSequence + i, kind: 'spell' as const,
        derived: true, state: 'ready' as const, exitOf: undefined, transport: undefined,
        shape: options.shape ?? parent.shape,
        inheritedShape: options.shape === undefined ? parent.inheritedShape : false,
        remainingApplications: options.applications ?? parent.remainingApplications, status: undefined }));
      for (const lot of lots) {
        const portion = resourceShares.get(lot.resource);
        const lotNumerators = portion?.numerators ?? numerators, lotDenominator = portion?.denominator ?? denominator;
        const lotNumerator = portion?.numerator ?? numerator;
        const quantities = lotNumerators.map(n => Number(BigInt(lot.quantityQ) * n / lotDenominator));
        const rounding = Number(BigInt(lot.quantityQ) * lotNumerator / lotDenominator) - quantities.reduce((a, b) => a + b, 0);
        if (rounding && remainder === 'firstChild') quantities[0] += rounding;
        else if (rounding && remainder === 'loss') spends.push({ lotId: lot.lotId, quantityQ: rounding, reason: 'loss' });
        quantities.forEach((quantityQ, i) => { if (quantityQ) creates.push({ ownerId: children[i].id, resource: lot.resource,
          funding: [{ lotId: lot.lotId, quantityQ }], quantityQ, remainingUses: lot.remainingUses }); });
      }
      const funded = children.filter(child => creates.some(creation => creation.ownerId === child.id));
      requireValue(funded.length > 0, 'No whole resource unit can be allocated', 'INSUFFICIENT_RESOURCE');
      const result = this.commit({ expects: this.expect([objectId]), opens: funded.map(child => child.id), creates, spends });
      funded.forEach(child => this.publish(child)); this.objectSequence += children.length;
      return freeze({ objects: funded, transaction: result });
    });
  }

  createFinite(request: FiniteObjectRequest, capacity: number): Decision<RuntimeMutation> {
    return decide(() => {
      const source = this.live(request.fromObjectId);
      requireValue(['shell', 'status', 'field'].includes(request.kind), 'Unknown finite object kind');
      requireValue(integer(capacity) && capacity > 0 && capacity <= 1024, 'Invalid object capacity', 'INVALID_QUANTITY');
      requireValue((request.kind === 'shell' ? this.storedCount(request.tick) : this.activeByKind.get(request.kind)?.size ?? 0) < capacity,
        'No free object capacity', 'RESOURCE_LIMIT');
      this.validateTime(request.tick, request.delayTicks, request.lifeTicks, request.applications);
      requireValue(request.tick >= source.createdAtTick && request.tick < source.expiresAtTick, 'Source is outside its lifetime');
      this.validatePosition(request.position ?? source.position);
      this.validateProperties(request.properties ?? {});
      fraction(request.share); fraction(request.retention ?? 1);
      requireValue(request.resourceShares === undefined || plainObject(request.resourceShares), 'Invalid finite resource shares', 'INVALID_QUANTITY');
      for (const [resource, share] of Object.entries(request.resourceShares ?? {})) {
        requireValue(resourceIds.includes(resource as ResourceId), 'Unknown finite resource share', 'INVALID_QUANTITY');
        fraction(share);
      }
      requireValue(request.kind === 'field' ? plainObject(request.field) : request.field === undefined,
        'Field metadata does not match finite object kind', 'INVALID_QUANTITY');
      if (request.kind === 'field') {
        const field = request.field!;
        requireValue(Object.keys(field).every(key => ['shape', 'radius', 'from', 'allocation', 'onFinish'].includes(key))
          && ['circle', 'trail'].includes(field.shape) && Number.isFinite(field.radius) && field.radius > 0 && field.radius <= 10000
          && ['equal', 'onContact'].includes(field.allocation) && ['recover', 'lose'].includes(field.onFinish),
        'Invalid field metadata', 'INVALID_QUANTITY');
        requireValue(field.shape === 'trail' ? plainObject(field.from) : field.from === undefined,
          'Invalid field origin', 'INVALID_QUANTITY');
        if (field.shape === 'trail') {
          requireValue(Object.keys(field.from!).every(key => key === 'x' || key === 'y'), 'Invalid field origin', 'INVALID_QUANTITY');
          this.validatePosition(field.from!);
        }
      }
      const id = this.objectSequence, creates: FundedCreation[] = [], spends: ResourceSpend[] = [];
      for (const lot of this.ownedLots(source.id)) {
        const gross = multiplyResourceQ(lot.quantityQ, request.resourceShares?.[lot.resource] ?? request.share);
        const quantityQ = multiplyResourceQ(gross, request.retention ?? 1);
        if (gross > quantityQ) spends.push({ lotId: lot.lotId, quantityQ: gross - quantityQ, reason: 'loss' });
        if (quantityQ) creates.push({ ownerId: id, resource: lot.resource, funding: [{ lotId: lot.lotId, quantityQ }], quantityQ, remainingUses: lot.remainingUses });
      }
      requireValue(creates.length > 0, 'No funded content for finite object', 'INSUFFICIENT_RESOURCE');
      const object = freeze({ ...source, id, kind: request.kind, derived: true, state: 'stored' as const, exitOf: undefined,
        transport: undefined,
        field: request.kind === 'field' ? { ...request.field!, intervalTicks: Math.max(1, Math.floor(request.lifeTicks / request.applications)),
          ...(request.field!.from ? { from: point(request.field!.from) } : {}) } : undefined,
        status: request.kind === 'status' ? { intervalTicks: Math.max(1, Math.floor(request.lifeTicks / request.applications)),
          nextAtTick: Math.max(request.tick + request.delayTicks,
            request.tick + Math.max(1, Math.floor(request.lifeTicks / request.applications))), delayedTicks: 0 } : undefined,
        position: point(request.position ?? source.position), targetId: request.targetId ?? source.targetId,
        properties: { ...source.properties, ...request.properties }, createdAtTick: request.tick,
        readyAtTick: request.tick + request.delayTicks, expiresAtTick: request.tick + request.lifeTicks, remainingApplications: request.applications });
      const transaction = this.commit({ expects: this.expect([source.id]), opens: [id], creates, spends });
      this.publish(object); this.objectSequence++;
      return freeze({ objects: [object], transaction });
    });
  }

  /** Attach transfers existing material; a property name alone never creates material quantity. */
  attach(fromId: number, toId: number, resource: ResourceId, quantityQ: number): Decision<RuntimeMutation> {
    return decide(() => {
      this.live(fromId); const target = this.live(toId);
      requireValue(fromId !== toId && resource !== 'work' && integer(quantityQ) && quantityQ > 0, 'Invalid material attachment', 'INVALID_QUANTITY');
      const funding = this.funding(fromId, resource, quantityQ);
      const creates = funding.map(({ lot, quantityQ: amount }) => ({ ownerId: toId, resource,
        funding: [{ lotId: lot.lotId, quantityQ: amount }], quantityQ: amount, remainingUses: lot.remainingUses }));
      const transaction = this.commit({ expects: this.expect([fromId, toId]), creates });
      return freeze({ objects: [target], transaction });
    });
  }

  /** Paid copies retain the actual work origins even when several words fund one copy. */
  copy(templateId: number, workCostQ: number, powerFactor: number, inherit: readonly ('shape' | 'cold' | 'heat' | 'charge')[],
    storage?: StoredCopyRequest): Decision<RuntimeMutation> {
    return decide(() => {
      const template = this.live(templateId), original = this.manualReceipts.get(template.rootReceiptId);
      requireValue(original && integer(workCostQ) && workCostQ > 0 && powerFactor > 0, 'Invalid paid copy', 'INVALID_QUANTITY');
      fraction(powerFactor);
      requireValue(new Set(inherit).size === inherit.length && inherit.every(p => ['shape', 'cold', 'heat', 'charge'].includes(p)), 'Invalid copy inheritance');
      if (storage) {
        requireValue(['crystal', 'paper'].includes(storage.material) && integer(storage.capacity) && storage.capacity > 0 && storage.capacity <= 64, 'Invalid stored copy');
        this.validateTime(storage.tick, storage.delayTicks, storage.lifeTicks, 1);
        requireValue(storage.tick >= template.createdAtTick && storage.tick < template.expiresAtTick, 'Copy template is outside its lifetime');
        requireValue(this.storedCount(storage.tick) < storage.capacity, 'No free storage for a copy', 'RESOURCE_LIMIT');
      }
      const powerQ = multiplyResourceQ(original.originalPowerQ, powerFactor);
      requireValue(powerQ > 0, 'Copy has no funded power', 'INSUFFICIENT_RESOURCE');
      const funds = this.funding(WORK_OWNER, 'work', workCostQ), id = this.objectSequence;
      // Each root keeps its own lot. Integer rounding residue is paid loss, never free power.
      const conversionId = `copy:${powerQ}:${workCostQ}`;
      this.ledger.registerConversion({ id: conversionId, from: 'work', to: 'power', numerator: powerQ, denominator: workCostQ, origins: ['manual'] });
      const creates: FundedCreation[] = funds.map(({ lot, quantityQ }) => ({ ownerId: id, resource: 'power', funding: [{ lotId: lot.lotId, quantityQ }],
        quantityQ: Number(BigInt(quantityQ) * BigInt(powerQ) / BigInt(workCostQ)), conversionId, remainingUses: lot.remainingUses }));
      for (const resource of ['cold', 'heat', 'charge'] as const) if (inherit.includes(resource)) {
        for (const lot of this.ownedLots(template.id).filter(lot => lot.resource === resource)) {
          const quantityQ = multiplyResourceQ(lot.quantityQ, powerFactor);
          if (quantityQ) creates.push({ ownerId: id, resource, funding: [{ lotId: lot.lotId, quantityQ }], quantityQ, remainingUses: lot.remainingUses });
        }
      }
      requireValue(creates.some(creation => creation.resource === 'power' && creation.quantityQ > 0), 'Work portions are below a usable copy unit', 'INSUFFICIENT_RESOURCE');
      const properties = Object.fromEntries(Object.entries(template.properties).filter(([key]) => key === 'shape' && inherit.includes('shape'))) as SpellObject['properties'];
      const child = freeze({ ...template, id, kind: 'spell' as const, state: 'ready' as const, derived: true, exitOf: undefined,
        status: undefined, transport: undefined, transportReturned: undefined, relayed: undefined,
        inheritedShape: inherit.includes('shape'), properties, shape: inherit.includes('shape') ? template.shape : 'shot' as const,
        remainingApplications: inherit.includes('shape') ? template.remainingApplications : 1,
        ...(storage ? { kind: 'shell' as const, state: 'stored' as const, createdAtTick: storage.tick,
          readyAtTick: storage.tick + storage.delayTicks, expiresAtTick: storage.tick + storage.lifeTicks,
          properties: { ...properties, material: storage.material, integrity: 1 } } : {}) });
      const transaction = this.commit({ expects: this.expect([WORK_OWNER, templateId]), opens: [id], creates });
      this.publish(child); this.objectSequence++;
      return freeze({ objects: [child], transaction });
    });
  }

  startTransport(shellId: number, attackId: number, actorId: number, tick: number, retention: number,
    assembly?: RuntimeTransportAssembly): Decision<RuntimeMutation> {
    return decide(() => {
      requireValue(integer(actorId) && integer(tick) && shellId !== attackId, 'Invalid transport request', 'INVALID_QUANTITY');
      fraction(retention);
      const shell = this.live(shellId), attack = this.live(attackId);
      requireValue(shell.kind === 'shell' && shell.state === 'stored' && !shell.letter && !shell.field && !shell.status
        && shell.exitOf === undefined && tick >= shell.createdAtTick && tick < shell.expiresAtTick,
      'No available stored shell', 'STALE_RESOURCE_OWNER');
      requireValue(attack.kind === 'spell' && attack.state === 'ready' && attack.derived && !attack.letter && !attack.field
        && !attack.status && attack.exitOf === undefined && tick >= attack.readyAtTick && tick < attack.expiresAtTick,
      'No ready attack ticket', 'STALE_RESOURCE_OWNER');
      requireValue(!this.active('shell').some(other => other.state === 'carried' && other.transport?.actorId === actorId),
        'Actor already carries a shell', 'RESOURCE_LIMIT');
      if (assembly !== undefined) {
        requireValue(plainObject(assembly) && Object.keys(assembly).length === 2
          && Object.hasOwn(assembly, 'objectIds') && Object.hasOwn(assembly, 'waitTicks')
          && denseArray(assembly.objectIds) && assembly.objectIds.length >= 2 && assembly.objectIds.length <= 8
          && assembly.objectIds.every(integer) && new Set(assembly.objectIds).size === assembly.objectIds.length
          && assembly.objectIds[0] === shellId && !assembly.objectIds.includes(attackId)
          && integer(assembly.waitTicks) && assembly.waitTicks >= 1 && assembly.waitTicks <= 180,
        'Invalid transport assembly', 'INVALID_QUANTITY');
        const parts = assembly.objectIds.map(id => this.live(id));
        requireValue(parts.every(part => mergeCompatible(shell, part) && tick >= part.createdAtTick && tick < part.expiresAtTick),
          'Transport assembly needs compatible live shells', 'STALE_RESOURCE_OWNER');
        const readyAtTick = Math.max(tick, ...parts.map(part => part.readyAtTick)) + assembly.waitTicks;
        const expiresAtTick = Math.min(...parts.map(part => part.expiresAtTick));
        requireValue(Number.isSafeInteger(readyAtTick) && readyAtTick < expiresAtTick,
          'Transport assembly must finish before every shell expires', 'STALE_RESOURCE_OWNER');
        this.registerProcessingOwners([...assembly.objectIds, attackId]);
        const cargoLots = parts.flatMap(part => this.ownedLots(part.id));
        const ticketLots = this.ownedLots(attackId);
        requireValue(ticketLots.length > 0, 'Attack ticket has no resources', 'INSUFFICIENT_RESOURCE');
        const spends: ResourceSpend[] = [], claims: ResourceClaim[] = [], transfers: { lotId: number; toOwnerId: number; uses: number }[] = [];
        const id = this.objectSequence;
        for (const lot of cargoLots) {
          const kept = multiplyResourceQ(lot.quantityQ, retention);
          if (lot.quantityQ > kept) spends.push({ lotId: lot.lotId, quantityQ: lot.quantityQ - kept, reason: 'loss' });
          claims.push({ lotId: lot.lotId, key: 'native.transport.merge', limit: 1, uses: 1 });
          claims.push({ lotId: lot.lotId, key: 'native.transport.take', limit: Number.MAX_SAFE_INTEGER, uses: 1 });
          if (kept) transfers.push({ lotId: lot.lotId, toOwnerId: id, uses: 0 });
        }
        requireValue(transfers.length > 0, 'Transport retains no resource', 'INSUFFICIENT_RESOURCE');
        for (const lot of ticketLots) {
          spends.push({ lotId: lot.lotId, quantityQ: lot.quantityQ, reason: 'processing' });
          claims.push({ lotId: lot.lotId, key: 'native.transport.take', limit: Number.MAX_SAFE_INTEGER, uses: 1 });
        }
        const cargo = freeze({ ...shell, id, derived: true, state: 'carried' as const,
          createdAtTick: Math.min(...parts.map(part => part.createdAtTick)), readyAtTick, expiresAtTick,
          remainingApplications: Math.min(...parts.map(part => part.remainingApplications)),
          transport: { actorId, returning: false } });
        const closed = parts.map(part => freeze({ ...part, state: 'closed' as const }));
        const closedTicket = freeze({ ...attack, state: 'closed' as const });
        const transaction = this.commit({ expects: this.expect([...assembly.objectIds, attackId]), opens: [id],
          claims, spends, transfers, closes: [...assembly.objectIds, attackId] });
        closed.forEach(part => this.publish(part)); this.publish(closedTicket); this.publish(cargo); this.objectSequence++;
        return freeze({ objects: [cargo, ...closed, closedTicket], transaction });
      }
      this.registerProcessingOwners([shellId, attackId]);
      const cargoLots = this.ownedLots(shellId), ticketLots = this.ownedLots(attackId);
      requireValue(ticketLots.length > 0, 'Attack ticket has no resources', 'INSUFFICIENT_RESOURCE');
      const spends: ResourceSpend[] = [], claims: ResourceClaim[] = [];
      let retained = false;
      for (const lot of cargoLots) {
        const kept = multiplyResourceQ(lot.quantityQ, retention);
        retained ||= kept > 0;
        if (lot.quantityQ > kept) spends.push({ lotId: lot.lotId, quantityQ: lot.quantityQ - kept, reason: 'loss' });
        claims.push({ lotId: lot.lotId, key: 'native.transport.take', limit: Number.MAX_SAFE_INTEGER, uses: 1 });
      }
      requireValue(retained, 'Transport retains no resource', 'INSUFFICIENT_RESOURCE');
      for (const lot of ticketLots) {
        spends.push({ lotId: lot.lotId, quantityQ: lot.quantityQ, reason: 'processing' });
        claims.push({ lotId: lot.lotId, key: 'native.transport.take', limit: Number.MAX_SAFE_INTEGER, uses: 1 });
      }
      const cargo = freeze({ ...shell, state: 'carried' as const, transport: { actorId, returning: false } });
      const closed = freeze({ ...attack, state: 'closed' as const });
      const transaction = this.commit({ expects: this.expect([shellId, attackId]), claims, spends, closes: [attackId] });
      this.publish(cargo); this.publish(closed);
      return freeze({ objects: [cargo, closed], transaction });
    });
  }

  beginTransportReturn(objectId: number, actorId: number, tick: number): Decision<RuntimeMutation> {
    return decide(() => {
      requireValue(integer(actorId) && integer(tick), 'Invalid transport return', 'INVALID_QUANTITY');
      const cargo = this.live(objectId);
      requireValue(cargo.kind === 'shell' && cargo.state === 'carried' && cargo.transport?.actorId === actorId
        && !cargo.transport.returning && cargo.transportReturned !== true && tick >= cargo.createdAtTick
        && tick < cargo.expiresAtTick, 'Cargo cannot begin return', 'STALE_RESOURCE_OWNER');
      const updated = freeze({ ...cargo, transport: { actorId, returning: true } });
      const transaction = this.commit({ expects: this.expect([objectId]),
        transfers: this.ownedLots(objectId).map(lot => ({ lotId: lot.lotId, toOwnerId: objectId, uses: 0 })) });
      this.publish(updated); return freeze({ objects: [updated], transaction });
    });
  }

  returnTransport(objectId: number, actorId: number, tick: number, capacity: number, retention: number,
    waitTicks: number, position: SpellObject['position']): Decision<RuntimeMutation> {
    return decide(() => {
      requireValue(integer(actorId) && integer(tick) && integer(capacity) && capacity >= 1 && capacity <= 64
        && integer(waitTicks) && waitTicks <= 72000, 'Invalid transport return', 'INVALID_QUANTITY');
      fraction(retention); this.validatePosition(position);
      const cargo = this.live(objectId);
      requireValue(cargo.kind === 'shell' && cargo.state === 'carried' && cargo.transport?.actorId === actorId
        && cargo.transport.returning && cargo.transportReturned !== true && tick >= cargo.createdAtTick
        && tick < cargo.expiresAtTick, 'Cargo cannot return', 'STALE_RESOURCE_OWNER');
      requireValue(this.storedCount(tick) < capacity, 'No free storage for returned cargo', 'RESOURCE_LIMIT');
      const readyAtTick = Math.max(cargo.readyAtTick, tick + waitTicks);
      requireValue(Number.isSafeInteger(readyAtTick) && readyAtTick < cargo.expiresAtTick,
        'Return must finish before cargo expires', 'STALE_RESOURCE_OWNER');
      this.registerProcessingOwners([objectId]);
      const spends: ResourceSpend[] = [], claims: ResourceClaim[] = [];
      let retained = false;
      for (const lot of this.ownedLots(objectId)) {
        const kept = multiplyResourceQ(lot.quantityQ, retention);
        retained ||= kept > 0;
        if (lot.quantityQ > kept) spends.push({ lotId: lot.lotId, quantityQ: lot.quantityQ - kept, reason: 'loss' });
        claims.push({ lotId: lot.lotId, key: 'native.transport.return', limit: Number.MAX_SAFE_INTEGER, uses: 1 });
      }
      requireValue(retained, 'Return retains no resource', 'INSUFFICIENT_RESOURCE');
      const updated = freeze({ ...cargo, state: 'stored' as const, transport: undefined, transportReturned: true as const,
        position: point(position), readyAtTick });
      const transaction = this.commit({ expects: this.expect([objectId]), claims, spends });
      this.publish(updated); return freeze({ objects: [updated], transaction });
    });
  }

  deliverTransport(objectId: number, actorId: number, targetId: number, tick: number,
    position: SpellObject['position']): Decision<RuntimeMutation> {
    return decide(() => {
      requireValue(integer(actorId) && integer(targetId) && integer(tick), 'Invalid transport delivery', 'INVALID_QUANTITY');
      this.validatePosition(position);
      const cargo = this.live(objectId);
      requireValue(cargo.kind === 'shell' && cargo.state === 'carried' && cargo.transport?.actorId === actorId
        && !cargo.transport.returning && tick >= cargo.readyAtTick && tick < cargo.expiresAtTick,
      'Cargo is not ready for delivery', 'STALE_RESOURCE_OWNER');
      const delivered = freeze({ ...cargo, kind: 'spell' as const, state: 'ready' as const,
        transport: undefined, position: point(position), targetId, targetPolicy: 'original' as const });
      const transaction = this.commit({ expects: this.expect([objectId]),
        transfers: this.ownedLots(objectId).map(lot => ({ lotId: lot.lotId, toOwnerId: objectId, uses: 0 })) });
      this.publish(delivered); return freeze({ objects: [delivered], transaction });
    });
  }

  merge(objectIds: readonly number[], waitTicks: number, tick: number,
    outputPolicy: 'concentrate' | 'preserveShape' = 'preserveShape'): Decision<RuntimeMutation> {
    return decide(() => {
      requireValue(objectIds.length >= 2 && objectIds.length <= 64 && new Set(objectIds).size === objectIds.length, 'Invalid merge group');
      const parts = objectIds.map(id => this.live(id)), first = parts[0];
      requireValue(integer(waitTicks) && integer(tick) && ['concentrate', 'preserveShape'].includes(outputPolicy)
        && parts.every(part => mergeCompatible(first, part)), 'Only compatible unlaunched same-root objects can merge');
      const expiresAtTick = Math.min(...parts.map(part => part.expiresAtTick));
      const readyAtTick = Math.max(tick, ...parts.map(part => part.readyAtTick)) + waitTicks;
      requireValue(Number.isSafeInteger(readyAtTick) && tick >= Math.max(...parts.map(part => part.createdAtTick))
        && readyAtTick < expiresAtTick, 'Merge must finish before every input expires');
      this.registerProcessingOwners(objectIds);
      const id = this.objectSequence, lots = parts.flatMap(part => this.ownedLots(part.id));
      requireValue(lots.length > 0, 'Merge has no remaining content', 'INSUFFICIENT_RESOURCE');
      const output = freeze({ ...first, id, derived: true, createdAtTick: Math.min(...parts.map(part => part.createdAtTick)), readyAtTick, expiresAtTick,
        remainingApplications: outputPolicy === 'concentrate' ? 1 : Math.min(...parts.map(part => part.remainingApplications)) });
      const closed = parts.map(part => freeze({ ...part, state: 'closed' as const }));
      const transaction = this.commit({ expects: this.expect(objectIds), opens: [id], transfers: lots.map(lot => ({ lotId: lot.lotId, toOwnerId: id, uses: 0 })), closes: [...objectIds] });
      closed.forEach(part => this.publish(part)); this.publish(output); this.objectSequence++;
      return freeze({ objects: [output, ...closed], transaction });
    });
  }

  convert(objectId: number, from: ResourceId, to: ResourceId, share: number, numerator: number, denominator: number, ruleId: string): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId); fraction(share);
      requireValue(resourceIds.includes(from) && resourceIds.includes(to) && from !== to && to !== 'work' && from !== 'opportunity' && to !== 'opportunity' && integer(numerator) && numerator > 0 && integer(denominator) && denominator > 0
        && numerator / denominator <= 16 && /^[A-Za-z][A-Za-z0-9:._-]*$/.test(ruleId), 'Invalid registered conversion');
      const conversionId = `convert:${ruleId}:${from}:${to}:${numerator}:${denominator}`;
      this.ledger.registerConversion({ id: conversionId, from, to, numerator, denominator, origins: ['manual', 'enemyProjectile', 'acquisition'] });
      const creates: FundedCreation[] = [];
      for (const lot of this.ownedLots(objectId).filter(lot => lot.resource === from)) {
        const quantityQ = multiplyResourceQ(lot.quantityQ, share);
        if (quantityQ) creates.push({ ownerId: objectId, resource: to, funding: [{ lotId: lot.lotId, quantityQ }],
          quantityQ: Number(BigInt(quantityQ) * BigInt(numerator) / BigInt(denominator)), remainingUses: lot.remainingUses,
          conversionId, claimBonus: ruleId });
      }
      requireValue(creates.length, 'No resource is available for conversion', 'INSUFFICIENT_RESOURCE');
      const transaction = this.commit({ expects: this.expect([objectId]), creates });
      return freeze({ objects: [object], transaction });
    });
  }

  heat(fromId: number, shellId: number, amountQ: number, thresholdQ: number, tick: number, mode: 'open' | 'retain' | 'fracture'):
    Decision<{ readonly opened: boolean; readonly shell: SpellObject; readonly escrow?: SpellObject; readonly transaction: ResourceTransactionResult }> {
    return decide(() => {
      const source = this.live(fromId), shell = this.live(shellId);
      requireValue(fromId !== shellId && shell.kind === 'shell' && shell.state === 'stored'
        && integer(amountQ) && amountQ > 0 && integer(thresholdQ) && thresholdQ > 0
        && integer(tick) && Number.isSafeInteger(tick + 1) && tick >= Math.max(source.createdAtTick, shell.createdAtTick)
        && tick < Math.min(source.expiresAtTick, shell.expiresAtTick) && ['open', 'retain', 'fracture'].includes(mode), 'Invalid heat request');
      this.registerProcessingOwners([fromId, shellId]);
      const funds = this.funding(fromId, 'heat', amountQ);
      const shellHeat = this.balance(shellId, 'heat'), totalHeat = shellHeat + amountQ;
      requireValue(Number.isSafeInteger(totalHeat) && totalHeat <= LIMIT, 'Stored heat exceeds supported range', 'RESOURCE_LIMIT');
      const opened = mode !== 'retain' && totalHeat >= thresholdQ;
      const targetOwner = opened ? this.objectSequence : shellId;
      let heatCostLeft = opened ? thresholdQ : 0;
      const spends: ResourceSpend[] = [], creates: FundedCreation[] = [];
      const shellLots = this.ownedLots(shellId);
      for (const lot of shellLots) if (lot.resource === 'heat' && heatCostLeft) {
        const quantityQ = Math.min(lot.quantityQ, heatCostLeft); heatCostLeft -= quantityQ;
        spends.push({ lotId: lot.lotId, quantityQ, reason: 'processing' });
      }
      for (const fund of funds) {
        const spent = Math.min(fund.quantityQ, heatCostLeft); heatCostLeft -= spent;
        if (spent) spends.push({ lotId: fund.lot.lotId, quantityQ: spent, reason: 'processing' });
        const left = fund.quantityQ - spent;
        if (left) creates.push({ ownerId: targetOwner, resource: 'heat', funding: [{ lotId: fund.lot.lotId, quantityQ: left }],
          quantityQ: left, remainingUses: fund.lot.remainingUses });
      }
      const updated = freeze({ ...shell, properties: { ...shell.properties, heat: opened ? totalHeat - thresholdQ : totalHeat }, state: opened ? 'closed' as const : shell.state });
      const escrow: SpellObject | undefined = opened ? freeze({ ...updated, id: targetOwner, kind: 'spell' as const, state: 'ready' as const,
        derived: true, exitOf: shellId, createdAtTick: tick, readyAtTick: tick, expiresAtTick: tick + 1 }) : undefined;
      const transaction = this.commit({ expects: this.expect([fromId, shellId]), opens: opened ? [targetOwner] : [], creates, spends,
        transfers: opened ? shellLots.map(lot => ({ lotId: lot.lotId, toOwnerId: targetOwner, uses: 0 })) : [], closes: opened ? [shellId] : [] });
      this.publish(updated);
      if (escrow) { this.publish(escrow); this.objectSequence++; }
      return freeze({ opened, shell: updated, escrow, transaction });
    });
  }

  dispatch(objectId: number, targetId: number, tick: number, flightLifeTicks: number): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId);
      requireValue(object.kind === 'spell' && object.state === 'ready' && integer(targetId) && tick >= object.readyAtTick && tick < object.expiresAtTick,
        'Spell is not ready for dispatch', 'STALE_RESOURCE_OWNER');
      this.validateTime(tick, 0, flightLifeTicks, object.remainingApplications);
      requireValue(this.ownedLots(objectId).length > 0, 'Nothing remains to dispatch', 'INSUFFICIENT_RESOURCE');
      const updated = freeze({ ...object, targetId, state: 'flight' as const,
        expiresAtTick: object.exitOf === undefined ? Math.min(object.expiresAtTick, tick + flightLifeTicks) : tick + flightLifeTicks });
      const transaction = this.commit({ expects: this.expect([objectId]), transfers: this.ownedLots(objectId).map(lot => ({ lotId: lot.lotId, toOwnerId: objectId, uses: 0 })) });
      this.publish(updated); return freeze({ objects: [updated], transaction });
    });
  }

  waitForTarget(objectId: number, tick: number, delayTicks: number): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId);
      requireValue(object.kind === 'spell' && (object.state === 'ready' || object.state === 'flight') && !object.targetWaitUsed, 'A spell can wait for a missing target only once', 'DUPLICATE_CLAIM');
      this.validateTime(tick, delayTicks, delayTicks + 1, object.remainingApplications);
      requireValue(delayTicks > 0 && tick >= object.createdAtTick, 'Invalid target wait');
      const expiresAtTick = object.exitOf === undefined ? Math.min(object.expiresAtTick, tick + delayTicks + 1) : tick + delayTicks + 1;
      requireValue(tick + delayTicks < expiresAtTick, 'No paid lifetime remains for waiting', 'INSUFFICIENT_RESOURCE');
      const updated = freeze({ ...object, state: 'ready' as const, targetWaitUsed: true, readyAtTick: tick + delayTicks, expiresAtTick });
      const transaction = this.commit({ expects: this.expect([objectId]),
        transfers: this.ownedLots(objectId).map(lot => ({ lotId: lot.lotId, toOwnerId: objectId, uses: 0 })) });
      this.publish(updated); return freeze({ objects: [updated], transaction });
    });
  }

  transfer(objectId: number, targetId: number, position: SpellObject['position'], maxDistance: number, chargeCostQ: number): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId); this.validatePosition(position);
      requireValue(object.kind === 'spell' && (object.state === 'ready' || object.state === 'flight'),
        'Only an active spell can transfer', 'STALE_RESOURCE_OWNER');
      requireValue(object.remainingApplications > 0, 'No application remains for transfer', 'INSUFFICIENT_RESOURCE');
      requireValue(integer(targetId) && Number.isFinite(maxDistance) && maxDistance > 0 && maxDistance <= 10000 && integer(chargeCostQ) && chargeCostQ > 0, 'Invalid transfer');
      requireValue(Math.hypot(position.x - object.position.x, position.y - object.position.y) <= maxDistance, 'Transfer target is outside its allowed distance');
      const charges = this.funding(objectId, 'charge', chargeCostQ);
      const lots = this.ownedLots(objectId);
      const updated = freeze({ ...object, targetId, position: point(position), targetPolicy: 'nextUnhit' as const });
      const transaction = this.commit({ expects: this.expect([objectId]),
        spends: charges.map(({ lot, quantityQ }) => ({ lotId: lot.lotId, quantityQ, reason: 'processing' })),
        transfers: lots.map(lot => ({ lotId: lot.lotId, toOwnerId: objectId, uses: 1 })) });
      this.publish(updated); return freeze({ objects: [updated], transaction });
    });
  }

  transferVia(objectId: number, targetId: number, position: SpellObject['position'], maxDistance: number,
    chargeCostQ: number, relay: RuntimeSpellRelay, tick: number): Decision<RuntimeMutation> {
    return this.transferAlong(objectId, targetId, position, maxDistance, chargeCostQ, [relay], tick);
  }

  /** Every physical hop is funded and claimed in one commit; partial paths never become visible. */
  transferAlong(objectId: number, targetId: number, position: SpellObject['position'], maxDistance: number,
    chargeCostQ: number, relays: readonly RuntimeSpellRelay[], tick: number): Decision<RuntimeMutation> {
    return decide(() => {
      requireValue(integer(objectId) && integer(targetId) && integer(tick)
        && Number.isFinite(maxDistance) && maxDistance > 0 && maxDistance <= 10000
        && integer(chargeCostQ) && chargeCostQ > 0, 'Invalid relay transfer', 'INVALID_QUANTITY');
      this.validatePosition(position);
      requireValue(Array.isArray(relays) && relays.length >= 1 && relays.length <= 4
        && Object.keys(relays).length === relays.length, 'Invalid relay path', 'INVALID_QUANTITY');
      const ids = new Set([objectId]);
      for (const relay of relays) {
        requireValue(plainObject(relay) && Object.keys(relay).length === 4 + Number(Object.hasOwn(relay, 'actorId')) + Number(Object.hasOwn(relay, 'sourceCharge'))
          && ['objectId', 'position', 'maxDistance', 'chargeCostQ'].every(key => Object.hasOwn(relay, key))
          && (!Object.hasOwn(relay, 'actorId') || integer(relay.actorId))
          && (!Object.hasOwn(relay, 'sourceCharge') || relay.sourceCharge === true && relay.actorId === undefined && relay.chargeCostQ === chargeCostQ)
          && integer(relay.objectId) && !ids.has(relay.objectId)
          && plainObject(relay.position) && Object.keys(relay.position).length === 2
          && Object.hasOwn(relay.position, 'x') && Object.hasOwn(relay.position, 'y')
          && Number.isFinite(relay.position.x) && Number.isFinite(relay.position.y)
          && Number.isFinite(relay.maxDistance) && relay.maxDistance > 0 && relay.maxDistance <= 10000
          && integer(relay.chargeCostQ) && relay.chargeCostQ > 0,
        'Invalid relay', 'INVALID_QUANTITY');
        ids.add(relay.objectId);
      }
      const source = this.live(objectId), shells = relays.map(relay => this.live(relay.objectId));
      requireValue(source.kind === 'spell' && source.shape === 'chain' && source.state === 'flight'
        && source.remainingApplications > 0 && tick >= source.readyAtTick && tick < source.expiresAtTick,
      'Source cannot relay', 'STALE_RESOURCE_OWNER');
      let from = source.position, range = maxDistance;
      for (let i = 0; i < relays.length; i++) {
        const relay = relays[i], shell = shells[i];
        const physical = relay.actorId === undefined
          ? shell.state === 'stored' && !shell.transport && shell.position.x === relay.position.x && shell.position.y === relay.position.y
          : shell.state === 'carried' && shell.transport?.actorId === relay.actorId && shell.transport?.returning === false;
        const kind = relay.sourceCharge ? shell.kind === 'field' && !!shell.field && shell.remainingApplications > 0 && tick >= shell.readyAtTick
          : shell.kind === 'shell' && !shell.field;
        requireValue(kind && physical && !shell.relayed && tick >= shell.createdAtTick
          && tick < shell.expiresAtTick && !shell.letter && !shell.status,
        'Object cannot relay', 'STALE_RESOURCE_OWNER');
        requireValue(Math.hypot(relay.position.x - from.x, relay.position.y - from.y) <= range,
          'Relay target is outside its allowed distance');
        from = relay.position; range = relay.maxDistance;
      }
      requireValue(Math.hypot(position.x - from.x, position.y - from.y) <= range, 'Relay target is outside its allowed distance');
      this.registerProcessingOwners([...ids]);
      const sourceCharges = this.funding(objectId, 'charge', chargeCostQ * (1 + relays.filter(relay => relay.sourceCharge).length));
      const relayCharges = relays.filter(relay => !relay.sourceCharge).flatMap(relay => this.funding(relay.objectId, 'charge', relay.chargeCostQ));
      const sourceLots = this.ownedLots(objectId), relayLots = shells.flatMap(shell => this.ownedLots(shell.id));
      const fieldSpends: ResourceSpend[] = [];
      const updatedSource = freeze({ ...source, targetId, position: point(position), targetPolicy: 'nextUnhit' as const });
      const updatedRelays = shells.map((shell, i) => {
        if (!shell.field) return freeze({ ...shell, position: point(relays[i].position), relayed: true as const });
        const lots = this.ownedLots(shell.id);
        requireValue(lots.length > 0 && lots.every(lot => lot.resource !== 'work' && lot.resource !== 'opportunity'),
          'Field has no eligible application', 'INSUFFICIENT_RESOURCE');
        const spends = lots.map(lot => ({ lotId: lot.lotId,
          quantityQ: Number((BigInt(lot.quantityQ) + BigInt(shell.remainingApplications) - 1n) / BigInt(shell.remainingApplications)),
          reason: 'processing' as const }));
        fieldSpends.push(...spends);
        return freeze({ ...shell, relayed: true as const, remainingApplications: shell.remainingApplications - 1,
          state: spends.every((spend, index) => spend.quantityQ === lots[index].quantityQ) ? 'closed' as const : shell.state });
      });
      const transaction = this.commit({ expects: this.expect([...ids]),
        spends: [...fieldSpends, ...[...sourceCharges, ...relayCharges].map(({ lot, quantityQ }) => ({ lotId: lot.lotId, quantityQ, reason: 'processing' as const }))],
        closes: updatedRelays.filter(object => object.state === 'closed').map(object => object.id),
        claims: relayLots.map(lot => ({ lotId: lot.lotId, key: 'native.routing.relay', limit: 1, uses: 1 })),
        transfers: sourceLots.map(lot => ({ lotId: lot.lotId, toOwnerId: objectId, uses: 1 })) });
      this.publish(updatedSource); updatedRelays.forEach(shell => this.publish(shell));
      return freeze({ objects: [updatedSource, ...updatedRelays], transaction });
    });
  }

  fracture(objectId: number, integrityCost: number, maxPieces: number, tick: number, ruleId: string): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId);
      requireValue(integer(integrityCost) && integrityCost > 0 && Number(object.properties.integrity ?? 0) >= integrityCost
        && integer(maxPieces) && maxPieces > 0 && maxPieces <= 64 && integer(tick) && tick >= object.createdAtTick
        && Number.isSafeInteger(tick + 1) && /^[A-Za-z][A-Za-z0-9:._-]*$/.test(ruleId), 'Object has no eligible fracture structure');
      const lots = this.ownedLots(objectId), creates: FundedCreation[] = [];
      const pieces = Array.from({ length: maxPieces }, (_, i) => freeze({ ...object, id: this.objectSequence + i, kind: 'spell' as const,
        state: 'ready' as const, derived: true, exitOf: objectId, createdAtTick: tick, readyAtTick: tick, expiresAtTick: tick + 1,
        shape: 'shot' as const, inheritedShape: false, remainingApplications: 1, status: undefined,
        properties: { ...object.properties, integrity: 0 } }));
      for (const lot of lots) for (let i = 0; i < maxPieces; i++) {
        const quantityQ = Math.floor(lot.quantityQ / maxPieces) + (i < lot.quantityQ % maxPieces ? 1 : 0);
        if (quantityQ) creates.push({ ownerId: pieces[i].id, resource: lot.resource, funding: [{ lotId: lot.lotId, quantityQ }],
          quantityQ, remainingUses: lot.remainingUses, ...(i === 0 ? { claimBonus: ruleId } : {}) });
      }
      const funded = pieces.filter(piece => creates.some(create => create.ownerId === piece.id));
      requireValue(funded.length, 'No resource remains to fracture', 'INSUFFICIENT_RESOURCE');
      const closed = freeze({ ...object, state: 'closed' as const, properties: { ...object.properties, integrity: 0 } });
      const transaction = this.commit({ expects: this.expect([objectId]), opens: funded.map(piece => piece.id), creates, closes: [objectId] });
      this.publish(closed); funded.forEach(piece => this.publish(piece)); this.objectSequence += maxPieces;
      return freeze({ objects: funded, transaction });
    });
  }

  commitHit(objectId: number, targetId: number, position?: SpellObject['position'], share?: number): Decision<RuntimeDamageCommit> {
    return decide(() => {
      const object = this.live(objectId);
      if (position) this.validatePosition(position);
      if (share !== undefined) requireValue(Number.isFinite(share) && share > 0 && share <= 1, 'Invalid hit share', 'INVALID_QUANTITY');
      requireValue(integer(targetId) && object.remainingApplications > 0 && (object.kind === 'spell' || object.kind === 'status'), 'Object cannot commit a hit');
      const lots = this.ownedLots(objectId), spends: ResourceSpend[] = [], materials: Partial<Record<ResourceId, number>> = {};
      for (const lot of lots) {
        requireValue(lot.resource !== 'work' && lot.resource !== 'opportunity', 'Non-damage resource cannot commit a hit');
        if (object.kind === 'spell' && object.shape === 'chain' && lot.resource === 'charge') continue;
        const quantityQ = object.remainingApplications === 1 ? lot.quantityQ : share === undefined
          ? Number((BigInt(lot.quantityQ) + BigInt(object.remainingApplications) - 1n) / BigInt(object.remainingApplications))
          : multiplyResourceQ(lot.quantityQ, share);
        if (!quantityQ) continue;
        spends.push({ lotId: lot.lotId, quantityQ, reason: lot.resource === 'power' ? 'attack' : 'processing' });
        materials[lot.resource] = (materials[lot.resource] ?? 0) + quantityQ;
      }
      requireValue(lots.length > 0, 'Object has no unspent hit portion', 'INSUFFICIENT_RESOURCE');
      const finished = object.remainingApplications === 1;
      const routingFuel = finished && object.kind === 'spell' && object.shape === 'chain'
        && lots.some(lot => lot.resource === 'charge');
      const updated = freeze({ ...object, targetId, position: point(position ?? object.position), remainingApplications: object.remainingApplications - 1,
        status: object.status ? { ...object.status, nextAtTick: object.status.nextAtTick + object.status.intervalTicks } : undefined,
        state: finished ? routingFuel ? 'flight' as const : 'closed' as const : object.state });
      const transaction = this.commit({ expects: this.expect([objectId]), spends, closes: finished && !routingFuel ? [objectId] : [] });
      this.publish(updated);
      return freeze({ targetId, powerQ: materials.power ?? 0, materials, object: updated, transaction });
    });
  }

  advanceOngoing(objectId: number, applications: number, tick: number): Decision<RuntimeDamageCommit> {
    return decide(() => {
      const object = this.live(objectId);
      requireValue(object.kind === 'status' && object.state === 'stored' && object.status && object.targetId !== undefined,
        'Object cannot advance ongoing damage', 'STALE_RESOURCE_OWNER');
      requireValue(integer(tick) && tick >= object.createdAtTick && tick < object.expiresAtTick
        && integer(applications) && applications >= 1 && applications <= 64, 'Invalid ongoing advance', 'INVALID_QUANTITY');
      const count = Math.min(applications, object.remainingApplications);
      requireValue(count > 0, 'No ongoing application remains', 'INSUFFICIENT_RESOURCE');
      const lots = this.ownedLots(objectId), spends: ResourceSpend[] = [], materials: Partial<Record<ResourceId, number>> = {};
      requireValue(lots.length > 0, 'Ongoing object has no unspent portion', 'INSUFFICIENT_RESOURCE');
      for (const lot of lots) {
        requireValue(lot.resource !== 'work' && lot.resource !== 'opportunity', 'Non-damage resource cannot advance ongoing damage');
        let left = lot.quantityQ, amount = 0;
        for (let application = 0; application < count && left > 0; application++) {
          const remaining = object.remainingApplications - application;
          const portion = remaining === 1 ? left : Number((BigInt(left) + BigInt(remaining) - 1n) / BigInt(remaining));
          amount += portion; left -= portion;
        }
        if (!amount) continue;
        spends.push({ lotId: lot.lotId, quantityQ: amount, reason: lot.resource === 'power' ? 'attack' : 'processing' });
        materials[lot.resource] = (materials[lot.resource] ?? 0) + amount;
      }
      const exhausted = lots.every((lot, index) => spends[index]?.quantityQ === lot.quantityQ);
      const updated = freeze({ ...object, remainingApplications: object.remainingApplications - count,
        state: count === object.remainingApplications || exhausted ? 'closed' as const : object.state });
      const transaction = this.commit({ expects: this.expect([objectId]), spends,
        closes: updated.state === 'closed' ? [objectId] : [] });
      this.publish(updated);
      return freeze({ targetId: object.targetId, powerQ: materials.power ?? 0, materials, object: updated, transaction });
    });
  }

  delayOngoing(objectId: number, sourceId: number, coldCostQ: number, extraTicks: number, maxDelayTicks: number,
    tick: number): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId), source = this.live(sourceId);
      requireValue(objectId !== sourceId && object.kind === 'status' && object.state === 'stored' && object.status
        && object.remainingApplications > 0 && source.kind === 'spell' && source.state === 'flight',
        'Objects cannot delay ongoing damage', 'STALE_RESOURCE_OWNER');
      requireValue(integer(tick) && tick >= object.createdAtTick && tick < object.expiresAtTick
        && tick >= source.readyAtTick && tick < source.expiresAtTick
        && integer(coldCostQ) && coldCostQ > 0 && integer(extraTicks) && extraTicks > 0
        && integer(maxDelayTicks) && maxDelayTicks > 0 && maxDelayTicks <= 72000,
        'Invalid ongoing delay', 'INVALID_QUANTITY');
      requireValue(object.status.delayedTicks + extraTicks <= maxDelayTicks
        && Number.isSafeInteger(object.status.nextAtTick + extraTicks)
        && Number.isSafeInteger(object.expiresAtTick + extraTicks), 'Ongoing delay exceeds its limit', 'RESOURCE_LIMIT');
      requireValue(this.ownedLots(objectId).length > 0, 'Ongoing object has no unspent portion', 'INSUFFICIENT_RESOURCE');
      this.registerProcessingOwners([objectId, sourceId]);
      const spends = this.funding(sourceId, 'cold', coldCostQ).map(({ lot, quantityQ }) => ({ lotId: lot.lotId,
        quantityQ, reason: 'processing' as const }));
      const updated = freeze({ ...object, expiresAtTick: object.expiresAtTick + extraTicks,
        status: { ...object.status, nextAtTick: object.status.nextAtTick + extraTicks,
          delayedTicks: object.status.delayedTicks + extraTicks } });
      const transaction = this.commit({ expects: this.expect([objectId, sourceId]), spends });
      this.publish(updated);
      return freeze({ objects: [updated], transaction });
    });
  }

  /** One application consumes each lot once, then divides that exact portion among contacts. */
  applyField(objectId: number, targetIds: readonly number[]): Decision<RuntimeFieldCommit> {
    return decide(() => {
      const object = this.live(objectId);
      requireValue(object.kind === 'field' && object.state === 'stored' && object.field && object.remainingApplications > 0,
        'Object cannot apply a field', 'STALE_RESOURCE_OWNER');
      requireValue(denseArray(targetIds) && targetIds.length <= 64 && targetIds.every(integer)
        && new Set(targetIds).size === targetIds.length, 'Invalid field targets', 'INVALID_QUANTITY');
      requireValue(targetIds.length > 0 || object.field.allocation === 'equal',
        'No contact for field application', 'INSUFFICIENT_RESOURCE');
      const lots = this.ownedLots(objectId), spends: ResourceSpend[] = [];
      requireValue(lots.length > 0, 'Field has no unspent portion', 'INSUFFICIENT_RESOURCE');
      const allocations = targetIds.map(() => ({} as Partial<Record<ResourceId, number>>));
      for (const lot of lots) {
        requireValue(lot.resource !== 'work' && lot.resource !== 'opportunity', 'Non-damage resource cannot apply a field');
        const quantityQ = object.remainingApplications === 1 ? lot.quantityQ
          : Number((BigInt(lot.quantityQ) + BigInt(object.remainingApplications) - 1n) / BigInt(object.remainingApplications));
        spends.push({ lotId: lot.lotId, quantityQ, reason: targetIds.length === 0 ? 'loss'
          : lot.resource === 'power' ? 'attack' : 'processing' });
        if (targetIds.length) {
          const quotient = Math.floor(quantityQ / targetIds.length), remainder = quantityQ % targetIds.length;
          allocations.forEach((materials, index) => {
            const amount = quotient + (index < remainder ? 1 : 0);
            if (amount) materials[lot.resource] = (materials[lot.resource] ?? 0) + amount;
          });
        }
      }
      const exhausted = lots.every((lot, index) => spends[index].quantityQ === lot.quantityQ);
      const updated = freeze({ ...object, remainingApplications: object.remainingApplications - 1,
        state: object.remainingApplications === 1 || exhausted ? 'closed' as const : object.state });
      const transaction = this.commit({ expects: this.expect([objectId]), spends,
        closes: updated.state === 'closed' ? [objectId] : [] });
      this.publish(updated);
      const commits = targetIds.map((targetId, index) => freeze({ targetId, powerQ: allocations[index].power ?? 0,
        materials: allocations[index], object: updated, transaction }));
      return freeze({ object: updated, commits, transaction });
    });
  }

  guard(shellId: number, projectileReceiptId: string, requestedPowerQ: number): Decision<{ readonly blockedPowerQ: number; readonly transaction: ResourceTransactionResult }> {
    return decide(() => {
      const shell = this.live(shellId);
      requireValue(shell.kind === 'shell' && shell.state === 'stored' && projectileReceiptId
        && integer(requestedPowerQ) && requestedPowerQ > 0, 'Invalid interception');
      requireValue(!this.projectileClaims.has(projectileReceiptId), 'Projectile interception was already claimed', 'DUPLICATE_CLAIM');
      const blockedPowerQ = Math.min(requestedPowerQ, this.balance(shellId, 'power'));
      requireValue(blockedPowerQ > 0, 'No power remains for interception', 'INSUFFICIENT_RESOURCE');
      const spends = this.funding(shellId, 'power', blockedPowerQ).map(({ lot, quantityQ }) => ({ lotId: lot.lotId, quantityQ, reason: 'guard' as const }));
      const transaction = this.commit({ expects: this.expect([shellId]), spends });
      this.projectileClaims.add(projectileReceiptId);
      return freeze({ blockedPowerQ, transaction });
    });
  }

  /** Compatible pages jointly pay one interception; only actual contributors proceed to their exits. */
  guardTogether(shellIds: readonly number[], projectileReceiptId: string, requestedPowerQ: number, reserveShare: number,
    tick: number): Decision<RuntimeMutation & { readonly blockedPowerQ: number }> {
    return decide(() => {
      requireValue(denseArray(shellIds) && shellIds.length >= 2 && shellIds.length <= 8 && shellIds.every(integer)
        && new Set(shellIds).size === shellIds.length && !!projectileReceiptId && integer(requestedPowerQ) && requestedPowerQ > 0
        && integer(tick), 'Invalid joint interception', 'INVALID_QUANTITY');
      fraction(reserveShare);
      requireValue(reserveShare > 0, 'Joint interception needs a positive power share', 'INVALID_QUANTITY');
      requireValue(!this.projectileClaims.has(projectileReceiptId), 'Projectile interception was already claimed', 'DUPLICATE_CLAIM');
      const shells = shellIds.map(id => this.live(id)), contributors: SpellObject[] = [], spends: ResourceSpend[] = [];
      let remaining = requestedPowerQ;
      for (const shell of shells) requireValue(shell.kind === 'shell' && mergeCompatible(shells[0], shell)
        && tick >= shell.createdAtTick && tick < shell.expiresAtTick, 'Joint interception requires compatible live pages', 'STALE_RESOURCE_OWNER');
      for (const shell of shells) {
        const amount = Math.min(remaining, multiplyResourceQ(this.balance(shell.id, 'power'), reserveShare));
        if (!amount) continue;
        contributors.push(shell);
        spends.push(...this.funding(shell.id, 'power', amount).map(({ lot, quantityQ }) => ({ lotId: lot.lotId, quantityQ, reason: 'guard' as const })));
        remaining -= amount;
        if (!remaining) break;
      }
      requireValue(contributors.length >= 2, 'Joint interception needs two funded contributors', 'INSUFFICIENT_RESOURCE');
      this.registerProcessingOwners(contributors.map(shell => shell.id));
      const transaction = this.commit({ expects: this.expect(contributors.map(shell => shell.id)), spends,
        claims: contributors.flatMap(shell => this.ownedLots(shell.id).map(lot => ({ lotId: lot.lotId,
          key: 'native.guard.group', limit: Number.MAX_SAFE_INTEGER, uses: 1 }))) });
      this.projectileClaims.add(projectileReceiptId);
      return freeze({ objects: contributors, blockedPowerQ: requestedPowerQ - remaining, transaction });
    });
  }

  close(objectId: number, reason: SpellCloseResult['reason'], tick: number): Decision<SpellCloseResult> {
    return decide(() => {
      const object = this.live(objectId), id = this.objectSequence;
      requireValue(object.exitOf === undefined, 'A closing escrow cannot claim another closing exit', 'DUPLICATE_CLAIM');
      requireValue(['guard', 'thermal', 'expiry', 'release', 'fracture', 'room', 'death', 'miss', 'routing', 'transport'].includes(reason) && integer(tick) && Number.isSafeInteger(tick + 1) && tick >= object.createdAtTick, 'Invalid close');
      const lots = this.ownedLots(objectId);
      const closed = freeze({ ...object, state: 'closed' as const });
      const escrow = freeze({ ...object, id, kind: 'spell' as const, state: 'ready' as const, derived: true, createdAtTick: tick, readyAtTick: tick,
        expiresAtTick: tick + 1, remainingApplications: Math.max(1, object.remainingApplications), exitOf: objectId,
        status: undefined, transport: undefined });
      const transaction = this.commit({ expects: this.expect([objectId]), opens: [id],
        transfers: lots.map(lot => ({ lotId: lot.lotId, toOwnerId: id, uses: 0 })), closes: [objectId] });
      this.publish(closed); this.publish(escrow); this.objectSequence++;
      return freeze({ object: closed, escrow, reason, transaction });
    });
  }

  recover(objectId: number, resource: ReserveResource, share: number, retention: number, capacityQ: number,
    reuseAfter: 'nextManual' | 'nextRoom'): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId); fraction(share); fraction(retention);
      requireValue(Object.hasOwn(RESERVE_SPACE_UNITS, resource) && retention <= .7 && integer(capacityQ) && capacityQ <= LIMIT
        && ['nextManual', 'nextRoom'].includes(reuseAfter), 'Invalid recovery contract');
      const spends: ResourceSpend[] = [], creates: FundedCreation[] = [];
      let roomUnits = this.reserveRoomUnits(capacityQ);
      for (const lot of this.ownedLots(objectId).filter(lot => lot.resource === resource)) {
        const gross = multiplyResourceQ(lot.quantityQ, share);
        if (gross) requireValue(lot.remainingUses >= 1, 'No processing allowance remains', 'INSUFFICIENT_RESOURCE');
        const unit = BigInt(RESERVE_SPACE_UNITS[resource]);
        const kept = Number([BigInt(multiplyResourceQ(gross, retention)), roomUnits / unit].reduce((a, b) => a < b ? a : b));
        roomUnits -= BigInt(kept) * unit;
        if (gross > kept) spends.push({ lotId: lot.lotId, quantityQ: gross - kept, reason: 'loss' });
        if (kept) creates.push({ ownerId: RESERVE_OWNER, resource, funding: [{ lotId: lot.lotId, quantityQ: kept }], quantityQ: kept, remainingUses: lot.remainingUses - 1 });
      }
      requireValue(spends.length || creates.length, 'No recoverable remainder', 'INSUFFICIENT_RESOURCE');
      const transaction = this.commit({ expects: this.expect([objectId, RESERVE_OWNER]), spends, creates });
      for (const lotId of transaction.createdLotIds) {
        const lot = this.ledger.getLot(lotId)!;
        this.reserves.set(lotId, { lotId, origin: lot.origin, resource, availableAfterManual: this.manualSequence + 1,
          availableInRoom: this.room + (reuseAfter === 'nextRoom' ? 1 : 0) });
      }
      return freeze({ objects: [object], transaction });
    });
  }

  useReserve(objectId: number, resource: ReserveResource, maximumQ: number, share = 1, totalLimitQ?: number,
    burst?: RuntimeReserveBurstPolicy): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId);
      requireValue(Object.hasOwn(RESERVE_SPACE_UNITS, resource) && !object.derived && object.kind === 'spell'
        && this.manualReceipts.get(object.rootReceiptId)?.objectId === objectId
        && integer(maximumQ) && maximumQ > 0 && Number.isFinite(share) && share > 0 && share <= 1
        && (totalLimitQ === undefined || (integer(totalLimitQ) && totalLimitQ <= LIMIT)), 'Reserve is used by a later human primary');
      if (burst !== undefined) requireValue(plainObject(burst)
        && Reflect.ownKeys(burst).length === 5
        && Reflect.ownKeys(burst).every(key => ['targetPowerRatio', 'minimumTargetRatio', 'share', 'totalLimitQ', 'cooldownManuals'].includes(String(key)))
        && Number.isFinite(burst.targetPowerRatio) && burst.targetPowerRatio >= 0 && burst.targetPowerRatio <= 1_000_000
        && Number.isFinite(burst.minimumTargetRatio) && burst.minimumTargetRatio >= 1 && burst.minimumTargetRatio <= 1_000_000
        && Number.isFinite(burst.share) && burst.share > 0 && burst.share <= 1
        && integer(burst.totalLimitQ) && burst.totalLimitQ > 0 && burst.totalLimitQ <= LIMIT
        && integer(burst.cooldownManuals) && burst.cooldownManuals >= 1 && burst.cooldownManuals <= 64,
        'Invalid reserve burst policy', 'INVALID_QUANTITY');
      const previous = this.reservePlans.get(objectId);
      const signature = burst && JSON.stringify({ share, totalLimitQ, targetId: object.targetId, targetPowerRatio: burst.targetPowerRatio,
        minimumTargetRatio: burst.minimumTargetRatio, burstShare: burst.share, burstTotalLimitQ: burst.totalLimitQ,
        cooldownManuals: burst.cooldownManuals });
      if (previous) requireValue(previous.signature === signature,
        'Reserve policy changed within a manual spell', 'RECEIPT_CONFLICT');
      const receipt = this.manualReceipts.get(object.rootReceiptId)!;
      const burstTargetId = !previous && burst && object.targetId !== undefined
        && burst.targetPowerRatio >= burst.minimumTargetRatio && !this.burstTargets.has(object.targetId)
        ? object.targetId : undefined;
      const useShare = burstTargetId === undefined ? share : burst!.share;
      const plan = previous?.signature ? previous : { signature, share: useShare,
        totalLimitQ: burstTargetId === undefined ? totalLimitQ : burst!.totalLimitQ,
        burstTargetId, resourceLimitsQ: burst ? Object.fromEntries((Object.keys(RESERVE_SPACE_UNITS) as ReserveResource[])
          .map(kind => [kind, multiplyResourceQ(this.availableReserveQ(objectId, kind), useShare)])) : undefined };
      requireValue(receipt.ordinal > this.reserveCooldownUntilManual || previous?.burstTargetId !== undefined,
      'Reserve is resting after burst', 'INSUFFICIENT_RESOURCE');
      const eligible = this.eligibleReserve(objectId, resource);
      const creates: FundedCreation[] = [];
      const available = eligible.reduce((sum, { lot }) => sum + lot.quantityQ, 0);
      const resourceUsed = this.reserveUsedByResource.get(objectId)?.[resource] ?? 0;
      let remaining = Math.min(maximumQ, plan.resourceLimitsQ
        ? Math.max(0, (plan.resourceLimitsQ[resource] ?? 0) - resourceUsed) : multiplyResourceQ(available, plan.share), available);
      const unit = BigInt(RESERVE_SPACE_UNITS[resource]);
      if (plan.totalLimitQ !== undefined) {
        const roomUnits = BigInt(plan.totalLimitQ) * 16n - (this.reserveUsedUnitsByManual.get(objectId) ?? 0n);
        remaining = Math.min(remaining, Number(roomUnits > 0n ? roomUnits / unit : 0n));
      }
      for (const { lot } of eligible) {
        if (!remaining) break;
        const quantityQ = Math.min(remaining, lot.quantityQ); remaining -= quantityQ;
        if (quantityQ) creates.push({ ownerId: objectId, resource, funding: [{ lotId: lot.lotId, quantityQ }], quantityQ, remainingUses: lot.remainingUses - 1 });
      }
      requireValue(creates.length, 'No reserve is available for this manual spell', 'INSUFFICIENT_RESOURCE');
      const transaction = this.commit({ expects: this.expect([objectId, RESERVE_OWNER]), creates });
      if (!previous) this.reservePlans.set(objectId, plan);
      if (plan.resourceLimitsQ) this.reserveUsedByResource.set(objectId, { ...this.reserveUsedByResource.get(objectId),
        [resource]: resourceUsed + creates.reduce((sum, creation) => sum + creation.quantityQ, 0) });
      if (burstTargetId !== undefined) {
        this.burstTargets.add(burstTargetId);
        this.reserveCooldownUntilManual = receipt.ordinal + burst!.cooldownManuals;
      }
      this.reserveUsedUnitsByManual.set(objectId, (this.reserveUsedUnitsByManual.get(objectId) ?? 0n)
        + creates.reduce((sum, creation) => sum + BigInt(creation.quantityQ) * unit, 0n));
      for (const creation of creates) if (!this.ledger.getLot(creation.funding[0].lotId)!.quantityQ) this.reserves.delete(creation.funding[0].lotId);
      return freeze({ objects: [object], transaction });
    });
  }

  archiveReserves(retention: number, capacityQ: number): Decision<ResourceTransactionResult> {
    return decide(() => {
      requireValue(Number.isFinite(retention) && retention >= 0 && retention <= .9 && integer(capacityQ) && capacityQ <= LIMIT,
        'Invalid reserve archive contract', 'INVALID_QUANTITY');
      if (this.archivedReserves) {
        requireValue(this.archivedReserves.retention === retention && this.archivedReserves.capacityQ === capacityQ,
          'Reserve archive parameters changed', 'RECEIPT_CONFLICT');
        return this.archivedReserves.result;
      }
      requireValue(!this.payment && !this.exportedHandoff && this.active().length === 0 && Number.isSafeInteger(this.room + 1),
        'Finish room objects before archiving reserves');
      const spends: ResourceSpend[] = [], creates: FundedCreation[] = [];
      let roomUnits = BigInt(capacityQ) * 16n;
      for (const entry of [...this.reserveEntries()].sort((a, b) => a.lotId - b.lotId)) {
        const lot = this.ledger.getLot(entry.lotId)!;
        const unit = BigInt(RESERVE_SPACE_UNITS[entry.resource as ReserveResource]);
        const kept = Number([BigInt(multiplyResourceQ(lot.quantityQ, retention)), roomUnits / unit].reduce((a, b) => a < b ? a : b));
        roomUnits -= BigInt(kept) * unit;
        if (lot.quantityQ > kept) spends.push({ lotId: lot.lotId, quantityQ: lot.quantityQ - kept, reason: 'loss' });
        if (kept) creates.push({ ownerId: RESERVE_OWNER, resource: entry.resource, funding: [{ lotId: lot.lotId, quantityQ: kept }],
          quantityQ: kept, remainingUses: lot.remainingUses });
      }
      const transaction = this.commit({ expects: this.expect([RESERVE_OWNER]), spends, creates });
      this.reserves.clear();
      for (const lotId of transaction.createdLotIds) {
        const lot = this.ledger.getLot(lotId)!;
        this.reserves.set(lotId, { lotId, origin: lot.origin, resource: lot.resource,
          availableAfterManual: this.manualSequence + 1, availableInRoom: this.room + 1 });
      }
      this.archivedReserves = { retention, capacityQ, result: transaction };
      return transaction;
    });
  }

  discard(objectId: number): Decision<RuntimeMutation> {
    return decide(() => {
      const object = this.live(objectId), updated = freeze({ ...object, state: 'closed' as const });
      const transaction = this.commit({ expects: this.expect([objectId]),
        spends: this.ownedLots(objectId).map(lot => ({ lotId: lot.lotId, quantityQ: lot.quantityQ, reason: 'loss' })), closes: [objectId] });
      this.publish(updated); return freeze({ objects: [updated], transaction });
    });
  }

  private live(id: number): SpellObject {
    requireValue(!this.exportedHandoff && !this.archivedReserves, 'This room has handed off its resources', 'STALE_RESOURCE_OWNER');
    const object = this.objects.get(id);
    requireValue(object && object.state !== 'closed' && !this.ledger.getOwner(id)?.closed, `Object ${id} is no longer available`, 'STALE_RESOURCE_OWNER');
    return object;
  }
  private funding(ownerId: number, resource: ResourceId, quantityQ: number): { lot: ResourceLot; quantityQ: number }[] {
    let left = quantityQ; const result: { lot: ResourceLot; quantityQ: number }[] = [];
    for (const lot of this.ownedLots(ownerId)) if (lot.resource === resource && left > 0) {
      const part = Math.min(left, lot.quantityQ); result.push({ lot, quantityQ: part }); left -= part;
    }
    requireValue(left === 0, `Insufficient ${resource}`, 'INSUFFICIENT_RESOURCE'); return result;
  }
  private expect(ownerIds: readonly number[]) {
    return [...new Set(ownerIds)].map(ownerId => {
      const owner = this.ledger.getOwner(ownerId);
      requireValue(owner && !owner.closed, `Owner ${ownerId} is unavailable`, 'STALE_RESOURCE_OWNER');
      return { ownerId, version: owner.version };
    });
  }
  private commit(transaction: Omit<ResourceTransaction, 'id'>): ResourceTransactionResult {
    const payment = this.payment;
    requireValue(!payment?.committed, 'A registered operation must use one resource transaction');
    const expects = payment ? this.expect([...transaction.expects.map(owner => owner.ownerId), ...payment.owners]) : transaction.expects;
    const result = unwrap(this.ledger.commit({ ...transaction, expects, id: `runtime:${this.transactionSequence}`,
      claims: [...(payment?.claims ?? []), ...(transaction.claims ?? [])], spends: [...(payment?.spends ?? []), ...(transaction.spends ?? [])] }));
    if (payment) payment.committed = true;
    this.transactionSequence++; return result;
  }
  private publish(object: SpellObject): void {
    const previous = this.objects.get(object.id);
    if (previous) this.activeByKind.get(previous.kind)?.delete(object.id);
    this.objects.set(object.id, object);
    if (object.state !== 'closed') {
      let ids = this.activeByKind.get(object.kind);
      if (!ids) { ids = new Set(); this.activeByKind.set(object.kind, ids); }
      ids.add(object.id);
    }
  }
  private validateTime(tick: number, delay: number, life: number, applications: number): void {
    requireValue(integer(tick) && integer(delay) && integer(life) && life > 0 && life <= 72000 && delay <= 72000
      && Number.isSafeInteger(tick + Math.max(delay, life)) && integer(applications) && applications > 0 && applications <= 1024, 'Invalid finite lifetime or uses', 'INVALID_QUANTITY');
  }
  private validatePosition(position: SpellObject['position']): void {
    requireValue(position && Number.isFinite(position.x) && Number.isFinite(position.y), 'Invalid object position', 'INVALID_QUANTITY');
  }
  private validateSession(session: SpellWordSession): void {
    requireValue(session && integer(session.targetId) && integer(session.revision) && session.revision > 0
      && typeof session.word === 'string' && session.word.length > 0 && session.word.length <= 8192, 'Invalid word session');
  }
  private bindingKey(binding: SpellLetterBinding): string { return `${binding.session.targetId}:${binding.session.revision}:${binding.position}`; }
  private validateBinding(binding: SpellLetterBinding): void {
    this.validateSession(binding.session);
    requireValue(integer(binding.position) && /^[a-z0-9_'-]$/i.test(binding.character)
      && binding.session.word.replace(/ /g, '')[binding.position] === binding.character, 'Letter does not match its bound word position');
  }
  private validateProperties(properties: SpellObject['properties']): void {
    for (const [key, value] of Object.entries(properties)) {
      requireValue(Object.hasOwn(propertyTypes, key) && typeof value === propertyTypes[key as keyof typeof propertyTypes]
        && (typeof value !== 'number' || (Number.isFinite(value) && value >= 0 && value <= LIMIT)), 'Invalid object property');
    }
  }
}
