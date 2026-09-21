import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { extraHealth: 1 },
  id: "heal",
  name: "生命页签",
  tag: "恢复",
  icon: "heal",
  desc: "最大生命增加 20，并立即回复 30 点生命。",
  max: 2,
  affinity: [],
  hooks: [
    {
      phase: "acquire",
      priority: 10,
      effect: {
        kind: "maxHealth",
        amount: 20,
        heal: 30,
      },
    },
  ],
} satisfies Relic;
