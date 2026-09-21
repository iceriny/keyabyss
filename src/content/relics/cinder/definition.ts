import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "灼烧每层每跳伤害 {burn.damage}，每0.5秒结算一次。", castPreview: false },
  id: "cinder",
  name: "余烬墨水",
  icon: "cinder",
  tag: "火焰",
  book: "flame",
  desc: "火焰每跳伤害提高30%。",
  max: 3,
  grants: {
    burnPower: 1,
  },
} satisfies Relic;
