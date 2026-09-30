import type { BookId } from './content-ids.ts';
import type { BuildDiagnostic, ReserveResource, ResourceId } from './build-resources.ts';

export const BUILD_RULE_VERSION = 1;
export const ruleStages = ['income', 'assemble', 'dispatch', 'prepareHit', 'commitHit', 'afterHit', 'finish'] as const;
export type RuleStage = typeof ruleStages[number];
export const ruleEvents = [
  'manual.complete', 'word.interrupted', 'spell.assemble', 'spell.dispatch', 'hit.prepare', 'hit.commit',
  'hit.after', 'shell.assemble', 'shell.heat', 'shell.fracture', 'shell.finish', 'spell.finish', 'route.finish', 'status.start', 'status.contact', 'status.tick', 'status.finish', 'status.death', 'status.extract',
  'projectile.intercept', 'letter.match', 'field.apply', 'field.relay', 'field.finish', 'room.finish', 'transport.finish',
] as const;
export type RuleEvent = typeof ruleEvents[number];
export type ObjectKind = 'spell' | 'shell' | 'status' | 'field' | 'reserve' | 'letter' | 'projectile';
export type CapabilityId =
  | 'cold' | 'heat' | 'charge' | 'storage' | 'fracture' | 'transfer' | 'copy'
  | 'guard' | 'release' | 'recover' | 'ongoing' | 'field' | 'letters' | 'letterStorage' | 'transport' | 'merge' | 'summon';
export type PermitId = `permit:${string}`;
export type ConditionContext = 'purchase' | 'acquisition' | 'runtime';
export type PropertyId = 'material' | 'shape' | 'integrity' | 'heat' | 'ageTicks' | 'remainingTicks' | 'distance' | 'endReason';
export type CounterId = 'humanCharacters' | 'wordLength' | 'healthShare' | 'targetCount' | 'reserveQ' | 'wordErrors' | 'matchedCharacters' | 'targetPowerRatio';
export type Condition =
  | { readonly all: readonly Condition[] }
  | { readonly any: readonly Condition[] }
  | { readonly not: Condition }
  | { readonly mainBook: BookId }
  | { readonly allocated: string }
  | { readonly permit: PermitId }
  | { readonly owned: string; readonly minLevel: number }
  | { readonly capability: CapabilityId; readonly source: 'build' | 'talent' }
  | { readonly mode: string; readonly value: string }
  | { readonly objectProperty: PropertyId; readonly comparison: 'eq' | 'gte'; readonly value: string | number }
  | { readonly counter: CounterId; readonly comparison: 'gte' | 'lte'; readonly value: number };
export interface ConditionState {
  readonly mainBook: BookId;
  readonly allocated: ReadonlySet<string>;
  readonly permits: ReadonlySet<PermitId>;
  readonly owned: Readonly<Record<string, number>>;
  readonly buildCapabilities: ReadonlySet<CapabilityId>;
  readonly talentCapabilities: ReadonlySet<CapabilityId>;
  readonly modes?: Readonly<Record<string, string>>;
  readonly properties?: Readonly<Partial<Record<PropertyId, string | number>>>;
  readonly counters?: Readonly<Partial<Record<CounterId, number>>>;
}

export type QuantityUnit = 'ratio' | 'count' | 'ticks' | 'distance' | ResourceId;
export type Quantity =
  | { readonly value: number; readonly unit: QuantityUnit }
  | { readonly stat: string }
  | { readonly balance: ResourceId }
  | { readonly counter: CounterId }
  | { readonly add: readonly [Quantity, Quantity] }
  | { readonly subtract: readonly [Quantity, Quantity] }
  | { readonly multiply: readonly [Quantity, Quantity] }
  | { readonly divide: readonly [Quantity, Quantity] }
  | { readonly min: readonly [Quantity, Quantity] }
  | { readonly max: readonly [Quantity, Quantity] };
export interface NumericDefinition {
  readonly id: string;
  readonly unit: QuantityUnit;
  readonly base: number;
  readonly min: number;
  readonly max: number;
  readonly integer: boolean;
  readonly stage: RuleStage;
  /** Additions share one pool; named multiplier pools multiply after their own additive merge. */
  readonly multiplierPools: readonly string[];
}
export interface NumericModifier {
  readonly stat: string;
  readonly value: number;
  readonly unit: QuantityUnit;
  readonly pool: 'add' | string;
}
export type LotSelector = 'self' | 'stored' | 'unspent' | 'ongoing' | 'reserve';
export type TargetPolicy = 'original' | 'nearest' | 'strongest' | 'farthest' | 'nextUnhit' | 'player';
export type NoTargetPolicy = 'waitOnce' | 'recover' | 'lose';
export interface RuleCost {
  readonly resource: ResourceId;
  readonly amount: Quantity;
}
export type OperationDefinition =
  | { readonly op: 'Supply'; readonly incomeKind: 'primary' | 'work'; readonly receiptKind: 'manual';
      readonly amountPerHumanCharacter: Quantity; readonly distributionWeights: Readonly<Partial<Record<ResourceId, number>>> }
  | { readonly op: 'Attach'; readonly lotSelector: LotSelector; readonly targetSelector: ObjectKind; readonly resource: ResourceId;
      readonly amount: Quantity; readonly reserveShare?: Quantity; readonly reserveLimit?: Quantity;
      readonly reserveBurst?: { readonly minimumTargetRatio: Quantity; readonly share: Quantity; readonly totalLimit: Quantity;
        readonly cooldownManuals: Quantity } }
  | { readonly op: 'Allocate'; readonly sourceLot: LotSelector; readonly shares: readonly number[]; readonly maxChildren: number;
      readonly remainderPolicy: 'parent' | 'firstChild' | 'loss';
      readonly resourceShares?: Readonly<Partial<Record<ResourceId, readonly number[]>>>;
      readonly shape?: 'shot' | 'chain' | 'pierce' | 'burst' | 'blade'; readonly applications?: Quantity }
  | { readonly op: 'Store'; readonly shellArchetype: 'crystal' | 'paper'; readonly capacityUnits: Quantity;
      readonly share?: Quantity; readonly retention?: Quantity;
      readonly releaseDelayTicks: Quantity; readonly lifeTicks: Quantity; readonly onNoCapacity: 'retain' | 'lose' }
  | { readonly op: 'Transfer'; readonly targetPolicy: TargetPolicy; readonly maxDistance: Quantity; readonly hopCost: Quantity;
      readonly maxHops: Quantity; readonly onNoTarget: NoTargetPolicy }
  | { readonly op: 'Heat'; readonly thermalLot: LotSelector; readonly shellSelector: 'self' | 'nearest'; readonly amount: Quantity;
      readonly threshold: Quantity; readonly heatMode: 'open' | 'retain' | 'fracture' }
  | { readonly op: 'Fracture'; readonly integrityCost: Quantity; readonly allocationPattern: 'radial' | 'aimed'; readonly maxPieces: Quantity;
      readonly trigger: 'hit' | 'heat' | 'finish' }
  | { readonly op: 'Release'; readonly unspentLotSelector: 'unspent'; readonly targetPolicy: TargetPolicy; readonly exitClaim: 'close';
      readonly onNoTarget: NoTargetPolicy }
  | { readonly op: 'Copy'; readonly templateSelector: 'manualSpell' | 'storedSpell'; readonly workCost: Quantity;
      readonly fundedPowerFactor: Quantity; readonly inheritMask: readonly ('shape' | 'cold' | 'heat' | 'charge')[]; readonly maxCopies: Quantity;
      readonly storage?: { readonly shellArchetype: 'crystal' | 'paper'; readonly capacityUnits: Quantity;
        readonly releaseDelayTicks: Quantity; readonly lifeTicks: Quantity } }
  | { readonly op: 'Merge'; readonly compatibilityKey: 'shapeAndTarget'; readonly sameRoot: true; readonly maxInputs: Quantity;
      readonly waitTicks: Quantity; readonly outputPolicy: 'concentrate' | 'preserveShape' }
  | { readonly op: 'Recover'; readonly remainingSelector: LotSelector; readonly retention: Quantity; readonly capacityKey: string;
      readonly reuseAfter: 'nextManual' | 'nextRoom'; readonly resource?: ReserveResource; readonly share?: Quantity }
  | { readonly op: 'Guard'; readonly projectileClass: 'reflectable'; readonly selectionOrder: 'oldest' | 'newest';
      readonly powerPerBlockedUnit: Quantity; readonly reserveShare: Quantity; readonly projectileClaim: 'once'; readonly maxInputs?: Quantity }
  | { readonly op: 'Convert'; readonly fromComponent: ResourceId; readonly toComponent: ResourceId; readonly share: Quantity;
      readonly rate: Quantity; readonly conversionStage: 'income' | 'assemble' | 'finish' }
  | { readonly op: 'Mark'; readonly positionSelector: 'nextWord' | 'nearbyWords'; readonly matchPolicy: 'manualOnly'; readonly maxPositions: Quantity;
      readonly rewardAllocation: 'power' | 'work' | 'guard'; readonly humanReceiptClaim: 'once';
      readonly opportunityCost?: Quantity; readonly maxPerWord?: Quantity;
      readonly rewardPlan?: { readonly storedShare: Quantity; readonly workShare: Quantity;
        readonly storedRetention: Quantity; readonly workRetention: Quantity; readonly capacityUnits: Quantity;
        readonly releaseDelayTicks: Quantity; readonly lifeTicks: Quantity; readonly inheritShape: boolean } }
  | { readonly op: 'Field'; readonly shape: 'circle' | 'trail'; readonly radius: Quantity; readonly lifeTicks: Quantity;
      readonly share?: Quantity; readonly resourceShares?: Readonly<Partial<Record<ResourceId, number>>>;
      readonly maxApplications: Quantity; readonly lotAllocation: 'equal' | 'onContact'; readonly onFinish: 'recover' | 'lose' }
  | { readonly op: 'Ongoing'; readonly action: 'advance'; readonly applications: Quantity }
  | { readonly op: 'Ongoing'; readonly action: 'delay'; readonly coldCost: Quantity; readonly extraTicks: Quantity; readonly maxDelayTicks: Quantity };

export interface RuleDefinition {
  readonly id: string;
  readonly stage: RuleStage;
  readonly event: RuleEvent;
  readonly targetKind: ObjectKind;
  readonly when: Condition;
  readonly operation: OperationDefinition;
  readonly resourceCost: readonly RuleCost[];
  readonly modeSlot?: string;
  readonly modeValue?: string;
  readonly inherit: 'never' | 'shape' | 'paidProcessing';
  readonly repeat: { readonly unit: 'receipt' | 'lot' | 'object' | 'enemyProjectile'; readonly limit: number };
  /** Ordering constraints, not gameplay connections. */
  readonly after?: readonly string[];
}
export interface ModeChoice { readonly slot: string; readonly value: string }
export interface SupplyDirection {
  readonly resource: ResourceId;
  readonly weight: number;
  readonly modeSlot?: string;
  readonly modeValue?: string;
}
export interface BuildContribution {
  readonly rules: readonly string[];
  readonly capabilities: readonly CapabilityId[];
  readonly modifiers: readonly NumericModifier[];
  readonly modes: readonly ModeChoice[];
  /** New directions share the one auxiliary budget. Duplicate entrances use the greatest weight, not a sum. */
  readonly supplyDirections?: readonly SupplyDirection[];
}
export interface SemanticProfile {
  readonly concepts: Readonly<Record<string, number>>;
  readonly objectKinds: readonly ObjectKind[];
  readonly operationKinds: readonly OperationDefinition['op'][];
  readonly inputProperties: readonly string[];
  readonly outputProperties: readonly string[];
  readonly tradeoffKinds: readonly string[];
}
export interface TalentDefinition extends BuildContribution {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly cost: number;
  readonly root?: BookId;
  readonly purchaseRequires: Condition;
  readonly permits: readonly PermitId[];
  readonly selectableModes?: Readonly<Record<string, readonly string[]>>;
  readonly semantic: SemanticProfile;
  readonly appearance: 'ordinary' | 'mechanic' | 'keystone' | 'book';
}
export interface RelicDefinition extends BuildContribution {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly maxLevel: number;
  readonly eligibility: Condition;
  readonly permitsAll: readonly PermitId[];
  readonly evolutionFrom?: readonly string[];
  readonly semantic: SemanticProfile;
  readonly budget: { readonly perOpportunity: number; readonly inherited: boolean };
}
export interface RuleRegistry {
  readonly version: number;
  readonly rules: Readonly<Record<string, RuleDefinition>>;
  readonly numerics: Readonly<Record<string, NumericDefinition>>;
  readonly talents: Readonly<Record<string, TalentDefinition>>;
  readonly relics: Readonly<Record<string, RelicDefinition>>;
  readonly books: Readonly<Record<BookId, BuildContribution>>;
  readonly modeSlots: Readonly<Record<string, readonly string[]>>;
  /** Used only while no permanent or temporary choice occupies the slot. */
  readonly modeDefaults?: Readonly<Record<string, string>>;
  readonly legacyRelicIds?: Readonly<Record<string, string>>;
}
export interface BuildOverride extends BuildContribution {
  readonly id: string;
  readonly scope: 'room' | 'chapter' | 'run';
  readonly expiresAfter: number;
  /** Only these existing slots are shadowed. Capabilities do not issue talent permits. */
  readonly shadows: readonly string[];
}
export interface BuildAsset {
  readonly instanceId: string;
  readonly definitionId: string;
  readonly level: number;
  readonly state: 'owned' | 'leased' | 'pledged' | 'returned' | 'replaced';
}
export interface BuildSnapshot {
  readonly version: number;
  readonly revision: number;
  readonly mainBook: BookId;
  /** Frozen at departure. Events cannot mutate allocation or issue permits. */
  readonly allocated: readonly string[];
  readonly selectedModes: Readonly<Record<string, string>>;
  readonly assets: readonly BuildAsset[];
  readonly overrides: readonly BuildOverride[];
}
export interface CompiledRule {
  readonly definition: RuleDefinition;
  readonly sourceIds: readonly string[];
}
export interface CompiledRuleProgram {
  readonly version: number;
  readonly revision: number;
  readonly mainBook: BookId;
  readonly allocated: readonly string[];
  readonly owned: Readonly<Record<string, number>>;
  readonly rules: readonly CompiledRule[];
  readonly byEvent: Readonly<Partial<Record<RuleEvent, readonly CompiledRule[]>>>;
  readonly byStage: Readonly<Record<RuleStage, readonly CompiledRule[]>>;
  readonly numerics: Readonly<Record<string, number>>;
  readonly modes: Readonly<Record<string, string>>;
  readonly permits: readonly PermitId[];
  readonly capabilities: readonly CapabilityId[];
  readonly talentCapabilities: readonly CapabilityId[];
  /** Static caps are per claimed unit; the executor multiplies by actual funded units. */
  readonly claimsPerUnit: Readonly<Record<RuleDefinition['repeat']['unit'], number>>;
  readonly diagnostics: readonly BuildDiagnostic[];
}
