import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "受到致命伤时复活一次，回复 {rescue.health} 点生命并清屏。", castPreview: false },
  grants: { lethalRescue: 1 },
  id: "rescue",
  name: "未完待续",
  tag: "稀有",
  rarity: "rare",
  icon: "rescue",
  desc: "受到致命伤时复活一次，回复 45% 生命并清屏。",
  max: 1,
  affinity: [],
} satisfies Relic;
