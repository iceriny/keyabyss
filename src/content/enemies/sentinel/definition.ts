import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "sentinel",
  behavior: {
    longWord: true,
    attack: "ring",
    ranged: true,
  },
  id: "sentinel",
  name: "装订机",
  hp: 112,
  speed: 18,
  r: 26,
  xp: 12,
  color: "#9ebdde",
  mass: 2.4,
  tip: "有规律地发射环形弹幕，环上保留缺口；不要等多圈重叠。",
} satisfies EnemyDefinition & { id: string };
