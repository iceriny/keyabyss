import { mul, pow, when, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "armor.multiplier": mul(
    pow(0.75, stat("damageArmor", "护甲层数")),
    when(stat("fragileDamage", "持有玻璃书封"), 1.3, 1),
  ),
} satisfies ValueDefinitions;
