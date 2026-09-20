import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { summonLegion: 1 },
  id: "legion",
  name: "千纸军团",
  tag: "觉醒",
  icon: "翼",
  desc: "增加3只纸灵；每次交叉斩额外发动一次全员俯冲。仍需要完词维持。",
  max: 1,
  book: "spirit",
  requires: ["spirit", "bond"],
  rarity: "awaken",
  affinity: [],
} satisfies Relic;
