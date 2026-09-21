import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "每次完词维持纸灵，无纸灵时唤醒一只。纸灵上限 {summon.capacity}；未标记目标单次伤害 {summon.damage}；每词维持 {summon.duration} 秒（累计上限18秒）。", castPreview: false },
  grants: { summonBond: 1 },
  id: "bond",
  name: "共命书线",
  tag: "纸灵",
  icon: "bond",
  desc: "纸灵攻击提高30%，每词额外维持2秒；无纸灵时唤醒一只。",
  max: 2,
  affinity: ["spirit"],
} satisfies Relic;
