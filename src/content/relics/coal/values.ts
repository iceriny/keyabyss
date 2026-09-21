import { mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "coal.shield": mul(5, stat("emberShield", "熔爆护盾层数")),
} satisfies ValueDefinitions;
