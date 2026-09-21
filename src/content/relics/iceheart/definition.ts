import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { empoweredFreeze: 1 },
  id: "iceheart",
  name: "凛冬残卷",
  tag: "觉醒",
  icon: "iceheart",
  desc: "冰河纪事获得30护盾，持续冰针雨更密集；重型冰矛额外冻结附近敌人。",
  max: 1,
  book: "frost",
  requires: ["frost", "brittle"],
  rarity: "awaken",
  affinity: [],
} satisfies Relic;
