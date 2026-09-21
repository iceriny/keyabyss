import type { RouteDefinition } from "../../contracts/content.ts";
export default {
  id: "rest",
  name: "安静的阅览室",
  icon: "rest",
  desc: "恢复 26 点生命。",
  type: "normal",
  heal: 26,
  word: "rest",
} satisfies RouteDefinition;
