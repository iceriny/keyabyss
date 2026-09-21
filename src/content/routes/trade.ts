import type { RouteDefinition } from "../../contracts/content.ts";
export default {
  id: "trade",
  name: "错页商人",
  icon: "trade",
  desc: "支付 15 点生命，选择一件遗物。不会致死。",
  type: "normal",
  hurt: 15,
  relic: true,
  word: "trade",
} satisfies RouteDefinition;
