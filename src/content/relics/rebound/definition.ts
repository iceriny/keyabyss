import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "弹反冷却 {parry.cooldown} 秒。", castPreview: false },
  id: "rebound",
  name: "回锋笔套",
  tag: "弹反",
  icon: "rebound",
  desc: "弹反冷却缩短 30%：0.70 秒 → 0.49 秒。",
  max: 1,
  affinity: [],
  grants: { parryHaste: 1 },
} satisfies Relic;
