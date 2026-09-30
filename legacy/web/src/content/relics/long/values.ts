import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "cast.long": add(1, mul(0.75, stat("longWordDamage", "长句回响层数"))),
} satisfies ValueDefinitions;
