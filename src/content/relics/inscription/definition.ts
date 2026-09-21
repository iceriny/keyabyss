import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "inscription",
  name: "返咒铭文",
  tag: "弹反",
  icon: "inscription",
  desc: "弹反伤害附带咒典效果：冰霜积寒、雷鸣导电、火焰灼烧、纸灵标记并唤醒纸灵。",
  max: 1,
  affinity: [],
  grants: { parryAffinity: 1 },
} satisfies Relic;
