import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "thermalvault",
  command: "thermalvault",
  name: "余热匣",
  tag: "回收",
  icon: "thermalvault",
  desc: "敌人死亡时回收人工主术尚未结算的灼烧，下一次人工施法自动附加储热。Ⅰ阶回收35%、容量60、每次最多释放30；Ⅱ阶50%、100、50。派生产物不再次回收。",
  max: 2,
  grants: { heatRecovery: 1 },
  provides: ["recovery"],
  modifies: ["heat", "recovery"],
} satisfies Relic;
