import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "直接施法留下4秒腐蚀，每秒伤害 {bleed.damage}，状态最多叠3层。", castPreview: false },
  grants: { bleedStacks: 1 },
  id: "bleed",
  name: "腐蚀墨迹",
  tag: "持续",
  icon: "bleed",
  desc: "直接施法留下4秒腐蚀，每秒造成8点伤害，最多叠3层。",
  max: 2,
  affinity: [],
} satisfies Relic;
