import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { longWordDamage: 1 },
  id: "long",
  name: "长句回响",
  tag: "重击",
  icon: "≡",
  desc: "长度至少 7 的咒文伤害提高 75%，并清除目标周围子弹。",
  max: 2,
  minWordLength: 7,
  affinity: [],
} satisfies Relic;
