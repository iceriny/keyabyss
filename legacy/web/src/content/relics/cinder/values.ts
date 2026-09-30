import { add, mul, stat, input } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "burn.damage": mul(
    6,
    input("damageMultiplier", "构筑伤害倍率"),
    add(1, mul(0.3, stat("burnPower", "余烬层数"))),
  ),
} satisfies ValueDefinitions;
