import type { BossDefinition } from "../../../contracts/content.ts";
export default {
  id: "echo-archivist",
  name: "镜页织者",
  behavior: "echo-archivist",
  appearance: "boss1",
  health: [800, 1050, 1500, 2100, 2900],
  growth: 1.7,
  reinforcement: "mirror",
  movementRadius: 180,
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
      summons: [],
    },
  ],
} satisfies BossDefinition;
