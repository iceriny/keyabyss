import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "mortar",
  behavior: { attack: "bombard", attackSequence: ["bombard", "crossfire"], ranged: true },
  id: "mortar",
  name: "墨弹炮手",
  hp: 80,
  speed: 19,
  r: 23,
  xp: 10,
  color: "#dd9a9a",
  mass: 1.6,
  tip: "交替预警脚下爆区与两侧夹击；夹击中心留有通道。击杀炮手可解除尚未落下的墨弹。",
} satisfies EnemyDefinition & { id: string };
