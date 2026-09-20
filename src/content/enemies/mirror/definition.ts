import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "mirror",
  behavior: {
    longWord: true,
    attack: "fan",
    ranged: true,
    mirror: true,
  },
  id: "mirror",
  name: "镜卫",
  hp: 93,
  speed: 28,
  r: 23,
  xp: 11,
  color: "#d5b9f4",
  mass: 1.5,
  tip: "镜盾抵消一次直接攻击的45%伤害，并发射反击。冻结可以绕过镜盾。",
} satisfies EnemyDefinition & { id: string };
