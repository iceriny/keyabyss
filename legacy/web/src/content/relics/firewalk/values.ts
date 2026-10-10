import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "fireTrail.radius": add(60, mul(20, stat("fireTrail", "火径层数"))),
  "fireTrail.duration": add(2, stat("fireTrail", "火径层数")),
} satisfies ValueDefinitions;
