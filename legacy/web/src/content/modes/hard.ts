import type { Mode } from "../../contracts/content.ts";
export default {
  id: "hard",
  name: "深渊",
  speed: 1.22,
  spawn: 2.25,
  cap: 11,
  hp: 110,
  window: 1.08,
  baseLen: 6,
  health: 1.12,
  damage: 1.1,
  elite: 0.14,
  dashCD: 4.8,
  iframe: 0.72,
  dashI: 1,
  rank: 2,
} satisfies Mode & { id: string };
