import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { grazeCharge: 1 },
  id: "graze",
  name: "飞白笔锋",
  tag: "反制",
  icon: "graze",
  desc: "擦弹获得双倍共鸣，同时获得少量护盾；每颗子弹仅结算一次。",
  max: 1,
  affinity: [],
} satisfies Relic;
