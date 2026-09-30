import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "长度不超过4的咒文伤害倍率 {cast.short}，回复0.1次闪避充能；施法伤害 {cast.hit}。", castPreview: true, wordLength: 4 },
  grants: { shortWordDamage: 1 },
  id: "short",
  name: "短咒连珠",
  tag: "快攻",
  icon: "short",
  desc: "长度不超过 4 的咒文伤害提高 60%，并回复少量闪避充能。",
  max: 2,
  maxWordLength: 4,
  affinity: [],
} satisfies Relic;
