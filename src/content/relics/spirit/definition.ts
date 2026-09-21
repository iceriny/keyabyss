import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { summonStacks: 1 },
  id: "spirit",
  name: "折纸使魔",
  tag: "纸灵",
  icon: "spirit",
  desc: "每次完词延长纸灵存在时间，纸灵数量上限增加 1。",
  max: 3,
  affinity: ["spirit"],
} satisfies Relic;
