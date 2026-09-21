import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "低生命条件生效时提高施法与纸灵伤害，当前倍率 {sacrifice.damageMultiplier}。 施法伤害 {cast.hit}。", castPreview: true },
  grants: { lowHealthPower: 1 },
  id: "sacrifice",
  name: "背水誓书",
  tag: "风险",
  icon: "sacrifice",
  desc: "生命低于40%时，施法和纸灵伤害提高50%。",
  max: 1,
  affinity: [],
  damageModifiers: [
    {
      factor: 1.5,
      belowHealth: 0.4,
      priority: 40,
    },
  ],
} satisfies Relic;
