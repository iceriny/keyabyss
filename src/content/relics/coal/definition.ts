import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "coal",
  name: "炽炭书封",
  icon: "♨",
  tag: "火焰",
  book: "flame",
  desc: "每次熔爆施法获得5点护盾。",
  max: 2,
  grants: {
    emberShield: 1,
  },
} satisfies Relic;
