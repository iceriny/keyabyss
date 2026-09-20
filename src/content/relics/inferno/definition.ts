import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "inferno",
  name: "不灭灰烬卷",
  icon: "♨",
  tag: "觉醒",
  book: "flame",
  desc: "灼烧上限提高至5层；终式延长至7秒，陨火间隔缩短至0.45秒。",
  max: 1,
  grants: {
    inferno: 1,
  },
  rarity: "awaken",
  requires: ["cinder", "pitch"],
} satisfies Relic;
