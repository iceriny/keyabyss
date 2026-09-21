import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "电弧传导范围 {chain.radius}；爆墨瓶范围 {blast.radius}。", castPreview: false },
  grants: { effectReach: 1 },
  id: "reach",
  name: "远行墨迹",
  tag: "连锁",
  icon: "reach",
  desc: "电弧传导范围增加 100，爆炸范围增加 25。",
  max: 2,
  affinity: [],
} satisfies Relic;
