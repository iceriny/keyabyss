import type { Mode } from "../../contracts/content.ts";
export default {
  id: "nightmare",
  name: "噩梦",
  speed: 1.48,
  spawn: 1.8,
  cap: 14,
  hp: 100,
  window: 0.94,
  baseLen: 7,
  health: 1.28,
  damage: 1.3,
  elite: 0.22,
  dashCD: 5.3,
  iframe: 0.62,
  dashI: 1,
  rank: 3,
} satisfies Mode & { id: string };
