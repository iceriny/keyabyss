import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { lowHealthPower: 1 },
  id: "sacrifice",
  name: "背水誓书",
  tag: "风险",
  icon: "†",
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
