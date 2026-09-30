import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { aimingSlow: 1 },
  id: "slow",
  name: "时间书签",
  tag: "控场",
  icon: "slow",
  desc: "锁定输入时，敌人与子弹移动速度降低 18%。",
  max: 1,
  affinity: [],
} satisfies Relic;
