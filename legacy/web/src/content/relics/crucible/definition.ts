import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "普通火弹爆炸火场半径 {fire.radius}；强化施法采用同一公式的强化分支。", castPreview: false },
  id: "crucible",
  name: "熔炉封蜡",
  icon: "crucible",
  tag: "火焰",
  book: "flame",
  desc: "火弹熔爆与爆炸火场半径增加25。",
  max: 2,
  grants: {
    fireRadius: 1,
  },
} satisfies Relic;
