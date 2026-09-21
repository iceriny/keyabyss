import type { RouteDefinition } from "../../contracts/content.ts";
export default {
  id: "forge",
  name: "朱砂工坊",
  icon: "forge",
  desc: "支付 10 点生命，获得 20 点护盾与一件遗物。",
  type: "normal",
  hurt: 10,
  shield: 20,
  relic: true,
  word: "forge",
} satisfies RouteDefinition;
