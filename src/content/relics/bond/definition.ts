import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { summonBond: 1 },
  id: "bond",
  name: "共命书线",
  tag: "纸灵",
  icon: "bond",
  desc: "纸灵攻击提高30%，每词额外维持2秒；无纸灵时唤醒一只。",
  max: 2,
  affinity: ["spirit"],
} satisfies Relic;
