import { RELICS } from "./catalog.ts";
import { add, mul, when, input, ref } from "../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../contracts/values.ts";
import { collectValues } from "../shared/relic-build.ts";

export const baseValues: ValueDefinitions = {
  "cast.word": add(35, mul(input("wordLength", "词长"), 5.4)),
  "cast.base": mul(
    ref("cast.word"),
    input("damageMultiplier", "构筑伤害倍率"),
    when(
      input("shortWord", "短咒条件满足"),
      ref("cast.short"),
      when(input("longWord", "长咒条件满足"), ref("cast.long"), 1),
    ),
    when(input("perfect", "无错字"), ref("cast.perfect"), 1),
    ref("cast.combo"),
  ),
  "cast.hit": mul(ref("cast.base"), input("schoolMultiplier", "咒典施法倍率")),
  "build.multiplier": input(
    "damageMultiplier",
    "持有遗物的伤害修饰乘积（含生命条件）",
  ),
  "player.maxHp": input("maxHp", "当前最大生命（包含本次获取效果）"),
  "player.maxDash": input("maxDash", "当前充能上限（包含本次获取效果）"),
};
export const combatValues = collectValues(baseValues, RELICS);
