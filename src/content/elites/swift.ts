import type { EliteDefinition } from "../../contracts/content.ts";
export default {
  health: 1.14,
  speed: 1.22,
  cooldown: 0.74,
  id: "swift",
  name: "迅捷",
  color: "#aaf0d2",
  tip: "移动和攻击节奏更快。",
} satisfies EliteDefinition & { id: string };
