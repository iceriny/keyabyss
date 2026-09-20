import type { EliteDefinition } from "../../contracts/content.ts";
export default {
  health: 1.14,
  echoDelay: 0.48,
  id: "echo",
  name: "回响",
  color: "#d7b4ff",
  tip: "多数攻击会在短暂间隔后追加一轮扇形弹幕。",
} satisfies EliteDefinition & { id: string };
