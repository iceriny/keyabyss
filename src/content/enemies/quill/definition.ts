import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "quill",
  behavior: { attack: "fan", ranged: true },
  id: "quill",
  name: "飞羽射手",
  hp: 65,
  speed: 25,
  r: 19,
  xp: 7,
  color: "#b0b0eb",
  mass: 1,
  tip: "保持距离，发射瞄准扇形弹幕。优先打断蓄力。",
} satisfies EnemyDefinition & { id: string };
