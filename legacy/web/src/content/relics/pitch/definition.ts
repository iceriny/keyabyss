import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "每层使灼烧延长1秒，同一份伤害多分两次造成；总伤害不变。", castPreview: false },
  id: "pitch",
  name: "松脂印章",
  icon: "pitch",
  tag: "火焰",
  book: "flame",
  desc: "每层使灼烧延长1秒，同一份伤害多分两次造成；总伤害不变。",
  max: 2,
  grants: {
    burnDuration: 1,
  },
} satisfies Relic;
