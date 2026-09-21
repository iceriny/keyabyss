import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "每第4次直接施法必定暴击；施法伤害 {cast.hit}，暴击 {cast.critical}。", castPreview: true },
  grants: { criticalCadence: 1 },
  id: "crit",
  name: "惊叹号",
  tag: "重击",
  icon: "crit",
  desc: "每第 4 次直接施法必定暴击，造成 2 倍伤害。",
  max: 1,
  affinity: [],
} satisfies Relic;
