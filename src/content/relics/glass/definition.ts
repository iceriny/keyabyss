import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "施法与纸灵伤害倍率 {glass.damageMultiplier}；受伤倍率（含护甲）{armor.multiplier}。 施法伤害 {cast.hit}。", castPreview: true },
  grants: { fragileDamage: 1 },
  id: "glass",
  name: "玻璃书封",
  tag: "诅咒",
  icon: "glass",
  desc: "施法与纸灵伤害提高45%，受到的伤害也提高30%。",
  max: 1,
  rarity: "curse",
  affinity: [],
  damageModifiers: [
    {
      factor: 1.45,
      priority: 30,
    },
  ],
} satisfies Relic;
