import type { Mode } from "../../contracts/content.ts";
export default {
  id: "apocalypse",
  name: "灭世",
  speed: 1.76,
  spawn: 1.5,
  cap: 17,
  hp: 90,
  window: 0.84,
  baseLen: 8,
  health: 1.44,
  damage: 1.5,
  elite: 0.3,
  dashCD: 5.8,
  iframe: 0.54,
  dashI: 1,
  rank: 4,
} satisfies Mode & { id: string };
