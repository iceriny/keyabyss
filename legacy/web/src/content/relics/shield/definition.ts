import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { partialWordShield: 1 },
  id: "shield",
  name: "残句书签",
  tag: "生存",
  icon: "shield",
  desc: "输入中的目标被连锁或纸灵击杀，转化为 10 点护盾。",
  max: 1,
  affinity: [],
} satisfies Relic;
