import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { chainTargets: 1 },
  id: "chain",
  name: "导电墨水",
  tag: "雷鸣",
  icon: "chain",
  desc: "电弧多跳跃 1 个目标；非雷鸣咒典获得 1 次电弧跳跃。",
  max: 3,
  affinity: ["storm"],
} satisfies Relic;
