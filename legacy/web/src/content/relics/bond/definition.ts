import type { Relic } from "../../../contracts/content.ts";
export default {
  description: { template: "可用制作力量唤醒纸灵，维持效率提高 10%；完词成功补充纸灵攻击时，多维持 1 秒。纸灵攻击与复写共用制作力量。", castPreview: false },
  grants: { summonBond: 1 },
  id: "bond",
  name: "共命书线",
  tag: "纸灵",
  icon: "bond",
  desc: "可用制作力量唤醒纸灵，维持效率提高 10%；完词成功补充纸灵攻击时，多维持 1 秒。",
  max: 2,
  affinity: ["spirit"],
} satisfies Relic;
