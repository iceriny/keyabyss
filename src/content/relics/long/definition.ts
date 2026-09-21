import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "长度至少7的咒文伤害倍率 {cast.long}，清除目标周围105范围子弹；施法伤害 {cast.hit}。", castPreview: true, wordLength: 7 },
  grants: { longWordDamage: 1 },
  id: "long",
  name: "长句回响",
  tag: "重击",
  icon: "long",
  desc: "长度至少 7 的咒文伤害提高 75%，并清除目标周围子弹。",
  max: 2,
  minWordLength: 7,
  affinity: [],
} satisfies Relic;
