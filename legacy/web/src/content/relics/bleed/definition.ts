import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "将主术的部分伤害转为灼烧；每层使转为灼烧时的威力保留提高3%。", castPreview: false },
  grants: { bleedStacks: 1 },
  id: "bleed",
  name: "腐蚀墨迹",
  tag: "持续",
  icon: "bleed",
  desc: "将主术的部分伤害转为灼烧；每层使转为灼烧时的威力保留提高3%。",
  max: 2,
  affinity: [],
} satisfies Relic;
