import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  provides: ["carrier"],
  values,
  description: { template: "纸灵上限 {summon.capacity}；未标记目标单次伤害 {summon.damage}；每词维持 {summon.duration} 秒（累计上限18秒）。每12个有效人工字符还可承载一张35%主术威力的复写页。", castPreview: false },
  grants: { summonStacks: 1, copyPages: 1 },
  id: "spirit",
  name: "折纸使魔",
  tag: "纸灵",
  icon: "spirit",
  desc: "每次完词延长纸灵存在时间，纸灵数量上限增加1。每12个有效人工字符还可承载一张35%主术威力的复写页。",
  max: 3,
  affinity: ["spirit"],
} satisfies Relic;
