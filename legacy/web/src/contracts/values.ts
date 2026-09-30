import type { CombatStat } from "./stats.ts";

/** A bounded arithmetic tree, shared by simulation and formula rendering. */
export type ValueExpression =
  | number
  | { stat: CombatStat; label: string }
  | { input: string; label: string }
  | { ref: string }
  | { op: "add" | "mul" | "pow" | "min"; args: readonly ValueExpression[] }
  | { when: ValueExpression; yes: ValueExpression; no: ValueExpression };
export type ValueDefinitions = Readonly<Record<string, ValueExpression>>;
export interface RelicDescription {
  template: string;
  castPreview?: boolean;
  wordLength?: number;
}
