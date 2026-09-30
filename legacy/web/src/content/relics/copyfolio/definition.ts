import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "copyfolio",
  command: "copyfolio",
  name: "复写页",
  tag: "承载",
  icon: "copyfolio",
  desc: "每12个人工有效字符生成一张复写主术的纸页，造成主术35%伤害。纸页1.8秒后寻敌释放，存在5秒；无目标时等待至过期。Ⅰ阶同时最多1页，Ⅱ阶3页。",
  max: 2,
  grants: { copyPages: 1 },
  provides: ["carrier"],
  modifies: ["carrier"],
} satisfies Relic;
