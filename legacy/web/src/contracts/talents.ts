import type { BookId } from "./game.ts";
import type { CombatStat } from "./stats.ts";
import type { CombatCapability } from "./combat-weave.ts";

export interface TalentNode {
  id: string;
  name: string;
  description: string;
  school: BookId | "shared";
  root?: BookId;
  cost: number;
  kind?: 'path' | 'rule' | 'keystone';
  family?: string;
  budget?: number;
  links: readonly string[];
  grants?: Partial<Record<CombatStat, number>>;
  capabilities?: readonly CombatCapability[];
  requires?: readonly CombatCapability[];
  requiresNodes?: readonly string[];
  exclusive?: string;
}

export interface TalentLoadout {
  allocated: string[];
  secondaryBook?: BookId;
}

export interface TalentConfiguration {
  version: 1;
  graphVersion?: number;
  byBook: Partial<Record<BookId, TalentLoadout>>;
}

export interface TalentReceipt {
  characters: number;
  points: number;
}

export interface TalentProgress extends TalentConfiguration {
  manualCharacters: number;
  byRun: Record<string, number>;
  receipts: Record<string, TalentReceipt>;
}
