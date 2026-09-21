import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { frostField: 1 },
  id: "permafrost",
  name: "永冻墨池",
  tag: "冰霜",
  icon: "permafrost",
  desc: "霜场持续增加3秒，半径增加35；无霜场时施法额外生成小型霜场。",
  max: 1,
  affinity: ["frost"],
} satisfies Relic;
