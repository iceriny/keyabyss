import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "scatterfolio",
  command: "scatterfolio",
  name: "散页分发",
  tag: "分发",
  icon: "scatterfolio",
  desc: "将Ⅱ阶复写页装订为散页：每份生成2张纸页，各造成主术25%伤害，同时最多6页。与重印孤页互斥。",
  max: 1,
  grants: { scatterPages: 1 },
  requires: ["copyfolio"],
  requiresLevels: { copyfolio: 2 },
  needs: ["carrier"],
  modifies: ["carrier"],
  excludes: ["heavyfolio"],
} satisfies Relic;
