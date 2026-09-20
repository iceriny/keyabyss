import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "firewalk",
  name: "灼痕行书",
  icon: "♨",
  tag: "火焰",
  book: "flame",
  desc: "闪避火场半径增加20，持续时间延长1秒。",
  max: 2,
  grants: {
    fireTrail: 1,
  },
} satisfies Relic;
