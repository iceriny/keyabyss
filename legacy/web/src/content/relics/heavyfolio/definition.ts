import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "heavyfolio",
  command: "monofolio",
  name: "重印孤页",
  tag: "重印",
  icon: "heavyfolio",
  desc: "将Ⅱ阶复写页装订为重印：同时最多1张纸页，每份造成主术70%伤害。与散页分发互斥。",
  max: 1,
  grants: { heavyPages: 1 },
  requires: ["copyfolio"],
  requiresLevels: { copyfolio: 2 },
  needs: ["carrier"],
  modifies: ["carrier"],
  excludes: ["scatterfolio"],
} satisfies Relic;
