import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  provides: ["carrier"],
  values,
  description: { template: "可用制作力量唤醒纸灵，数量上限增加一只。所有纸灵共用制作力量，停笔后不会无限攻击；复写仍需另行学习。", castPreview: false },
  grants: { summonStacks: 1, copyPages: 1 },
  id: "spirit",
  name: "折纸使魔",
  tag: "纸灵",
  icon: "spirit",
  desc: "可用制作力量唤醒纸灵，纸灵数量上限增加一只；所有纸灵共用有限的制作力量。",
  max: 3,
  affinity: ["spirit"],
} satisfies Relic;
