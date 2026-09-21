import type {
  ValueDefinitions,
  ValueExpression as E,
} from "../contracts/values.ts";
import type { CombatStats } from "../contracts/stats.ts";
import { combatStats } from "../contracts/stats.ts";

export class ValueRules {
  readonly definitions: ValueDefinitions;
  constructor(definitions: ValueDefinitions) {
    this.definitions = definitions;
    const visit = (e: E, path: Set<string>): void => {
      if (typeof e === "number") {
        if (!Number.isFinite(e)) throw new Error("Non-finite formula constant");
      } else if ("ref" in e) {
        if (!(e.ref in definitions))
          throw new Error(`Unknown formula: ${e.ref}`);
        if (path.has(e.ref)) throw new Error(`Formula cycle: ${e.ref}`);
        visit(definitions[e.ref], new Set([...path, e.ref]));
      } else if ("op" in e) {
        if (
          !["add", "mul", "pow", "min"].includes(e.op) ||
          e.args.length < 2 ||
          (e.op === "pow" && e.args.length !== 2)
        )
          throw new Error("Invalid formula operator/arity");
        e.args.forEach((arg) => visit(arg, path));
      } else if ("when" in e) {
        visit(e.when, path);
        visit(e.yes, path);
        visit(e.no, path);
      } else if ("stat" in e) {
        if (!combatStats.includes(e.stat) || !e.label)
          throw new Error("Invalid formula stat");
      } else if (!("input" in e) || !e.input || !e.label)
        throw new Error("Invalid formula operand");
    };
    Object.entries(definitions).forEach(([key, e]) => visit(e, new Set([key])));
  }
  expression(id: string): E {
    const e = this.definitions[id];
    if (e === undefined) throw new Error(`Unknown formula: ${id}`);
    return e;
  }
  evaluate(
    id: string,
    stats: CombatStats,
    inputs: Readonly<Record<string, number>> = {},
  ): number {
    const calc = (e: E): number => {
      if (typeof e === "number") return e;
      if ("ref" in e) return calc(this.expression(e.ref));
      if ("stat" in e) return stats[e.stat];
      if ("input" in e) {
        const value = inputs[e.input];
        if (!Number.isFinite(value))
          throw new Error(`Missing formula input: ${e.input}`);
        return value;
      }
      if ("when" in e) return calc(e.when) ? calc(e.yes) : calc(e.no);
      const args = e.args.map(calc);
      switch (e.op) {
        case "add":
          return args.reduce((a, b) => a + b, 0);
        case "mul":
          return args.reduce((a, b) => a * b, 1);
        case "pow":
          return Math.pow(args[0], args[1]);
        case "min":
          return Math.min(...args);
      }
    };
    const result = calc(this.expression(id));
    if (!Number.isFinite(result))
      throw new Error(`Non-finite formula result: ${id}`);
    return result;
  }
  format(id: string): string {
    const render = (e: E): string => {
      if (typeof e === "number") return String(e);
      if ("ref" in e) return render(this.expression(e.ref));
      if ("stat" in e || "input" in e) return e.label;
      if ("when" in e)
        return `〔${render(e.when)}：${render(e.yes)}，否则${render(e.no)}〕`;
      const args = e.args.map(render);
      if (e.op === "min") return `min(${args.join("，")})`;
      return `(${args.join({ add: "＋", mul: "×", pow: "^" }[e.op])})`;
    };
    return render(this.expression(id));
  }
}
