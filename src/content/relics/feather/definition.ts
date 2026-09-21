import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { autofillCadence: 1 },
  id: "feather",
  name: "通灵羽毛笔",
  tag: "稀有",
  rarity: "rare",
  icon: "feather",
  desc: "每完成 4 次手动咒文，下一词输入前 2 个字母即可自动补全。",
  max: 1,
  minWordLength: 3,
  affinity: [],
} satisfies Relic;
