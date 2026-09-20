import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "crucible",
  name: "熔炉封蜡",
  icon: "♨",
  tag: "火焰",
  book: "flame",
  desc: "火弹熔爆与爆炸火场半径增加25。",
  max: 2,
  grants: {
    fireRadius: 1,
  },
} satisfies Relic;
