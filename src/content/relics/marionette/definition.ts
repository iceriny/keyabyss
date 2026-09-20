import type { Relic } from "../../../contracts/content.ts";
export default {
  grants: { summonedMark: 1 },
  id: "marionette",
  name: "傀儡纸冠",
  tag: "觉醒",
  icon: "♜",
  desc: "纸灵在飞行中拦截敌弹；击杀标记目标额外获得8点共鸣。",
  max: 1,
  book: "spirit",
  requires: ["ward", "shield"],
  rarity: "awaken",
  affinity: [],
} satisfies Relic;
