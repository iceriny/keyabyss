import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "直接施法造成 {blast.radius} 范围溅射，伤害 {blast.damage}。", castPreview: true },
  grants: { hitExplosion: 1 },
  id: "blast",
  name: "爆墨瓶",
  tag: "爆破",
  icon: "blast",
  desc: "直接施法造成 90 范围溅射，伤害为本次施法的 35%。",
  max: 2,
  affinity: [],
} satisfies Relic;
