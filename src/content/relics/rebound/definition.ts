import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "rebound",
  name: "回锋笔套",
  tag: "弹反",
  icon: "◇",
  desc: "弹反冷却缩短 30%：0.70 秒 → 0.49 秒。",
  max: 1,
  affinity: [],
  grants: { parryHaste: 1 },
} satisfies Relic;
