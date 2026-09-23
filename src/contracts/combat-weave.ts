/** Capabilities describe composable functions, independent of a book or relic ID. */
export const combatCapabilities = ['cold', 'heat', 'conduction', 'carrier', 'guard', 'release', 'recovery'] as const;
export type CombatCapability = (typeof combatCapabilities)[number];
export type SpellElement = 'ice' | 'fire' | 'storm' | 'paper';
export type SpellSource = 'manual' | 'derived' | 'carrier' | 'fragment' | 'conduction';
export interface SpellRoot {
  readonly id: number;
  readonly room: number;
  remaining: number;
  primaryClaimed: boolean;
  readonly crystal: boolean;
  readonly heat: boolean;
  readonly conduction: boolean;
  readonly reserve: number;
}
export interface SpellPayload {
  readonly root: SpellRoot;
  readonly source: SpellSource;
  readonly depth: number;
}
export interface WeaveSummary {
  readonly manualCharacters: number;
  readonly pagesCreated: number;
  readonly pagesReleased: number;
  readonly pagesBlocked: number;
  readonly fragments: number;
  readonly recoveredHeat: number;
}
export interface CarrierPage {
  readonly id: number;
  readonly element: SpellElement;
  readonly damage: number;
  readonly payload: SpellPayload;
  x: number;
  y: number;
  life: number;
  age: number;
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
