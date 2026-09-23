import type { BookId } from './content-ids.ts';

export interface BuildExample {
  readonly id: string;
  readonly title: string;
  readonly book: BookId;
  readonly family: string;
  readonly talentIds: readonly string[];
  /** Acquisition order; evolution removes the replaced relic in the real upgrade flow. */
  readonly relicIds: readonly string[];
  readonly eventId: string;
  readonly purpose: string;
  readonly tradeoff: string;
  readonly eventChange: string;
}
export interface DemonstrationMetrics {
  readonly seconds: number;
  readonly casts: number;
  readonly damage: number;
  readonly health: number;
  readonly shield: number;
  readonly manualCharacters: number;
  readonly pagesCreated: number;
  readonly pagesReleased: number;
  readonly pagesBlocked: number;
  readonly recoveredHeat: number;
  readonly kills: number;
  readonly state: string;
  readonly roomVisit: number;
  readonly remainingShots: number;
  readonly remainingPages: number;
}
export interface DemonstrationSnapshot {
  readonly example: BuildExample;
  readonly talentIds: readonly string[];
  readonly heldRelics: readonly string[];
  readonly talentNames: readonly string[];
  readonly heldRelicNames: readonly string[];
  readonly revisedRelicNames?: readonly string[];
  readonly eventStatus: string;
  readonly eventApplied: boolean;
  readonly eventScope?: 'room' | 'chapter' | 'run';
  readonly eventRecordStatus?: string;
  readonly elapsed: number;
  readonly baseline: DemonstrationMetrics;
  readonly revised?: DemonstrationMetrics;
  readonly running: boolean;
}
export interface DemonstrationHandle {
  step(seconds: number): DemonstrationSnapshot;
  snapshot(): DemonstrationSnapshot;
  stop(): void;
  destroy(): void;
}
