import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "电弧每跳伤害倍率 {chain.retention}；导电引爆伤害 {overload.damage}，周围敌人受到其70%。", castPreview: false },
  grants: { chainConduction: 1 },
  id: "conductor",
  name: "超导银墨",
  tag: "雷鸣",
  icon: "conductor",
  desc: "电弧跳跃衰减减轻，导电引爆伤害提高35%。",
  max: 2,
  affinity: ["storm"],
} satisfies Relic;
