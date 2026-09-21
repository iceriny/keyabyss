import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "冻结敌人受到的施法伤害倍率 {frozen.multiplier}；强化冰枪再乘1.25。", castPreview: false },
  grants: { frozenVulnerability: 1 },
  id: "brittle",
  name: "脆裂书页",
  tag: "冰霜",
  icon: "brittle",
  desc: "冻结敌人受到的施法伤害额外提高40%；非冰霜咒典也生效。",
  max: 2,
  affinity: ["frost"],
} satisfies Relic;
