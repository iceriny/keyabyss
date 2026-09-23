import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "wirestitch",
  command: "wirestitch",
  name: "导电缝线",
  tag: "传导",
  icon: "wirestitch",
  desc: "每12个人工有效字符供应一份传导，最多缓存3份。人工主术命中后最多传至2个邻敌，总计造成主术40%伤害；每次主术最多使用一份。",
  max: 1,
  grants: { conductionPayload: 1 },
  provides: ["conduction"],
  modifies: ["conduction"],
} satisfies Relic;
