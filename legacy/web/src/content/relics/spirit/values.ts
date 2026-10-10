import {
  add,
  mul,
  when,
  stat,
  input,
} from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "summon.damage": mul(
    add(12, mul(stat("summonStacks", "纸灵层数"), 3)),
    add(1, mul(stat("summonBond", "羁绊层数"), 0.3)),
    input("damageMultiplier", "构筑伤害倍率"),
    when(input("marked", "目标被标记"), 1.45, 1),
  ),
  "summon.duration": add(
    4,
    stat("summonStacks", "纸灵层数"),
    mul(stat("summonBond", "羁绊层数"), 2),
  ),
  "summon.capacity": add(
    input("nativeSummons", "咒典基础纸灵数"),
    stat("summonStacks", "纸灵层数"),
    when(
      stat("summonBond", "持有羁绊"),
      when(
        input("nativeSummons", "咒典自带纸灵"),
        0,
        when(stat("summonStacks", "已有纸灵遗物"), 0, 1),
      ),
      0,
    ),
    when(stat("summonLegion", "持有军团"), 3, 0),
    when(
      input("nativeSummons", "咒典自带纸灵"),
      when(input("ultimateActive", "终式生效"), 4, 0),
      0,
    ),
  ),
} satisfies ValueDefinitions;
