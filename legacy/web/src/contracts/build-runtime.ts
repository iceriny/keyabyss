import type { BookId } from './content-ids.ts';
import type { CompiledRuleProgram, ObjectKind, PropertyId, TargetPolicy } from './build-rules.ts';
import type { ResourceHandoff, ResourceId, ResourceOrigin, ResourceTransactionResult } from './build-resources.ts';

export interface SpellPosition { readonly x: number; readonly y: number }
export type SpellForm = 'shot' | 'chain' | 'pierce' | 'burst' | 'blade';
export interface SpellWordSession { readonly targetId: number; readonly revision: number; readonly word: string }
export interface SpellLetterBinding { readonly session: SpellWordSession; readonly position: number; readonly character: string }
/** Evaluated once when a letter is bound; later acquisitions cannot rewrite its reward or routing. */
export interface SpellLetterPlan {
  readonly storedShare: number;
  readonly workShare: number;
  readonly storedRetention: number;
  readonly workRetention: number;
  readonly capacity: number;
  readonly delayTicks: number;
  readonly lifeTicks: number;
  readonly inheritShape: boolean;
  readonly opportunityCostQ: number;
  readonly spread: boolean;
  readonly maxPerWord: number;
}
export interface SpellLetter {
  readonly binding: SpellLetterBinding;
  readonly reward: 'power' | 'work' | 'guard';
  readonly powerPerUnitQ: number;
  readonly templateApplications?: number;
  readonly plan?: SpellLetterPlan;
}
export interface SpellField {
  readonly shape: 'circle' | 'trail';
  readonly radius: number;
  /** A trail is the capsule between this point and the object's fixed position. */
  readonly from?: SpellPosition;
  readonly allocation: 'equal' | 'onContact';
  /** Recovery still requires an owned finish rule; this flag alone never grants resources. */
  readonly onFinish: 'recover' | 'lose';
  /** Frozen at creation; spending an application on routing cannot reschedule the field. */
  readonly intervalTicks: number;
}
export interface SpellStatusTiming {
  readonly intervalTicks: number;
  readonly nextAtTick: number;
  readonly delayedTicks: number;
}
export interface SpellObject {
  readonly id: number;
  readonly kind: ObjectKind;
  readonly rootReceiptId: string;
  readonly program: CompiledRuleProgram;
  readonly book: BookId;
  readonly shape: SpellForm;
  readonly position: SpellPosition;
  readonly targetId?: number;
  readonly targetPolicy: TargetPolicy;
  readonly properties: Readonly<Partial<Record<PropertyId, string | number>>>;
  readonly createdAtTick: number;
  readonly readyAtTick: number;
  readonly expiresAtTick: number;
  readonly remainingApplications: number;
  readonly state: 'ready' | 'stored' | 'carried' | 'flight' | 'closed';
  /** A physical spirit owns this cargo until delivery, return or cleanup. */
  readonly transport?: { readonly actorId: number; readonly returning: boolean };
  readonly transportReturned?: true;
  /** The same stored portions can relay only once, including after transport or repacking. */
  readonly relayed?: true;
  readonly derived: boolean;
  readonly inheritedShape: boolean;
  readonly exitOf?: number;
  readonly targetWaitUsed?: boolean;
  readonly letter?: SpellLetter;
  readonly field?: SpellField;
  readonly status?: SpellStatusTiming;
}
export interface ManualSpellReceipt {
  readonly id: string;
  readonly wordLength: number;
  readonly wordSession?: SpellWordSession;
  readonly humanPositions: readonly number[];
  readonly primaryPowerQ: number;
  /** Native material quantities belong to this same receipt, not separate suppliers. */
  readonly primaryMaterialsQ?: Readonly<Partial<Record<'cold' | 'heat' | 'charge', number>>>;
  readonly auxiliaryWorkQ: number;
  /** Allocated from the same auxiliary budget; opportunity stays in the shared account. */
  readonly auxiliaryResourcesQ?: Readonly<Partial<Record<Exclude<ResourceId, 'work'>, number>>>;
  readonly program: CompiledRuleProgram;
  readonly shape: SpellForm;
  readonly position: SpellPosition;
  readonly targetId?: number;
  readonly tick: number;
  readonly lifeTicks: number;
  readonly applications: number;
  readonly processingUses: number;
}
export type ManualSpellInput = Omit<ManualSpellReceipt, 'primaryPowerQ' | 'primaryMaterialsQ' | 'auxiliaryWorkQ' | 'auxiliaryResourcesQ'> & {
  /** Engine-owned input quality/cadence adjustment, applied only to the primary budget. */
  readonly primaryMultiplier?: number;
};
export interface RuntimeMutation {
  readonly objects: readonly SpellObject[];
  readonly transaction: ResourceTransactionResult;
}
export interface RuntimeLetterRedemption extends RuntimeMutation {
  readonly matchedCount: number;
}
/** Optional redistribution and shape for funded children; unspecified resources use the common shares. */
export interface ResourceAllocationOptions {
  readonly resourceShares?: Readonly<Partial<Record<ResourceId, readonly number[]>>>;
  readonly shape?: SpellForm;
  readonly applications?: number;
}
export interface RuntimeRulePayment {
  readonly objectId: number;
  readonly ruleId: string;
  readonly portionLimit?: number;
  readonly processingUses: number;
  readonly costs: readonly { readonly ownerId: number; readonly resource: ResourceId; readonly quantityQ: number }[];
}
export interface ObjectFunding {
  readonly lotId: number;
  readonly quantityQ: number;
}
export interface RuntimeDamageCommit {
  readonly targetId: number;
  readonly powerQ: number;
  readonly materials: Readonly<Partial<Record<ResourceId, number>>>;
  readonly object: SpellObject;
  readonly transaction: ResourceTransactionResult;
}
export interface RuntimeFieldCommit {
  readonly object: SpellObject;
  readonly commits: readonly RuntimeDamageCommit[];
  readonly transaction: ResourceTransactionResult;
}
export interface FiniteObjectRequest {
  readonly kind: 'shell' | 'status' | 'field';
  readonly fromObjectId: number;
  readonly share: number;
  /** Per-material fractions override share; omitted materials keep the common fraction. */
  readonly resourceShares?: Readonly<Partial<Record<ResourceId, number>>>;
  readonly field?: Omit<SpellField, 'intervalTicks'>;
  /** Loss applies only to the portion entering this object; the untouched parent stays intact. */
  readonly retention?: number;
  readonly position?: SpellPosition;
  readonly targetId?: number;
  readonly properties?: Readonly<Partial<Record<PropertyId, string | number>>>;
  readonly tick: number;
  readonly delayTicks: number;
  readonly lifeTicks: number;
  readonly applications: number;
}
export interface StoredCopyRequest {
  readonly material: 'crystal' | 'paper';
  readonly capacity: number;
  readonly tick: number;
  readonly delayTicks: number;
  readonly lifeTicks: number;
}
export interface RuntimeTransportAssembly {
  /** Includes the selected shell as the first entry; all inputs must remain physically compatible. */
  readonly objectIds: readonly number[];
  readonly waitTicks: number;
}
export interface RuntimeSpellRelay {
  readonly objectId: number;
  /** Omitted for a stationary shell, whose position must match the authoritative object. */
  readonly actorId?: number;
  readonly position: SpellPosition;
  readonly maxDistance: number;
  readonly chargeCostQ: number;
  /** Passive fields spend one application; the travelling spell supplies this leg's charge. */
  readonly sourceCharge?: true;
}
export interface SpellCloseResult {
  readonly object: SpellObject;
  /** Closed objects hand all unspent lots to this single-use spell owner. */
  readonly escrow: SpellObject;
  readonly reason: 'guard' | 'thermal' | 'expiry' | 'release' | 'fracture' | 'room' | 'death' | 'miss' | 'routing' | 'transport';
  readonly transaction: ResourceTransactionResult;
}
export interface RuntimeReserveEntry {
  readonly lotId: number;
  readonly origin: ResourceOrigin;
  readonly resource: ResourceId;
  readonly quantityQ: number;
  readonly availableAfterManual: number;
  readonly availableInRoom: number;
}
/** Held by one running expedition, consumed by the immediately following room. */
export interface RuntimeReserveHandoff {
  readonly fromRoom: number;
  readonly toRoom: number;
  readonly resources: ResourceHandoff;
  /** Remaining genuine completions that cannot use reserves, including when the account is empty. */
  readonly cooldownManuals?: number;
}

/** Evaluated from one frozen manual cast; individual materials share the selected policy and limit. */
export interface RuntimeReserveBurstPolicy {
  readonly targetPowerRatio: number;
  readonly minimumTargetRatio: number;
  readonly share: number;
  readonly totalLimitQ: number;
  readonly cooldownManuals: number;
}
