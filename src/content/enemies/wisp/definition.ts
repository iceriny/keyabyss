import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "wisp",
  behavior: { attack: "curve", weave: true },
  id: "wisp",
  name: "烛火",
  hp: 39,
  speed: 43,
  r: 13,
  xp: 6,
  color: "#ffb393",
  mass: 0.65,
  tip: "曲线漂移，发射缓慢加速的火弹。轻质量使它容易被撞飞。",
} satisfies EnemyDefinition & { id: string };
