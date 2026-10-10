import type { SpellForm } from './build-runtime.ts';

/** Native geometry and finite timing; secondary book roots do not install these patterns. */
export interface NativeSpellDefinition {
  readonly shape: SpellForm;
  readonly element: 'ice' | 'fire' | 'storm' | 'paper';
  readonly hitCounts: readonly [number, number];
  readonly hitRetention: number;
  readonly ongoingShare: number;
  readonly ongoingTicks: number;
  readonly ongoingApplications: number;
  readonly splashShare: number;
  readonly splashRadius: number;
  readonly summon?: { readonly workCost: number; readonly powerFactor: number; readonly capacity: number };
}
export interface SpellReference { readonly room: number; readonly objectId: number }

/** Positions are playable-character indices; display spaces and automatic completion earn nothing. */
export interface CompletedWordInput {
  readonly id: string;
  readonly word: string;
  readonly humanPositions: readonly number[];
  readonly targetId?: number;
  readonly wordRevision?: number;
}
