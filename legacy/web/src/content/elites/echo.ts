import type { EliteDefinition } from "../../contracts/content.ts";
export default {
  wordPreference: "punctuated",
  health: 1.14,
  echoDelay: 0.48,
  id: "echo",
  name: "回响",
  color: "#d7b4ff",
  tip: "多数攻击会在短暂间隔后追加扇形弹幕。更常使用所选词库中的连字符或撇号词。",
} satisfies EliteDefinition & { id: string };
