import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { precisionWindow: 1 },
  id: "hourglass",
  name: "停笔沙漏",
  tag: "闪避",
  icon: "hourglass",
  desc: "闪避后世界以10%速度流动，持续1.5秒；期间可继续打字施法，闪避与弹反仍按真实时间恢复。",
  max: 1,
  affinity: [],
} satisfies Relic;
