import type { Mode } from "../../contracts/content.ts";
export default {
  id: "normal",
  name: "冒险",
  speed: 0.9,
  spawn: 3.25,
  cap: 8,
  hp: 125,
  window: 1.3,
  baseLen: 5,
  health: 0.9,
  damage: 0.85,
  elite: 0.06,
  dashCD: 4.2,
  iframe: 0.85,
  dashI: 1,
  rank: 1,
} satisfies Mode & { id: string };
