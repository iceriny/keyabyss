import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "guardseal",
  command: "guardseal",
  name: "护封",
  tag: "防御",
  icon: "guardseal",
  desc: "未释放的承载纸页可消耗自身，拦截一次普通敌弹。防御消耗与正常释放只能兑现一次。",
  max: 1,
  grants: { carrierGuard: 1 },
  needs: ["carrier"],
  provides: ["guard"],
  modifies: ["carrier", "release"],
} satisfies Relic;
