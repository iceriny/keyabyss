import type { CombatStat } from './stats.ts';
import type { CombatCapability } from './combat-weave.ts';
export type BuildEventKind = 'revision' | 'loan' | 'bridge' | 'smelt' | 'archive' | 'proofread' | 'contract' | 'trial';
export type BuildEventScope = 'room' | 'chapter' | 'run';
export interface BuildEventDefinition {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly kind: BuildEventKind;
  readonly family?: string;
  readonly scope: BuildEventScope;
  readonly grants: Partial<Record<CombatStat, number>>;
  readonly needs?: readonly CombatCapability[];
  readonly talentStats?: readonly CombatStat[];
  readonly maxHealthCost: number;
  readonly rewardDebt?: number;
  readonly pressure?: number;
  readonly evolve?: boolean;
}
export interface BuildEventChoice {
  readonly activation?: 'immediate' | 'after-room';
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly scope: BuildEventScope;
  readonly grants: Partial<Record<CombatStat, number>>;
  readonly maxHealthCost: number;
  readonly rewardDebt: number;
  readonly pressure: number;
  readonly heal: number;
  readonly replacement?: { readonly from: string; readonly to: string };
  /** Cross-graph references use talent:<id> or relic:<id>; local graph IDs stay unchanged. */
  readonly nodeIds: readonly string[];
}
export interface BuildEventOffer {
  readonly id: string;
  readonly definitionId: string;
  readonly name: string;
  readonly description: string;
  readonly choices: readonly BuildEventChoice[];
}
export interface BuildEventRecord {
  readonly id: string;
  readonly definitionId: string;
  readonly name: string;
  readonly choice: BuildEventChoice;
  readonly room: number;
  readonly chapter: number;
  readonly active: boolean;
  readonly status?: 'active' | 'pending' | 'expired' | 'kept' | 'applied';
}
