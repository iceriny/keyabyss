import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "priest",
  behavior: {
    targetingPriority: -70,
    spawnLimit: 2,
    attack: "heal",
    ranged: true,
    cooldown: 3.4,
  },
  id: "priest",
  name: "补页祭司",
  hp: 74,
  speed: 24,
  r: 21,
  xp: 12,
  color: "#b1e6bb",
  mass: 0.9,
  tip: "每次施法治疗三名附近盟友，不治疗自己。优先移除这个支援点。",
} satisfies EnemyDefinition & { id: string };
