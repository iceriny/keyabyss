import type { BossDefinition } from "../../../contracts/content.ts";
export default {
  id: "ink-colossus",
  name: "吞墨巨像",
  behavior: "ink-colossus",
  appearance: "boss0",
  health: [800, 1050, 1500, 2380, 3370],
  growth: 1.7,
  reinforcement: "ram",
  movementRadius: 95,
  shieldUnits: ["tower"],
  shieldMultiplier: 0.58,
  phases: [
    {
      name: "批注",
      above: 0.67,
      floor: 0.665,
      summons: [],
    },
    {
      name: "重写",
      above: 0.34,
      floor: 0.335,
      summons: [
        { enemy: "guard", x: 370, y: 325 },
        { enemy: "guard", x: 910, y: 325 },
      ],
    },
    {
      name: "终稿",
      above: 0,
      floor: 0,
      summons: [
        { enemy: "tower", x: 380, y: 235 },
        { enemy: "ram", x: 890, y: 335 },
      ],
    },
  ],
} satisfies BossDefinition;
