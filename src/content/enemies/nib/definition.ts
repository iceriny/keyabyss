import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "nib",
  behavior: { attack: "pursue" },
  id: "nib",
  name: "游墨",
  hp: 43,
  speed: 33,
  r: 16,
  xp: 5,
  color: "#91c7b7",
  mass: 0.9,
  tip: "持续追近的轻型单位。短词与击退可以迅速清理。",
} satisfies EnemyDefinition & { id: string };
