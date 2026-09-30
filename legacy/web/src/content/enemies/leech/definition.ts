import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "leech",
  behavior: {
    chargeDrain: 0.4,
    attack: "pursue",
    weave: true,
  },
  id: "leech",
  name: "噬字虫",
  hp: 47,
  speed: 55,
  r: 15,
  xp: 7,
  color: "#bdd48b",
  mass: 0.65,
  tip: "快速摆动逼近，持续贴身会干扰闪避恢复。短词也必须优先处理。",
} satisfies EnemyDefinition & { id: string };
