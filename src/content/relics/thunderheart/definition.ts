import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { ultimateChain: 1 },
  id: "thunderheart",
  name: "永昼雷章",
  tag: "觉醒",
  icon: "☀",
  desc: "雷鸣终章延长3秒；期间每次完词额外落下两道雷击，命中回复少量护盾。",
  max: 1,
  book: "storm",
  requires: ["stormcell", "haste"],
  rarity: "awaken",
  affinity: [],
} satisfies Relic;
