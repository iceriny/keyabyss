import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "reaper",
  behavior: { attack: "charge", weave: true, chargeSpeed: 600, cooldown: 2.5 },
  id: "reaper",
  name: "断句者",
  hp: 62,
  speed: 53,
  r: 19,
  xp: 12,
  color: "#f0a5c2",
  mass: 0.9,
  tip: "高阶快速突进单位，路径预警后高速斩击。保留闪避或控制来打断。",
} satisfies EnemyDefinition & { id: string };
