import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { execution: 1 },
  id: "execute",
  name: "终止符",
  tag: "重击",
  icon: "■",
  desc: "直接施法处决生命低于18%的普通敌人；对Boss伤害提高15%。",
  max: 1,
  affinity: [],
} satisfies Relic;
