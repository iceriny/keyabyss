import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "cast.short": add(1, mul(0.6, stat("shortWordDamage", "短咒连珠层数"))),
} satisfies ValueDefinitions;
