/** Capabilities describe composable functions, independent of a book or relic ID. */
export const combatCapabilities = ['cold', 'heat', 'conduction', 'carrier', 'guard', 'release', 'recovery'] as const;
export type CombatCapability = (typeof combatCapabilities)[number];
export type SpellElement = 'ice' | 'fire' | 'storm' | 'paper';
export type SpellSource = 'manual' | 'derived' | 'carrier' | 'fragment' | 'conduction' | 'recovered';
export type SpellShape = 'shot' | 'chain' | 'pierce' | 'burst' | 'blade';
export type SpellResource = 'power' | 'cold' | 'heat' | 'charge' | 'copy';
export type SpellResources = Record<SpellResource, number>;
export interface SpellBlueprint {
  readonly element: SpellElement;
  readonly shape: SpellShape;
  readonly operations: readonly ('split' | 'conduct' | 'burn' | 'store' | 'release' | 'pierce')[];
  readonly nativeSegments: number;
}
export interface BuildProgram {
  readonly blueprint: SpellBlueprint;
  readonly secondary?: SpellElement;
  readonly materialRate: number;
  readonly processingRetention: number;
  readonly copyRate: number;
  readonly copyCost: number;
  readonly carrierCapacity: number;
  readonly carrierLife: number;
  readonly carrierDelay: number;
  readonly carrierRelease: boolean;
  readonly carrierGuard: boolean;
  readonly carrierRetain: boolean;
  readonly carrierRelay: boolean;
  readonly crystalStorage: boolean;
  readonly mergePayload: boolean;
  readonly guardNewest: boolean;
  readonly guardEfficiency: number;
  readonly thermalRelease: boolean;
  readonly fragmentCount: number;
  readonly fragmentShare: number;
  readonly chainCount: number;
  readonly chainShare: number;
  readonly chainReach: number;
  readonly recoveryRate: number;
  readonly recoveryEligible: boolean;
  readonly recoveryCapacity: number;
  readonly recoveryExtract: boolean;
  readonly reservePersist: boolean;
  readonly reserveThreshold: number;
  readonly spellPower: number;
  readonly copyInheritance: boolean;
  readonly reactionEfficiency: number;
  readonly paperRecovery: boolean;
  readonly missRecovery: boolean;
  readonly markCarrier: boolean;
  readonly markSpread: boolean;
  readonly summonTransport: boolean;
  readonly payloadPierce: number;
  readonly sources: readonly string[];
  readonly unimplemented: readonly string[];
}
/** A root owns one manual receipt and a calculated defensive execution allowance. */
export interface SpellRoot {
  readonly id: number;
  readonly room: number;
  readonly sourceIds?: readonly string[];
  readonly manualCharacters: number;
  readonly basePower: number;
  executionLimit: number;
  executions: number;
}
/** Every packet owns its resources. Splitting transfers balances out of the parent. */
export interface SpellPacket {
  readonly id: number;
  readonly root: SpellRoot;
  readonly rootId: number;
  readonly room: number;
  readonly source: SpellSource;
  readonly blueprint: SpellBlueprint;
  readonly program: BuildProgram;
  owner: string;
  readonly depth: number;
  readonly history: Set<string>;
  readonly resources: SpellResources;
  remainingLife: number;
  reserve: number;
  hitBudget: number;
  hitsCommitted: number;
  lastHitPower: number;
  spent: boolean;
}
export type SpellPayload = SpellPacket;
export interface WeaveSummary {
  readonly manualCharacters: number;
  readonly pagesCreated: number;
  readonly pagesReleased: number;
  readonly pagesBlocked: number;
  readonly fragments: number;
  readonly recoveredHeat: number;
  readonly rejectedPages?: number;
  readonly rejectedBurn?: number;
  readonly lostPower?: number;
  readonly lostHeat?: number;
  readonly lostMaterial?: number;
  readonly lostSupply?: number;
  readonly lostBurn?: number;
}
export interface CarrierPage {
  readonly id: number;
  readonly element: SpellElement;
  damage: number;
  readonly payload: SpellPacket;
  readonly payloads: SpellPacket[];
  guardBalance: number;
  transportedBy?: number;
  x: number;
  y: number;
  life: number;
  age: number;
  exit?: 'attack' | 'guard' | 'thermal' | 'expiry' | 'clear';
}
export interface LetterMote {
  x: number;
  y: number;
  readonly letter: string;
  readonly targetId: number;
  readonly word: string;
  readonly index: number;
  readonly start: { x: number; y: number };
  readonly control: { x: number; y: number };
  readonly seed: number;
  age: number;
}
