import { mul, input } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "rescue.health": mul(input("maxHp", "最大生命"), 0.45),
} satisfies ValueDefinitions;
