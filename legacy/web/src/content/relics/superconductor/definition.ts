import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "{description} 普通施法电弧跳跃 {chain.count} 次。", castPreview: false },
  grants: { overloadPull: 1 },
  id: "superconductor",
  name: "超导禁卷",
  tag: "觉醒",
  icon: "superconductor",
  desc: "电弧额外跳跃2次，过载向内牵引敌人并造成更大范围爆炸。",
  max: 1,
  book: "storm",
  requires: ["chain", "conductor"],
  rarity: "awaken",
  affinity: [],
} satisfies Relic;
