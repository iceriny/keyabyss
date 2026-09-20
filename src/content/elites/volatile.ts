import type { EliteDefinition } from "../../contracts/content.ts";
export default {
  health: 1.14,
  deathBlast: { radius: 85, warning: 0.95 },
  id: "volatile",
  name: "殉爆",
  color: "#ffa6aa",
  tip: "死亡后留下有预警的爆炸圆，绿色咒印可以解除。",
} satisfies EliteDefinition & { id: string };
