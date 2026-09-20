import type { BossDefinition } from "../../../contracts/content.ts";
export default {
  id: "final-editor",
  name: "大校对官",
  behavior: "final-editor",
  appearance: "boss2",
  health: [800, 1050, 1500, 2100, 2900],
  growth: 1.7,
  reinforcement: "priest",
  movementRadius: 95,
  shieldUnits: ["tower"],
  shieldMultiplier: 0.45,
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
      summons: [],
    },
    {
      name: "终稿",
      above: 0,
      floor: 0,
      summons: [
        {
          enemy: "tower",
          x: 350,
          y: 260,
        },
        {
          enemy: "tower",
          x: 930,
          y: 260,
        },
      ],
    },
  ],
} satisfies BossDefinition;
