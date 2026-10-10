import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "guard",
  behavior: {
    longWord: true,
    attack: "fan",
    ranged: true,
    frontArmor: true,
  },
  id: "guard",
  name: "书封卫士",
  hp: 122,
  speed: 21,
  r: 25,
  xp: 10,
  color: "#e2b378",
  mass: 2.6,
  tip: "正面减伤30%。冻结、失衡或纸灵从侧面攻击可瓦解防御。",
} satisfies EnemyDefinition & { id: string };
