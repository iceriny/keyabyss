import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "连笔伤害倍率 {cast.combo}；施法伤害 {cast.hit}。", castPreview: true },
  grants: { comboPower: 1 },
  id: "rhythm",
  name: "连笔字帖",
  tag: "快攻",
  icon: "rhythm",
  desc: "连笔伤害加成翻倍：最多额外获得25%施法伤害。",
  max: 1,
  affinity: [],
} satisfies Relic;
