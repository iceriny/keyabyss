import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { roomHealthCost: 1 },
  id: "bloodprice",
  name: "血字契约",
  tag: "诅咒",
  icon: "契",
  desc: "施法伤害提高40%；领取时及之后每进入新的一页损失8生命，同一页只扣一次，不会致死。",
  max: 1,
  rarity: "curse",
  affinity: [],
  damageModifiers: [
    {
      factor: 1.4,
      priority: 20,
    },
  ],
  hooks: [
    {
      phase: "acquire",
      priority: 10,
      effect: {
        kind: "bloodPrice",
      },
    },
  ],
} satisfies Relic;
