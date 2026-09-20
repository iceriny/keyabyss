import type { Relic } from "../../../contracts/content.ts";
export default {
  command: "fold",
  grants: { extraDash: 1 },
  id: "dash",
  name: "折叠书页",
  tag: "生存",
  icon: "➜",
  desc: "闪避充能恢复加快 28%，充能上限增加 1。",
  max: 1,
  affinity: [],
  hooks: [
    {
      phase: "acquire",
      priority: 10,
      effect: {
        kind: "dashCharge",
        amount: 1,
      },
    },
  ],
} satisfies Relic;
