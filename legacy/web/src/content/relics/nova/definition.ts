import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { perfectPulse: 1 },
  id: "nova",
  name: "完美段落",
  tag: "精准",
  icon: "nova",
  desc: "连续完成3次无错字咒文，释放一次半径150的清弹冲击波。",
  max: 1,
  affinity: [],
  hooks: [
    {
      phase: "afterCast",
      priority: 40,
      every: 3,
      counter: "perfectWords",
      perfectOnly: true,
      exclusiveGroup: "cast-pulse",
      effect: {
        kind: "pulse",
        radius: 150,
        damage: 24,
      },
    },
  ],
} satisfies Relic;
