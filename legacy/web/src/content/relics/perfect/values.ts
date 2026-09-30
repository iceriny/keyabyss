import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "cast.perfect": add(1.08, mul(0.35, stat("perfectDamage", "无瑕落款层数"))),
} satisfies ValueDefinitions;
