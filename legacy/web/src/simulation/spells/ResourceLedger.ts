import type {
  BuildDiagnostic, BuildErrorCode, Decision, ResourceConversion,
  ResourceDefinition, ResourceHandoff, ResourceHandoffLot, ResourceId, ResourceLedgerSnapshot, ResourceLot, ResourceOrigin,
  ResourceOwner, ResourceReceipt, ResourceReceiptResult, ResourceTransaction,
  ResourceTransactionResult,
} from '../../contracts/build-resources.ts';

class LedgerError extends Error {
  readonly code: BuildErrorCode;
  constructor(code: BuildErrorCode, message: string) { super(message); this.code = code; }
}

const originKinds = new Set<ResourceOrigin['kind']>(['manual', 'enemyProjectile', 'acquisition']);
const resourceIds = new Set<ResourceId>(['power', 'work', 'cold', 'heat', 'charge', 'opportunity']);
const spendReasons = new Set(['attack', 'guard', 'processing', 'loss', 'healing']);
const integer = (value: unknown): value is number => Number.isSafeInteger(value) && (value as number) >= 0;
const positive = (value: unknown): value is number => integer(value) && value > 0;
const nonempty = (value: unknown): value is string => typeof value === 'string' && value.length > 0;
const diagnostic = (error: LedgerError): BuildDiagnostic => ({ code: error.code, message: error.message });
function reject(code: BuildErrorCode, message: string): never { throw new LedgerError(code, message); }
const freeze = <T>(value: T): T => {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const child of Object.values(value)) freeze(child);
  }
  return value;
};
const copyOrigin = (origin: ResourceOrigin): ResourceOrigin => ({ kind: origin.kind, receiptId: origin.receiptId });
const copyLot = (lot: ResourceLot): ResourceLot => ({
  ...lot, origin: copyOrigin(lot.origin), parentLots: [...lot.parentLots], appliedBonuses: [...lot.appliedBonuses], ruleClaims: { ...lot.ruleClaims },
});
const copyOwner = (owner: ResourceOwner): ResourceOwner => ({ ...owner });
const copyHandoffLot = (lot: ResourceHandoffLot): ResourceHandoffLot => ({
  sourceLotId: lot.sourceLotId, origin: copyOrigin(lot.origin), resource: lot.resource,
  quantityQ: lot.quantityQ, appliedBonuses: [...lot.appliedBonuses],
  ruleClaims: { ...lot.ruleClaims }, remainingUses: lot.remainingUses,
});
const copyHandoff = (ticket: ResourceHandoff): ResourceHandoff => ({ id: ticket.id, lots: ticket.lots.map(copyHandoffLot) });
const exactKeys = (value: object, keys: readonly string[]): boolean =>
  Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
const success = <T>(value: T): Decision<T> => freeze({ ok: true, value });
const failure = <T>(error: LedgerError): Decision<T> => freeze({ ok: false, errors: [diagnostic(error)] });

/** Stable full-request identity, independent of object key insertion order. */
function requestKey(value: unknown): string {
  const seen = new Set<object>();
  const encode = (part: unknown): string => {
    if (part === null) return 'null';
    if (typeof part === 'string' || typeof part === 'boolean') return JSON.stringify(part);
    if (typeof part === 'number') return Number.isFinite(part) ? JSON.stringify(part) : String(part);
    if (typeof part === 'undefined') return 'undefined';
    if (typeof part !== 'object') return String(part);
    if (seen.has(part)) return reject('INVALID_RESOURCE_TRANSACTION', 'Cyclic request');
    seen.add(part);
    const result = Array.isArray(part)
      ? `[${part.map(encode).join(',')}]`
      : `{${Object.keys(part).sort().map(key => `${JSON.stringify(key)}:${encode((part as Record<string, unknown>)[key])}`).join(',')}}`;
    seen.delete(part);
    return result;
  };
  return encode(value);
}

interface Recorded<T> { readonly key: string; readonly result: T }

export class ResourceLedger {
  private readonly definitions = new Map<ResourceId, ResourceDefinition>();
  private readonly conversions = new Map<string, ResourceConversion>();
  private lots = new Map<number, ResourceLot>();
  private owners = new Map<number, ResourceOwner>();
  private readonly balances = new Map<number, Map<ResourceId, bigint>>();
  private readonly receipts = new Map<string, Recorded<ResourceReceiptResult>>();
  private readonly transactions = new Map<string, Recorded<ResourceTransactionResult>>();
  private readonly exports = new Map<string, Recorded<ResourceHandoff>>();
  private readonly imports = new Map<string, Recorded<ResourceTransactionResult>>();
  private readonly ownedLots = new Map<number, Set<number>>();
  private nextLotId = 1;

  constructor(definitions: readonly ResourceDefinition[], conversions: readonly ResourceConversion[] = []) {
    for (const item of definitions) {
      if (!item || !resourceIds.has(item.id) || !positive(item.maxQuantityQ) || !Array.isArray(item.allowedOrigins)
        || item.allowedOrigins.length === 0 || item.allowedOrigins.some(kind => !originKinds.has(kind))
        || this.definitions.has(item.id)) {
        throw new Error(`Invalid resource definition: ${String(item?.id)}`);
      }
      this.definitions.set(item.id, freeze({ ...item, allowedOrigins: [...item.allowedOrigins] }));
    }
    for (const item of conversions) this.registerConversion(item);
  }

  /** Engine-only registration. Existing rates are immutable across build snapshots. */
  registerConversion(item: ResourceConversion): void {
      const existing = item && this.conversions.get(item.id);
      if (existing && requestKey(existing) === requestKey(item)) return;
      if (!item || !nonempty(item.id) || this.conversions.has(item.id)
        || !this.definitions.has(item.from) || !this.definitions.has(item.to) || item.to === 'opportunity'
        || (item.to === 'work' && (item.from !== 'opportunity' || item.origins?.length !== 1
          || item.origins[0] !== 'manual' || item.numerator > item.denominator))
        || !positive(item.numerator) || !positive(item.denominator)
        || !Array.isArray(item.origins) || item.origins.length === 0
        || item.origins.some(kind => !originKinds.has(kind))) {
        throw new Error(`Invalid resource conversion: ${String(item?.id)}`);
      }
      this.conversions.set(item.id, freeze({ ...item, origins: [...item.origins] }));
  }

  getLot(lotId: number): ResourceLot | undefined {
    const lot = this.lots.get(lotId);
    return lot && freeze(copyLot(lot));
  }

  getOwner(ownerId: number): ResourceOwner | undefined {
    const owner = this.owners.get(ownerId);
    return owner && freeze(copyOwner(owner));
  }

  /** Positive balances only. Combat operations never scan consumed historical lots. */
  getOwnedLots(ownerId: number): readonly ResourceLot[] {
    return freeze([...(this.ownedLots.get(ownerId) ?? [])].sort((a, b) => a - b).map(id => copyLot(this.lots.get(id)!)));
  }

  snapshot(): ResourceLedgerSnapshot {
    return freeze({
      lots: [...this.lots.values()].sort((a, b) => a.lotId - b.lotId).map(copyLot),
      owners: [...this.owners.values()].sort((a, b) => a.ownerId - b.ownerId).map(copyOwner),
    });
  }

  issue(receipt: ResourceReceipt): Decision<ResourceReceiptResult> {
    try {
      if (!receipt || !receipt.origin || !originKinds.has(receipt.origin.kind) || !nonempty(receipt.origin.receiptId)
        || !integer(receipt.ownerId) || !Array.isArray(receipt.grants) || receipt.grants.length === 0) {
        reject('INVALID_RESOURCE_TRANSACTION', 'Invalid resource receipt');
      }
      const identity = `${receipt.origin.kind}:${receipt.origin.receiptId}`;
      const key = requestKey(receipt);
      const previous = this.receipts.get(identity);
      if (previous) return previous.key === key ? success({ ...previous.result, lotIds: [...previous.result.lotIds] })
        : failure(new LedgerError('RECEIPT_CONFLICT', `Receipt ${identity} has different content`));
      const owner = this.owners.get(receipt.ownerId);
      if (owner?.closed) reject('STALE_RESOURCE_OWNER', `Owner ${receipt.ownerId} is closed`);
      const incomeOwners = new Set([receipt.ownerId]);
      for (const grant of receipt.grants) {
        const definition = this.definition(grant?.resource);
        if (!positive(grant.quantityQ)) reject('INVALID_QUANTITY', 'Receipt grant must have positive safe-integer quantity');
        if (!integer(grant.remainingUses)) reject('INVALID_QUANTITY', 'Receipt uses must be a nonnegative safe integer');
        if (!definition.allowedOrigins.includes(receipt.origin.kind)) reject('INVALID_RESOURCE_TRANSACTION', 'Origin cannot issue this resource');
        if (grant.quantityQ > definition.maxQuantityQ) reject('RESOURCE_LIMIT', 'Receipt grant exceeds resource limit');
        const ownerId = grant.ownerId ?? receipt.ownerId;
        if (!integer(ownerId)) reject('INVALID_RESOURCE_TRANSACTION', 'Invalid income owner');
        if (this.owners.get(ownerId)?.closed) reject('STALE_RESOURCE_OWNER', `Owner ${ownerId} is closed`);
        incomeOwners.add(ownerId);
      }
      const newLots = new Map<number, ResourceLot>();
      const balanceWrites = new Map<number, Map<ResourceId, bigint>>();
      let nextId = this.nextLotId;
      const lotIds: number[] = [];
      for (const grant of receipt.grants) {
        if (!integer(nextId)) reject('RESOURCE_LIMIT', 'Lot ID exhausted');
        lotIds.push(nextId);
        newLots.set(nextId, {
          lotId: nextId, origin: copyOrigin(receipt.origin), parentLots: [], resource: grant.resource,
          quantityQ: grant.quantityQ, ownerId: grant.ownerId ?? receipt.ownerId, appliedBonuses: [], ruleClaims: {}, remainingUses: grant.remainingUses,
        });
        this.changeBalance(balanceWrites, grant.ownerId ?? receipt.ownerId, grant.resource, BigInt(grant.quantityQ));
        nextId++;
      }
      this.checkBalances(balanceWrites);
      const version = this.increment(owner?.version ?? 0, 'Owner version exhausted');
      const ownerWrites = [...incomeOwners].map(ownerId => ({ ownerId,
        version: this.increment(this.owners.get(ownerId)?.version ?? 0, 'Owner version exhausted'), closed: false }));
      const result: ResourceReceiptResult = freeze({ lotIds, ownerVersion: version });
      for (const lot of newLots.values()) this.publishLot(lot);
      for (const [id, account] of balanceWrites) this.balances.set(id, account);
      for (const changed of ownerWrites) this.owners.set(changed.ownerId, changed);
      this.nextLotId = nextId;
      this.receipts.set(identity, { key, result });
      return success({ lotIds: [...lotIds], ownerVersion: version });
    } catch (error) {
      if (error instanceof LedgerError) return failure(error);
      throw error;
    }
  }

  /** Engine-only move of selected positive reserves into a portable, immutable ticket. */
  exportHandoff(id: string, ownerId: number, lotIds: readonly number[]): Decision<ResourceHandoff> {
    try {
      if (!nonempty(id) || !integer(ownerId) || !Array.isArray(lotIds)
        || lotIds.some(lotId => !positive(lotId)) || new Set(lotIds).size !== lotIds.length)
        reject('INVALID_RESOURCE_TRANSACTION', 'Invalid handoff export request');
      const selected = [...lotIds].sort((a, b) => a - b);
      const key = requestKey({ ownerId, lotIds: selected });
      const previous = this.exports.get(id);
      if (previous) return previous.key === key ? success(copyHandoff(previous.result))
        : failure(new LedgerError('RECEIPT_CONFLICT', `Handoff export ${id} has different content`));
      const owner = this.owners.get(ownerId);
      if (!owner || owner.closed) reject('STALE_RESOURCE_OWNER', `Owner ${ownerId} is unavailable`);
      const lotWrites: ResourceLot[] = [];
      const ticketLots: ResourceHandoffLot[] = [];
      const balanceWrites = new Map<number, Map<ResourceId, bigint>>();
      for (const lotId of selected) {
        const lot = this.lots.get(lotId);
        if (!lot || lot.ownerId !== ownerId || !positive(lot.quantityQ))
          reject('INVALID_RESOURCE_TRANSACTION', `Lot ${lotId} is not an owned positive reserve`);
        if (lot.resource === 'work' || lot.resource === 'opportunity' || !this.definitions.has(lot.resource))
          reject('INVALID_RESOURCE_TRANSACTION', `Lot ${lotId} cannot be handed off`);
        ticketLots.push(copyHandoffLot({ sourceLotId: lot.lotId, origin: lot.origin,
          resource: lot.resource, quantityQ: lot.quantityQ, appliedBonuses: lot.appliedBonuses,
          ruleClaims: lot.ruleClaims, remainingUses: lot.remainingUses }));
        lotWrites.push({ ...lot, quantityQ: 0 });
        this.changeBalance(balanceWrites, ownerId, lot.resource, -BigInt(lot.quantityQ));
      }
      this.checkBalances(balanceWrites);
      const changedOwner = selected.length > 0
        ? { ...owner, version: this.increment(owner.version, 'Owner version exhausted') } : owner;
      const ticket: ResourceHandoff = freeze({ id, lots: ticketLots });
      for (const lot of lotWrites) this.publishLot(lot);
      for (const [accountId, account] of balanceWrites) this.balances.set(accountId, account);
      if (selected.length > 0) this.owners.set(ownerId, changedOwner);
      this.exports.set(id, { key, result: ticket });
      return success(copyHandoff(ticket));
    } catch (error) {
      if (error instanceof LedgerError) return failure(error);
      throw error;
    }
  }

  /** Engine-only import: local IDs are new roots; provenance and processing state remain intact. */
  importHandoff(ticket: ResourceHandoff, ownerId: number): Decision<ResourceTransactionResult> {
    try {
      if (!ticket || typeof ticket !== 'object' || !exactKeys(ticket, ['id', 'lots'])
        || !nonempty(ticket.id) || !Array.isArray(ticket.lots) || !integer(ownerId))
        reject('INVALID_RESOURCE_TRANSACTION', 'Invalid handoff ticket');
      const key = requestKey({ ticket, ownerId });
      const previous = this.imports.get(ticket.id);
      if (previous) return previous.key === key ? success(this.copyResult(previous.result))
        : failure(new LedgerError('RECEIPT_CONFLICT', `Handoff import ${ticket.id} has different content`));
      const owner = this.owners.get(ownerId);
      if (!owner || owner.closed) reject('STALE_RESOURCE_OWNER', `Owner ${ownerId} is unavailable`);
      const sourceIds = new Set<number>();
      const newLots: ResourceLot[] = [];
      const balanceWrites = new Map<number, Map<ResourceId, bigint>>();
      const facts: ResourceTransactionResult['facts'][number][] = [];
      let nextId = this.nextLotId;
      for (let index = 0; index < ticket.lots.length; index++) {
        if (!Object.hasOwn(ticket.lots, index)) reject('INVALID_RESOURCE_TRANSACTION', 'Sparse handoff lots');
        const lot = ticket.lots[index];
        if (!lot || typeof lot !== 'object' || !exactKeys(lot, [
          'sourceLotId', 'origin', 'resource', 'quantityQ', 'appliedBonuses', 'ruleClaims', 'remainingUses',
        ]) || !positive(lot.sourceLotId) || sourceIds.has(lot.sourceLotId)
          || !lot.origin || typeof lot.origin !== 'object' || !exactKeys(lot.origin, ['kind', 'receiptId'])
          || !originKinds.has(lot.origin.kind) || !nonempty(lot.origin.receiptId)
          || !positive(lot.quantityQ) || !integer(lot.remainingUses)
          || !Array.isArray(lot.appliedBonuses)
          || !lot.ruleClaims || typeof lot.ruleClaims !== 'object' || Array.isArray(lot.ruleClaims))
          reject('INVALID_RESOURCE_TRANSACTION', 'Invalid handoff lot');
        const definition = this.definition(lot.resource);
        if (lot.resource === 'work' || lot.resource === 'opportunity'
          || !definition.allowedOrigins.includes(lot.origin.kind))
          reject('INVALID_RESOURCE_TRANSACTION', 'Handoff resource or origin is forbidden');
        if (lot.quantityQ > definition.maxQuantityQ) reject('RESOURCE_LIMIT', 'Handoff lot exceeds resource limit');
        const bonuses = new Set<string>();
        for (let bonusIndex = 0; bonusIndex < lot.appliedBonuses.length; bonusIndex++) {
          if (!Object.hasOwn(lot.appliedBonuses, bonusIndex) || !nonempty(lot.appliedBonuses[bonusIndex])
            || bonuses.has(lot.appliedBonuses[bonusIndex]))
            reject('INVALID_RESOURCE_TRANSACTION', 'Invalid or repeated handoff bonus');
          bonuses.add(lot.appliedBonuses[bonusIndex]);
        }
        for (const [claim, count] of Object.entries(lot.ruleClaims))
          if (!nonempty(claim) || !positive(count))
            reject('INVALID_RESOURCE_TRANSACTION', 'Invalid handoff rule claim');
        if (!integer(nextId)) reject('RESOURCE_LIMIT', 'Lot ID exhausted');
        sourceIds.add(lot.sourceLotId);
        const imported: ResourceLot = { lotId: nextId++, origin: copyOrigin(lot.origin), parentLots: [],
          resource: lot.resource, quantityQ: lot.quantityQ, ownerId,
          appliedBonuses: [...lot.appliedBonuses], ruleClaims: { ...lot.ruleClaims }, remainingUses: lot.remainingUses };
        newLots.push(imported);
        this.changeBalance(balanceWrites, ownerId, lot.resource, BigInt(lot.quantityQ));
        facts.push({ kind: 'import', ownerId, lotId: imported.lotId,
          resource: imported.resource, quantityQ: imported.quantityQ, reason: ticket.id });
      }
      this.checkBalances(balanceWrites);
      const changedOwner = newLots.length > 0
        ? { ...owner, version: this.increment(owner.version, 'Owner version exhausted') } : owner;
      const result: ResourceTransactionResult = freeze({ createdLotIds: newLots.map(lot => lot.lotId),
        owners: newLots.length > 0 ? [copyOwner(changedOwner)] : [], facts });
      for (const lot of newLots) this.publishLot(lot);
      for (const [accountId, account] of balanceWrites) this.balances.set(accountId, account);
      if (newLots.length > 0) this.owners.set(ownerId, changedOwner);
      this.nextLotId = nextId;
      this.imports.set(ticket.id, { key, result });
      return success(this.copyResult(result));
    } catch (error) {
      if (error instanceof LedgerError) return failure(error);
      throw error;
    }
  }

  commit(transaction: ResourceTransaction): Decision<ResourceTransactionResult> {
    try {
      if (!transaction || !nonempty(transaction.id) || !Array.isArray(transaction.expects))
        reject('INVALID_RESOURCE_TRANSACTION', 'Invalid transaction header');
      const key = requestKey(transaction);
      const previous = this.transactions.get(transaction.id);
      if (previous) return previous.key === key ? success(this.copyResult(previous.result))
        : failure(new LedgerError('RECEIPT_CONFLICT', `Transaction ${transaction.id} has different content`));
      const opens = transaction.opens ?? [];
      const claims = transaction.claims ?? [];
      const spends = transaction.spends ?? [];
      const creates = transaction.creates ?? [];
      const transfers = transaction.transfers ?? [];
      const closes = transaction.closes ?? [];
      if (![opens, claims, spends, creates, transfers, closes].every(Array.isArray))
        reject('INVALID_RESOURCE_TRANSACTION', 'Transaction phases must be arrays');
      const expected = new Map<number, number>();
      for (const entry of transaction.expects) {
        if (!entry || !integer(entry.ownerId) || !integer(entry.version) || expected.has(entry.ownerId))
          reject('INVALID_RESOURCE_TRANSACTION', 'Invalid or repeated ownership version');
        expected.set(entry.ownerId, entry.version);
      }
      for (const [ownerId, version] of expected) {
        const owner = this.owners.get(ownerId);
        if (!owner || owner.closed || owner.version !== version)
          reject('STALE_RESOURCE_OWNER', `Owner ${ownerId} has stale version`);
      }
      const lotWrites = new Map<number, ResourceLot>();
      const ownerWrites = new Map<number, ResourceOwner>();
      const balanceWrites = new Map<number, Map<ResourceId, bigint>>();
      const touched = new Set<number>();
      const opened = new Set<number>();
      const facts: ResourceTransactionResult['facts'][number][] = [];
      const createdLotIds: number[] = [];
      let nextId = this.nextLotId;
      const stagedLot = (lotId: number): ResourceLot | undefined => lotWrites.get(lotId) ?? this.lots.get(lotId);
      const stagedOwner = (ownerId: number): ResourceOwner | undefined => ownerWrites.get(ownerId) ?? this.owners.get(ownerId);
      const writeLot = (lot: ResourceLot): void => {
        const previous = stagedLot(lot.lotId);
        if (!previous || previous.ownerId !== lot.ownerId || previous.resource !== lot.resource
          || previous.quantityQ !== lot.quantityQ) {
          if (previous) this.changeBalance(balanceWrites, previous.ownerId, previous.resource, -BigInt(previous.quantityQ));
          this.changeBalance(balanceWrites, lot.ownerId, lot.resource, BigInt(lot.quantityQ));
        }
        lotWrites.set(lot.lotId, lot);
      };
      const touch = (ownerId: number): void => {
        if (!integer(ownerId)) reject('INVALID_RESOURCE_TRANSACTION', 'Invalid owner ID');
        const owner = stagedOwner(ownerId);
        if (!owner || owner.closed) reject('STALE_RESOURCE_OWNER', `Owner ${ownerId} is unavailable`);
        if (!opened.has(ownerId) && !expected.has(ownerId))
          reject('STALE_RESOURCE_OWNER', `Owner ${ownerId} requires a version expectation`);
        touched.add(ownerId);
      };
      const lotFor = (lotId: number): ResourceLot => {
        if (!integer(lotId)) reject('INVALID_RESOURCE_TRANSACTION', 'Invalid lot ID');
        const lot = stagedLot(lotId);
        if (!lot) reject('INVALID_RESOURCE_TRANSACTION', `Unknown lot ${lotId}`);
        touch(lot.ownerId);
        return lot;
      };
      for (const ownerId of opens) {
        if (!integer(ownerId) || stagedOwner(ownerId) || opened.has(ownerId))
          reject('INVALID_RESOURCE_TRANSACTION', `Cannot open owner ${ownerId}`);
        ownerWrites.set(ownerId, { ownerId, version: 0, closed: false });
        opened.add(ownerId);
        touched.add(ownerId);
      }
      const claimed = new Set<string>();
      for (const claim of claims) {
        if (!claim || !nonempty(claim.key) || !positive(claim.limit) || !integer(claim.uses))
          reject('INVALID_RESOURCE_TRANSACTION', 'Invalid rule claim');
        const lot = lotFor(claim.lotId), identity = `${claim.lotId}:${claim.key}`;
        const previousCount = Object.hasOwn(lot.ruleClaims, claim.key) ? lot.ruleClaims[claim.key] : 0;
        if (claimed.has(identity) || previousCount >= claim.limit)
          reject('DUPLICATE_CLAIM', `Rule ${claim.key} exhausted its portion allowance`);
        if (!lot.quantityQ || lot.remainingUses < claim.uses)
          reject('INSUFFICIENT_RESOURCE', `Lot ${lot.lotId} has no processing allowance`);
        claimed.add(identity);
        writeLot({ ...lot, remainingUses: lot.remainingUses - claim.uses,
          ruleClaims: { ...lot.ruleClaims, [claim.key]: previousCount + 1 } });
        facts.push({ kind: 'claim', ownerId: lot.ownerId, lotId: lot.lotId, reason: claim.key });
      }
      for (const spend of spends) {
        if (!spend || !positive(spend.quantityQ) || !spendReasons.has(spend.reason))
          reject('INVALID_QUANTITY', 'Invalid spend quantity or reason');
        const lot = lotFor(spend.lotId);
        if (lot.quantityQ < spend.quantityQ) reject('INSUFFICIENT_RESOURCE', `Lot ${lot.lotId} cannot fund spend`);
        writeLot({ ...lot, quantityQ: lot.quantityQ - spend.quantityQ });
        facts.push({ kind: 'spend', ownerId: lot.ownerId, lotId: lot.lotId, resource: lot.resource,
          quantityQ: spend.quantityQ, reason: spend.reason });
      }
      for (const creation of creates) {
        if (!creation || !integer(creation.ownerId) || !Array.isArray(creation.funding)
          || creation.funding.length === 0 || !integer(creation.remainingUses)
          || !integer(creation.quantityQ) || (creation.claimBonus !== undefined && !nonempty(creation.claimBonus)))
          reject('INVALID_RESOURCE_TRANSACTION', 'Invalid funded creation');
        touch(creation.ownerId);
        const definition = this.definition(creation.resource);
        const parents: ResourceLot[] = [];
        let amount = 0n;
        let origin: ResourceOrigin | undefined;
        for (const funding of creation.funding) {
          if (!funding || !positive(funding.quantityQ)) reject('INVALID_QUANTITY', 'Funding must be positive');
          const parent = lotFor(funding.lotId);
          if (!origin) origin = parent.origin;
          if (parent.origin.kind !== origin.kind || parent.origin.receiptId !== origin.receiptId)
            reject('INVALID_RESOURCE_TRANSACTION', 'Creation funding must share one root receipt');
          if (parent.resource !== creation.resource && creation.conversionId === undefined)
            reject('INVALID_UNIT', 'Funding resource differs from output resource');
          if (parent.quantityQ < funding.quantityQ)
            reject('INSUFFICIENT_RESOURCE', `Lot ${parent.lotId} cannot fund creation`);
          if (creation.remainingUses > parent.remainingUses)
            reject('INVALID_RESOURCE_TRANSACTION', 'Creation cannot increase remaining uses');
          if (creation.claimBonus && parent.appliedBonuses.includes(creation.claimBonus))
            reject('DUPLICATE_CLAIM', `Bonus ${creation.claimBonus} was already claimed`);
          parents.push(parent);
          amount += BigInt(funding.quantityQ);
          writeLot({ ...parent, quantityQ: parent.quantityQ - funding.quantityQ });
        }
        if (!definition.allowedOrigins.includes(origin!.kind))
          reject('INVALID_RESOURCE_TRANSACTION', 'Origin cannot produce this resource');
        let output = amount;
        if (creation.conversionId !== undefined) {
          const conversion = this.conversions.get(creation.conversionId);
          if (!conversion || conversion.to !== creation.resource || !conversion.origins.includes(origin!.kind)
            || parents.some(parent => parent.resource !== conversion.from))
            reject('INVALID_UNIT', 'Conversion does not match resource or origin');
          output = amount * BigInt(conversion.numerator) / BigInt(conversion.denominator);
        }
        if (output > BigInt(Number.MAX_SAFE_INTEGER) || output > BigInt(definition.maxQuantityQ))
          reject('RESOURCE_LIMIT', 'Creation output exceeds resource limit');
        if (creation.quantityQ !== Number(output))
          reject('INVALID_QUANTITY', 'Creation output does not match funded quantity');
        if (!integer(nextId)) reject('RESOURCE_LIMIT', 'Lot ID exhausted');
        const inherited = new Set(parents.flatMap(parent => parent.appliedBonuses));
        const inheritedClaims: Record<string, number> = {};
        for (const parent of parents) for (const [claim, count] of Object.entries(parent.ruleClaims))
          Object.defineProperty(inheritedClaims, claim, { value: Math.max(Object.hasOwn(inheritedClaims, claim) ? inheritedClaims[claim] : 0, count), enumerable: true, configurable: true, writable: true });
        if (creation.claimBonus) inherited.add(creation.claimBonus);
        const child: ResourceLot = {
          lotId: nextId, origin: copyOrigin(origin!), parentLots: [...new Set(parents.map(parent => parent.lotId))],
          resource: creation.resource, quantityQ: creation.quantityQ, ownerId: creation.ownerId,
          appliedBonuses: [...inherited], ruleClaims: inheritedClaims, remainingUses: creation.remainingUses,
        };
        writeLot(child);
        createdLotIds.push(nextId++);
        if (creation.claimBonus) {
          for (const parent of parents) {
            const residual = stagedLot(parent.lotId)!;
            if (residual.quantityQ > 0)
              writeLot({ ...residual, appliedBonuses: [...new Set([...residual.appliedBonuses, creation.claimBonus])] });
          }
        }
        facts.push({ kind: 'create', ownerId: creation.ownerId, lotId: child.lotId,
          resource: child.resource, quantityQ: child.quantityQ });
      }
      const transferred = new Set<number>();
      for (const transfer of transfers) {
        if (!transfer || !integer(transfer.uses) || !integer(transfer.toOwnerId)
          || transferred.has(transfer.lotId))
          reject('INVALID_RESOURCE_TRANSACTION', 'Invalid or repeated transfer');
        const lot = lotFor(transfer.lotId);
        touch(transfer.toOwnerId);
        if (lot.remainingUses < transfer.uses)
          reject('INSUFFICIENT_RESOURCE', `Lot ${lot.lotId} has insufficient uses`);
        transferred.add(lot.lotId);
        writeLot({ ...lot, ownerId: transfer.toOwnerId, remainingUses: lot.remainingUses - transfer.uses });
        facts.push({ kind: 'transfer', ownerId: transfer.toOwnerId, lotId: lot.lotId,
          resource: lot.resource, quantityQ: lot.quantityQ });
      }
      const closed = new Set<number>();
      for (const ownerId of closes) {
        if (!integer(ownerId) || closed.has(ownerId)) reject('INVALID_RESOURCE_TRANSACTION', 'Invalid or repeated close');
        touch(ownerId);
        if (this.ownerHasPositiveBalance(ownerId, balanceWrites))
          reject('INSUFFICIENT_RESOURCE', `Owner ${ownerId} still holds positive resources`);
        closed.add(ownerId);
        facts.push({ kind: 'close', ownerId });
      }
      this.checkBalances(balanceWrites);
      for (const ownerId of touched) {
        const owner = stagedOwner(ownerId)!;
        ownerWrites.set(ownerId, { ...owner, version: this.increment(owner.version, 'Owner version exhausted'), closed: closed.has(ownerId) });
      }
      const result: ResourceTransactionResult = freeze({
        createdLotIds, owners: [...touched].sort((a, b) => a - b).map(id => copyOwner(ownerWrites.get(id)!)), facts,
      });
      for (const lot of lotWrites.values()) this.publishLot(lot);
      for (const [id, owner] of ownerWrites) this.owners.set(id, owner);
      for (const [id, account] of balanceWrites) this.balances.set(id, account);
      this.nextLotId = nextId;
      this.transactions.set(transaction.id, { key, result });
      return success(this.copyResult(result));
    } catch (error) {
      if (error instanceof LedgerError) return failure(error);
      throw error;
    }
  }

  private definition(id: ResourceId): ResourceDefinition {
    const definition = this.definitions.get(id);
    if (!definition) reject('UNKNOWN_DEFINITION', `Unknown resource ${String(id)}`);
    return definition;
  }

  private publishLot(lot: ResourceLot): void {
    const previous = this.lots.get(lot.lotId);
    if (previous) {
      const oldIds = this.ownedLots.get(previous.ownerId);
      oldIds?.delete(lot.lotId);
      if (oldIds?.size === 0) this.ownedLots.delete(previous.ownerId);
    }
    this.lots.set(lot.lotId, lot);
    if (lot.quantityQ > 0) {
      let ids = this.ownedLots.get(lot.ownerId);
      if (!ids) { ids = new Set(); this.ownedLots.set(lot.ownerId, ids); }
      ids.add(lot.lotId);
    }
  }

  private increment(value: number, message: string): number {
    if (!integer(value + 1)) reject('RESOURCE_LIMIT', message);
    return value + 1;
  }

  private changeBalance(
    writes: Map<number, Map<ResourceId, bigint>>, ownerId: number, resource: ResourceId, delta: bigint,
  ): void {
    let account = writes.get(ownerId);
    if (!account) {
      account = new Map(this.balances.get(ownerId));
      writes.set(ownerId, account);
    }
    account.set(resource, (account.get(resource) ?? 0n) + delta);
  }

  private ownerHasPositiveBalance(ownerId: number, writes: Map<number, Map<ResourceId, bigint>>): boolean {
    const account = writes.get(ownerId) ?? this.balances.get(ownerId);
    return account !== undefined && [...account.values()].some(quantity => quantity > 0n);
  }

  private checkBalances(writes: Map<number, Map<ResourceId, bigint>>): void {
    for (const [ownerId, account] of writes) {
      for (const [resource, quantity] of account) {
        const limit = BigInt(this.definition(resource).maxQuantityQ);
        if (quantity < 0n || quantity > limit)
          reject('RESOURCE_LIMIT', `Owner ${ownerId} exceeds ${resource} limit`);
      }
    }
  }

  private copyResult(result: ResourceTransactionResult): ResourceTransactionResult {
    return {
      createdLotIds: [...result.createdLotIds], owners: result.owners.map(copyOwner),
      facts: result.facts.map(fact => ({ ...fact })),
    };
  }
}
