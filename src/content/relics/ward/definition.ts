import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { castWard: 1 },
  id: "ward",
  name: "护页结界",
  tag: "生存",
  icon: "⬡",
  desc: "每完成5词获得12点护盾，护盾最多60。",
  max: 2,
  affinity: [],
  hooks: [
    {
      phase: "afterCast",
      priority: 20,
      every: 5,
      effect: {
        kind: "shield",
        amount: 12,
        cap: 60,
        color: "#c3aaf1",
      },
    },
  ],
} satisfies Relic;
