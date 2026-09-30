import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "split",
  behavior: {
    deathSpawns: [
      { enemy: "nib", x: -28, y: 4 },
      { enemy: "nib", x: 28, y: 4 },
    ],
    attack: "pursue",
    deathSplit: true,
  },
  id: "split",
  name: "裂页",
  hp: 76,
  speed: 29,
  r: 22,
  xp: 8,
  color: "#97d0a6",
  mass: 1.2,
  tip: "死亡时分裂成两只带词条的游墨，范围技能可以一并处理。",
} satisfies EnemyDefinition & { id: string };
