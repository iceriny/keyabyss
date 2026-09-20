import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { deathFrostVolley: 1 },
  id: "avalanche",
  name: "雪崩圣典",
  tag: "觉醒",
  icon: "❆",
  desc: "冻裂击杀向四周射出6枚冰针，冰枪额外穿透2次；连锁冰针不再自我复制。",
  max: 1,
  book: "frost",
  requires: ["shatter", "permafrost"],
  rarity: "awaken",
  affinity: [],
} satisfies Relic;
