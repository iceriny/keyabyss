import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { echoCast: 1 },
  id: "echo",
  name: "双生笔尖",
  tag: "连锁",
  icon: "echo",
  desc: "每第 3 次完词，向另一个敌人复制 65% 伤害法术。",
  max: 1,
  affinity: [],
} satisfies Relic;
