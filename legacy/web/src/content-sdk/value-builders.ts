import type { ValueExpression as E } from "../contracts/values.ts";
import type { CombatStat } from "../contracts/stats.ts";
export const stat = (stat: CombatStat, label: string): E => ({ stat, label });
export const input = (input: string, label: string): E => ({ input, label });
export const ref = (ref: string): E => ({ ref });
export const add = (...args: E[]): E => ({ op: "add", args });
export const mul = (...args: E[]): E => ({ op: "mul", args });
export const pow = (base: E, exponent: E): E => ({
  op: "pow",
  args: [base, exponent],
});
export const min = (...args: E[]): E => ({ op: "min", args });
export const when = (condition: E, yes: E, no: E): E => ({
  when: condition,
  yes,
  no,
});
