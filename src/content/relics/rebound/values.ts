import { mul, when, stat, input } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "parry.cooldown": mul(
    input("parryCooldown", "基础弹反冷却"),
    when(stat("parryHaste", "持有回锋遗物"), 0.7, 1),
  ),
} satisfies ValueDefinitions;
