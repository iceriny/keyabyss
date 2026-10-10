export type { SpellBlueprint, SpellPacket, SpellResources, SpellResource, BuildProgram } from './combat-weave.ts';
export interface BurnContribution {
  readonly id: number;
  readonly rootId: number | null;
  readonly packetId: number | null;
  readonly sourceIds?: readonly string[];
  readonly source: import('./combat-weave.ts').SpellSource | 'ambient';
  readonly recoverable: boolean;
  readonly recoveryRate: number;
  balance: number;
  rate: number;
  life: number;
  readonly spreadDepth: number;
}
