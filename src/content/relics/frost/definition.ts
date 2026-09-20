import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { coldStacks: 1 },
  id: "frost",
  name: "零度批注",
  tag: "冰霜",
  icon: "❄",
  desc: "所有施法附加寒气；已有寒气增加，冻结持续更久。",
  max: 3,
  affinity: ["frost"],
} satisfies Relic;
