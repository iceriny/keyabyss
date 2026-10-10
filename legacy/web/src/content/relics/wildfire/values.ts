import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "burn.spreadRadius": add(130, mul(25, stat("burnSpread", "传播层数"))),
  "burn.spreadTargets": add(2, stat("burnSpread", "传播层数")),
} satisfies ValueDefinitions;
