import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "emberink",
  command: "emberink",
  name: "余烬墨",
  tag: "热量",
  icon: "emberink",
  desc: "亲手输入可积攒热量，用来增强法术或加热保存法术的外壳；用掉的热量不能重复使用。",
  max: 1,
  grants: { heatPayload: 1 },
  provides: ["heat"],
  modifies: ["cold", "recovery"],
} satisfies Relic;
