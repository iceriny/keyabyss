import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "vortex",
  behavior: {
    longWord: true,
    spawnLimit: 2,
    attack: "vortex",
    ranged: true,
    pullAura: true,
    deathVortex: true,
  },
  id: "vortex",
  name: "噬墨之眼",
  hp: 134,
  speed: 17,
  r: 27,
  xp: 15,
  color: "#ba9dea",
  mass: 2,
  tip: "靠近会受到引力牵引。死亡向内拉扯敌人，利用它组织一轮连锁。",
} satisfies EnemyDefinition & { id: string };
