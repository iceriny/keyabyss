import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "mortar",
  behavior: { attack: "bombard", ranged: true },
  id: "mortar",
  name: "墨弹炮手",
  hp: 80,
  speed: 19,
  r: 23,
  xp: 10,
  color: "#dd9a9a",
  mass: 1.6,
  tip: "在你脚下标出爆炸圆。击杀炮手可以解除尚未落下的墨弹。",
} satisfies EnemyDefinition & { id: string };
