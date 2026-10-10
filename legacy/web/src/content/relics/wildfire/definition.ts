import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "燃烧敌人死亡时传播灼烧，最多两代；传播距离 {burn.spreadRadius}，目标数 {burn.spreadTargets}。", castPreview: false },
  id: "wildfire",
  name: "野火书签",
  icon: "wildfire",
  tag: "火焰",
  book: "flame",
  desc: "燃烧敌人死亡时传播灼烧，最多传播两代；每层增加传播距离与目标数。",
  max: 2,
  grants: {
    burnSpread: 1,
  },
} satisfies Relic;
