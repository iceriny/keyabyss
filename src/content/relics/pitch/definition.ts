import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "pitch",
  name: "松脂印章",
  icon: "♨",
  tag: "火焰",
  book: "flame",
  desc: "灼烧持续时间延长1秒。",
  max: 2,
  grants: {
    burnDuration: 1,
  },
} satisfies Relic;
