/** Integer resource accounts. Only the authoritative simulation can issue receipts. */
export const RESOURCE_SCALE = 1024;
export type ResourceId = 'power' | 'work' | 'cold' | 'heat' | 'charge' | 'opportunity';
export type ReserveResource = Exclude<ResourceId, 'work' | 'opportunity'>;
/** Sixteenth-power space units. Capacity is shared; adding another material creates no extra slots. */
export const RESERVE_SPACE_UNITS: Readonly<Record<ReserveResource, number>> = Object.freeze({ power: 16, cold: 1, heat: 64, charge: 16 });
export type ResourceOrigin = Readonly<{
  kind: 'manual' | 'enemyProjectile' | 'acquisition';
  receiptId: string;
}>;

export type BuildErrorCode =
  | 'UNKNOWN_DEFINITION' | 'INVALID_DEFINITION' | 'INVALID_CONDITION_CONTEXT'
  | 'INVALID_QUANTITY' | 'INVALID_UNIT' | 'MODE_CONFLICT' | 'MISSING_PERMIT'
  | 'INVALID_ALLOCATION' | 'UNBOUNDED_RULE_CYCLE' | 'INVALID_RULE_ORDER'
  | 'STALE_RESOURCE_OWNER' | 'INSUFFICIENT_RESOURCE' | 'DUPLICATE_CLAIM'
  | 'RESOURCE_LIMIT' | 'INVALID_RESOURCE_TRANSACTION' | 'RECEIPT_CONFLICT';
export interface BuildDiagnostic {
  readonly code: BuildErrorCode;
  readonly definitionId?: string;
  readonly path?: string;
  /** Diagnostic text is for development; UI maps codes to specific player explanations. */
  readonly message: string;
}
export type Decision<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly errors: readonly BuildDiagnostic[] };

export interface ResourceDefinition {
  readonly id: ResourceId;
  readonly maxQuantityQ: number;
  readonly allowedOrigins: readonly ResourceOrigin['kind'][];
}
/** Registered conversions are owned by engine adapters, never supplied by a content transaction. */
export interface ResourceConversion {
  readonly id: string;
  readonly from: ResourceId;
  readonly to: ResourceId;
  readonly numerator: number;
  readonly denominator: number;
  readonly origins: readonly ResourceOrigin['kind'][];
}
export interface ResourceLot {
  readonly lotId: number;
  readonly origin: ResourceOrigin;
  readonly parentLots: readonly number[];
  readonly resource: ResourceId;
  readonly quantityQ: number;
  readonly ownerId: number;
  readonly appliedBonuses: readonly string[];
  /** Per-portion rule claims survive splits, conversions, ownership changes and merges. */
  readonly ruleClaims: Readonly<Record<string, number>>;
  readonly remainingUses: number;
}
export interface ResourceHandoffLot {
  readonly sourceLotId: number;
  readonly origin: ResourceOrigin;
  readonly resource: ResourceId;
  readonly quantityQ: number;
  readonly appliedBonuses: readonly string[];
  readonly ruleClaims: Readonly<Record<string, number>>;
  readonly remainingUses: number;
}
export interface ResourceHandoff {
  readonly id: string;
  readonly lots: readonly ResourceHandoffLot[];
}
export interface ResourceOwner {
  readonly ownerId: number;
  readonly version: number;
  readonly closed: boolean;
}
export interface ResourceReceipt {
  readonly origin: ResourceOrigin;
  readonly ownerId: number;
  readonly grants: readonly {
    /** Income can atomically fund the primary object and its shared work account. */
    readonly ownerId?: number;
    readonly resource: ResourceId;
    readonly quantityQ: number;
    readonly remainingUses: number;
  }[];
}
export interface ResourceReceiptResult {
  readonly lotIds: readonly number[];
  readonly ownerVersion: number;
}
export interface OwnershipVersion {
  readonly ownerId: number;
  readonly version: number;
}
export interface ResourceSpend {
  readonly lotId: number;
  readonly quantityQ: number;
  readonly reason: 'attack' | 'guard' | 'processing' | 'loss' | 'healing';
}
export interface ResourceTransfer {
  readonly lotId: number;
  readonly toOwnerId: number;
  /** Routing pays one or more uses. Escrow/ownership-only moves may use zero. */
  readonly uses: number;
}
export interface FundedCreation {
  readonly ownerId: number;
  readonly resource: ResourceId;
  readonly funding: readonly { readonly lotId: number; readonly quantityQ: number }[];
  /** Absent for conserved splits. Conversion output is floor(sum(funding) * rate). */
  readonly conversionId?: string;
  readonly quantityQ: number;
  readonly remainingUses: number;
  /** Inherited claims are always unioned. A claimed bonus can never be claimed twice. */
  readonly claimBonus?: string;
}
export interface ResourceFact {
  readonly kind: 'income' | 'spend' | 'transfer' | 'create' | 'close' | 'claim' | 'export' | 'import';
  readonly resource?: ResourceId;
  readonly quantityQ?: number;
  readonly lotId?: number;
  readonly ownerId: number;
  readonly reason?: string;
}
export interface ResourceClaim {
  readonly lotId: number;
  readonly key: string;
  readonly limit: number;
  /** Processing descendants inherit the reduced allowance. */
  readonly uses: number;
}
export interface ResourceTransaction {
  readonly id: string;
  /** Includes every existing owner touched, including transfer/creation destinations. */
  readonly expects: readonly OwnershipVersion[];
  /** New IDs must not exist. IDs cannot be reused after an owner closes. */
  readonly opens?: readonly number[];
  /** Claims are validated atomically before costs and funded output inherit them. */
  readonly claims?: readonly ResourceClaim[];
  readonly spends?: readonly ResourceSpend[];
  readonly transfers?: readonly ResourceTransfer[];
  readonly creates?: readonly FundedCreation[];
  /** Close requires no positive lots left; transfer remaining lots to escrow explicitly. */
  readonly closes?: readonly number[];
}
export interface ResourceTransactionResult {
  readonly createdLotIds: readonly number[];
  readonly owners: readonly ResourceOwner[];
  readonly facts: readonly ResourceFact[];
}
export interface ResourceLedgerSnapshot {
  readonly lots: readonly ResourceLot[];
  readonly owners: readonly ResourceOwner[];
}
