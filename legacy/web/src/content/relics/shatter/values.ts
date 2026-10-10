import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "shatter.radius": add(
    100,
    mul(20, stat("shatterStacks", "冻裂层数")),
    mul(25, stat("effectReach", "范围强化层数")),
  ),
  "shatter.damage": add(28, mul(18, stat("shatterStacks", "冻裂层数"))),
} satisfies ValueDefinitions;
