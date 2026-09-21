import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { perfectDamage: 1 },
  id: "perfect",
  name: "无瑕落款",
  tag: "精准",
  icon: "perfect",
  desc: "本次咒文没有错字时，获得额外 35% 伤害。",
  max: 2,
  affinity: [],
} satisfies Relic;
