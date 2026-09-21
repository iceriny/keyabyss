import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "法术击退倍率 {impulse.multiplier}；碰撞伤害翻倍。", castPreview: false },
  grants: { impulsePower: 1 },
  id: "heavy",
  name: "鲸骨笔杆",
  tag: "冲击",
  icon: "heavy",
  desc: "法术击退提高60%；撞墙与撞敌造成的碰撞伤害翻倍。",
  max: 2,
  affinity: [],
} satisfies Relic;
