import type { RouteDefinition } from "../../contracts/content.ts";
export default {
  id: "shelter",
  name: "留白的书房",
  icon: "shelter",
  desc: "获得 22 点护盾，恢复 10 点生命。",
  type: "normal",
  shield: 22,
  heal: 10,
  word: "shelter",
} satisfies RouteDefinition;
