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
  x: number;
  y: number;
  links: readonly string[];
  grants?: Partial<Record<CombatStat, number>>;
  capabilities?: readonly CombatCapability[];
  requires?: readonly CombatCapability[];
  exclusive?: "binding";
}

export interface TalentLoadout {
  allocated: string[];
  secondaryBook?: BookId;
}

export interface TalentConfiguration {
  version: 1;
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
