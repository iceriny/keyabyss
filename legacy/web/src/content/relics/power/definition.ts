import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "锋利笔尖伤害倍率 {power.damageMultiplier}；施法伤害 {cast.hit}。", castPreview: true },
  grants: { directDamage: 1 },
  id: "power",
  name: "锋利笔尖",
  tag: "基础",
  icon: "power",
  desc: "所有直接施法伤害提高 25%。",
  max: 3,
  affinity: [],
  damageModifiers: [
    {
      factor: 1.25,
      perStack: true,
      priority: 10,
    },
  ],
} satisfies Relic;
