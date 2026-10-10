import {
  add,
  mul,
  when,
  stat,
  input,
} from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "overload.damage": mul(
    add(34, mul(input("chapter", "章节索引（首章为0）"), 8)),
    add(1, mul(0.35, stat("chainConduction", "导电强化层数"))),
    input("damageMultiplier", "构筑伤害倍率"),
  ),
  "chain.retention": when(stat("chainConduction", "持有导电强化"), 0.91, 0.76),
} satisfies ValueDefinitions;
