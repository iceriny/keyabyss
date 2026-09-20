import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "tower",
  behavior: {
    eliteEligible: false,
    attack: "ring",
    stationary: true,
  },
  id: "tower",
  name: "批注柱",
  hp: 135,
  speed: 0,
  r: 24,
  xp: 13,
  color: "#d1a5dd",
  mass: 99,
  tip: "第三章Boss的护盾源。每座柱子都有词条，存活时Boss减伤55%。",
} satisfies EnemyDefinition & { id: string };
