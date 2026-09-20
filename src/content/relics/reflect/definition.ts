import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { reflectPower: 1 },
  id: "reflect",
  name: "镜面批注",
  tag: "反制",
  icon: "◈",
  desc: "拆弹反击伤害提高 60%；拆弹后下一次施法伤害翻倍。",
  max: 1,
  affinity: [],
} satisfies Relic;
