import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "emberink",
  command: "emberink",
  name: "余烬墨",
  tag: "火载荷",
  icon: "emberink",
  desc: "每12个人工有效字符供应一份火载荷，最多缓存3份。下一次人工主术命中附加灼烧，每次主术最多使用一份。",
  max: 1,
  grants: { heatPayload: 1 },
  provides: ["heat"],
  modifies: ["cold", "recovery"],
} satisfies Relic;
