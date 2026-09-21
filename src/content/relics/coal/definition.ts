import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "每次熔爆施法获得 {coal.shield} 点护盾，上限60。", castPreview: false },
  id: "coal",
  name: "炽炭书封",
  icon: "coal",
  tag: "火焰",
  book: "flame",
  desc: "每次熔爆施法获得5点护盾。",
  max: 2,
  grants: {
    emberShield: 1,
  },
} satisfies Relic;
