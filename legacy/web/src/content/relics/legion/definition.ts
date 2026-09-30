import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "{description} 纸灵上限 {summon.capacity}；未标记目标单次伤害 {summon.damage}；每词维持 {summon.duration} 秒（累计上限18秒）。", castPreview: false },
  grants: { summonLegion: 1 },
  id: "legion",
  name: "千纸军团",
  tag: "觉醒",
  icon: "legion",
  desc: "增加3只纸灵；每次交叉斩额外发动一次全员俯冲。仍需要完词维持。",
  max: 1,
  book: "spirit",
  requires: ["spirit", "bond"],
  rarity: "awaken",
  affinity: [],
} satisfies Relic;
