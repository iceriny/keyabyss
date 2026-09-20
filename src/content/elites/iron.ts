import type { EliteDefinition } from "../../contracts/content.ts";
export default {
  health: 1.35,
  mass: 1.5,
  unfrozenDamage: 0.9,
  id: "iron",
  name: "铁铸",
  color: "#e7bd80",
  tip: "更重，生命增加35%，未冻结时额外减伤10%。",
} satisfies EliteDefinition & { id: string };
