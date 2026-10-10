import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "ram",
  behavior: {
    contactDamage: 19,
    attack: "charge",
    chargeSpeed: 465,
    cooldown: 3.3,
  },
  id: "ram",
  name: "撞钟兽",
  hp: 91,
  speed: 31,
  r: 24,
  xp: 10,
  color: "#efb082",
  mass: 2.1,
  tip: "橙色路径预警后冲锋。冻结可打断，撞墙后会失衡。",
} satisfies EnemyDefinition & { id: string };
