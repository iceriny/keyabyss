import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "非冰霜施法附加 {cold.amount} 寒气；冻结 {cold.duration} 秒。冰霜直接施法基础积寒100。", castPreview: false },
  grants: { coldStacks: 1 },
  id: "frost",
  name: "零度批注",
  tag: "冰霜",
  icon: "frost",
  desc: "所有施法附加寒气；已有寒气增加，冻结持续更久。",
  max: 3,
  affinity: ["frost"],
} satisfies Relic;
