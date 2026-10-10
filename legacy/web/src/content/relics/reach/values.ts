import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "chain.radius": add(265, mul(100, stat("effectReach", "范围强化层数"))),
} satisfies ValueDefinitions;
