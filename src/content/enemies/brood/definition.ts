import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "brood",
  behavior: {
    dependencies: ["wisp", "nib"],
    spawnLimit: 2,
    attack: "brood",
    ranged: true,
    cooldown: 5,
  },
  id: "brood",
  name: "折页母巢",
  hp: 142,
  speed: 18,
  r: 28,
  xp: 15,
  color: "#b6c786",
  mass: 2.5,
  tip: "持续孵化带词条的小怪。一次最多孵化五只，迅速清除可减轻压力。",
} satisfies EnemyDefinition & { id: string };
