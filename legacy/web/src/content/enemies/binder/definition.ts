import type { EnemyDefinition } from "../../../contracts/content.ts";
export default {
  appearance: "binder",
  behavior: {
    spawnLimit: 2,
    attack: "bind",
    attackSequence: ["bind", "laser"],
    ranged: true,
    hasteAura: true,
  },
  id: "binder",
  name: "缚页使",
  hp: 103,
  speed: 21,
  r: 24,
  xp: 13,
  color: "#e6bc8f",
  mass: 1.8,
  tip: "光环内的盟友加速18%。交替发射转弯弹幕与预警射线，击杀后光环消失。",
} satisfies EnemyDefinition & { id: string };
