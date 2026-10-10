import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { directConduction: 1 },
  id: "stormcell",
  name: "避雷印",
  tag: "雷鸣",
  icon: "stormcell",
  desc: "过载爆炸会清除半径135内的敌弹；非雷鸣咒典命中也积累导电。",
  max: 1,
  affinity: ["storm"],
} satisfies Relic;
