import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "impulse.multiplier": add(1, mul(0.6, stat("impulsePower", "击退层数"))),
} satisfies ValueDefinitions;
