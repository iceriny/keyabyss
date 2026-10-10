import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "每完成6次咒文获得 {leech.hook.0.amount} 点生命。" },
  grants: { castLeech: 1 },
  id: "leech",
  name: "朱砂印",
  tag: "恢复",
  icon: "leech",
  desc: "每完成 6 次咒文恢复 4 点生命。",
  max: 2,
  affinity: [],
  hooks: [
    {
      phase: "afterCast",
      priority: 10,
      every: 6,
      effect: {
        kind: "heal",
        amount: 4,
      },
    },
  ],
} satisfies Relic;
