import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "scribe",
  behavior: { attack: "laser", ranged: true },
  id: "scribe",
  name: "划线师",
  hp: 87,
  speed: 23,
  r: 22,
  xp: 10,
  color: "#df9ab6",
  mass: 1.3,
  tip: "沿你的当前位置蓄力激光。击杀源头或绿色咒印可以取消预警。",
} satisfies EnemyDefinition & { id: string };
