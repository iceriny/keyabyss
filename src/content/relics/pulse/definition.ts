import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { castPulse: 1 },
  id: "pulse",
  name: "段落终结",
  tag: "爆破",
  icon: "◉",
  desc: "每完成 5 次咒文，释放以自身为中心的清弹冲击波。",
  max: 1,
  affinity: [],
  hooks: [
    {
      phase: "afterCast",
      priority: 30,
      every: 5,
      exclusiveGroup: "cast-pulse",
      effect: {
        kind: "pulse",
        radius: 220,
        damage: 35,
      },
    },
  ],
} satisfies Relic;
