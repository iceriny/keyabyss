import { add, when, stat, input } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "chain.count": add(
    input("nativeChain", "咒典基础跳跃数"),
    stat("chainTargets", "导电墨水层数"),
    when(
      input("nativeChain", "雷鸣咒典"),
      when(stat("overloadPull", "超导觉醒"), 2, 0),
      0,
    ),
    input("empoweredChain", "强化施法额外跳跃数"),
  ),
} satisfies ValueDefinitions;
