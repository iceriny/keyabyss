import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { lethalRescue: 1 },
  id: "rescue",
  name: "未完待续",
  tag: "稀有",
  rarity: "rare",
  icon: "↻",
  desc: "受到致命伤时复活一次，回复 45% 生命并清屏。",
  max: 1,
  affinity: [],
} satisfies Relic;
