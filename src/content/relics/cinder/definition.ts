import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "cinder",
  name: "余烬墨水",
  icon: "♨",
  tag: "火焰",
  book: "flame",
  desc: "火焰每跳伤害提高30%。",
  max: 3,
  grants: {
    burnPower: 1,
  },
} satisfies Relic;
