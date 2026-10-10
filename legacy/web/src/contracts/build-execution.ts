import type { BuildDiagnostic, Decision, ResourceTransactionResult } from './build-resources.ts';
import type { CompiledRule, CompiledRuleProgram, ConditionState, CounterId, OperationDefinition, RuleEvent, RuleStage, TargetPolicy } from './build-rules.ts';
import type { RuntimeDamageCommit, RuntimeMutation, RuntimeSpellRelay, SpellCloseResult, SpellObject, SpellPosition, SpellWordSession } from './build-runtime.ts';

/** Emitted by the authoritative input/hit/lifetime driver, never by content definitions. */
export interface SpellRuleEvent {
  readonly id: string;
  readonly event: RuleEvent;
  readonly stage: RuleStage;
  readonly tick: number;
  readonly subject: SpellObject;
  /** A closing subject is immutable; its still-unspent resources belong to this escrow. */
  readonly unspentObjectId?: number;
  readonly sourceObjectId?: number;
  readonly targetObjectId?: number;
  readonly hitTarget?: SpellRuleTarget;
  readonly endReason?: SpellCloseResult['reason'];
  readonly counters: Readonly<Partial<Record<CounterId, number>>>;
  readonly projectile?: { readonly id: string; readonly powerQ: number; readonly reflectable: boolean };
  readonly interrupted?: { readonly session: SpellWordSession; readonly humanPositions: readonly number[]; readonly position: SpellPosition };
}
export interface SpellRuleTarget extends SpellPosition { readonly id: number }
export interface RuleOperationResult {
  readonly objects: readonly SpellObject[];
  readonly transaction: ResourceTransactionResult;
  readonly damage?: RuntimeDamageCommit;
  readonly flight?: { readonly object: SpellObject; readonly target: SpellRuleTarget; readonly from?: SpellPosition; readonly via?: readonly SpellPosition[]; readonly pattern?: 'radial' | 'aimed' };
  readonly blockedPowerQ?: number;
  readonly relayedFields?: readonly SpellObject[];
  readonly closure?: { readonly subject: SpellObject; readonly escrow: SpellObject; readonly reason: 'thermal' | 'fracture' };
  /** Missing destination explicitly retires a fragment rather than finding a distant target. */
  readonly destinations?: readonly { readonly objectId: number; readonly target?: SpellRuleTarget }[];
}
export interface RuleExecutionContext {
  readonly event: SpellRuleEvent;
  readonly rule: CompiledRule;
  readonly object: SpellObject;
  readonly condition: ConditionState;
  readonly quantity: (value: import('./build-rules.ts').Quantity) => number;
}
/** Engine adapters own world queries and native input/letter semantics. No content callbacks. */
export interface SpellRuleWorld {
  selectTarget(object: SpellObject, policy: TargetPolicy, maxDistance?: number): SpellRuleTarget | undefined;
  targetsWithin?(position: SpellPosition, radius: number): readonly SpellRuleTarget[];
  /** Used only when no direct target fits: positions come from live shells or physical actors. */
  selectRelay?(object: SpellObject, policy: TargetPolicy, maxDistance: number, chargeCostQ: number, tick: number):
    { readonly relays: readonly RuntimeSpellRelay[]; readonly target: SpellRuleTarget } | undefined;
  readonly flightLifeTicks: number;
  supply(context: RuleExecutionContext, operation: Extract<OperationDefinition, { op: 'Supply' }>): Decision<RuntimeMutation>;
  mark(context: RuleExecutionContext, operation: Extract<OperationDefinition, { op: 'Mark' }>): Decision<RuntimeMutation>;
}
export interface RuleExecutionOutcome {
  readonly ruleId: string;
  readonly status: 'applied' | 'skipped' | 'failed';
  readonly reason?: 'condition' | 'inheritance' | 'limit' | 'resources' | 'capacity' | 'no-target' | 'closed';
  readonly result?: RuleOperationResult;
}
export interface RuleEventResult {
  readonly eventId: string;
  readonly program: CompiledRuleProgram;
  readonly outcomes: readonly RuleExecutionOutcome[];
  /** Earlier successful rules remain committed; the failing operation itself is atomic. */
  readonly errors: readonly BuildDiagnostic[];
}
