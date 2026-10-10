import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  provides: ["cold"],
  values,
  description: { template: "将主术的少量威力转为寒气；每层使相同寒气的积累效果提高15%。", castPreview: false },
  grants: { coldStacks: 1 },
  id: "frost",
  name: "零度批注",
  tag: "冰霜",
  icon: "frost",
  desc: "将主术的少量威力转为寒气；每层使相同寒气的积累效果提高15%。",
  max: 3,
  affinity: ["frost"],
} satisfies Relic;
