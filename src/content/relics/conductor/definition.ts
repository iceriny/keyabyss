import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { chainConduction: 1 },
  id: "conductor",
  name: "超导银墨",
  tag: "雷鸣",
  icon: "⌇",
  desc: "电弧跳跃衰减减轻，导电引爆伤害提高35%。",
  max: 2,
  affinity: ["storm"],
} satisfies Relic;
