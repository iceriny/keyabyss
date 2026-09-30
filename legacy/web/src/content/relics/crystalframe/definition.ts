import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "crystalframe",
  command: "crystalframe",
  name: "冰晶书脊",
  tag: "冰结构",
  icon: "crystalframe",
  desc: "每次人工主术携带冰晶结构，基础积寒30。若同时携带火载荷，命中时消耗晶体释放3枚灼热碎片，总计造成主术45%伤害。",
  max: 1,
  grants: { crystalPayload: 1 },
  provides: ["cold"],
  modifies: ["heat"],
} satisfies Relic;
