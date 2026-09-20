import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { shortWordDamage: 1 },
  id: "short",
  name: "短咒连珠",
  tag: "快攻",
  icon: "»",
  desc: "长度不超过 4 的咒文伤害提高 60%，并回复少量闪避充能。",
  max: 2,
  maxWordLength: 4,
  affinity: [],
} satisfies Relic;
