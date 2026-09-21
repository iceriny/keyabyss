import {
  add,
  mul,
  stat,
  input,
  ref,
} from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "blast.radius": add(90, mul(25, stat("effectReach", "范围强化层数"))),
  "blast.ratio": mul(0.35, stat("hitExplosion", "爆墨瓶层数")),
  "blast.damage": mul(
    input("hitDamage", "本次施法命中伤害"),
    ref("blast.ratio"),
  ),
} satisfies ValueDefinitions;
