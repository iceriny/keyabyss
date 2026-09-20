import type { Mode } from "../../contracts/content.ts";
export default {
  id: "story",
  name: "启程",
  speed: 0.68,
  spawn: 4.3,
  cap: 6,
  hp: 155,
  window: 1.6,
  baseLen: 4,
  health: 0.72,
  damage: 0.55,
  elite: 0.015,
  dashCD: 3.6,
  iframe: 1,
  dashI: 1,
  rank: 0,
} satisfies Mode & { id: string };
