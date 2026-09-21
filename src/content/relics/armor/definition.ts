import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "受到的伤害倍率 {armor.multiplier}。", castPreview: false },
  grants: { damageArmor: 1 },
  id: "armor",
  name: "硬壳书封",
  tag: "生存",
  icon: "armor",
  desc: "受到的伤害减少 25%。",
  max: 2,
  affinity: [],
} satisfies Relic;
