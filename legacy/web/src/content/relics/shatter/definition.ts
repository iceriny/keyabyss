import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "冻结敌人死亡时爆裂，范围 {shatter.radius}，伤害 {shatter.damage}，最多连锁三层。", castPreview: false },
  grants: { shatterStacks: 1 },
  id: "shatter",
  name: "冰裂残页",
  tag: "冰霜",
  icon: "shatter",
  desc: "冻结敌人死亡时爆裂，范围伤害提高，最多连锁三层。",
  max: 2,
  affinity: ["frost"],
} satisfies Relic;
