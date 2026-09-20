import type { Relic } from "../../../contracts/content.ts";
export default {
  command: "halo",
  grants: { dashShock: 1 },
  id: "dashnova",
  name: "留白之环",
  tag: "生存",
  icon: "◎",
  desc: "闪避后清除落点周围 135 范围的子弹，并推开附近敌人。",
  max: 1,
  affinity: [],
} satisfies Relic;
