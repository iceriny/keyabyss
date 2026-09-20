import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { gravityOnHit: 1 },
  id: "gravity",
  name: "引力墨核",
  tag: "控场",
  icon: "⊙",
  desc: "直接施法命中时，牵引附近敌人靠近落点，便于穿透与连锁。",
  max: 1,
  affinity: [],
} satisfies Relic;
