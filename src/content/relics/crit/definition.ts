import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { criticalCadence: 1 },
  id: "crit",
  name: "惊叹号",
  tag: "重击",
  icon: "!",
  desc: "每第 4 次直接施法必定暴击，造成 2 倍伤害。",
  max: 1,
  affinity: [],
} satisfies Relic;
