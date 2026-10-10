import values from "./values.ts";
import type { Relic } from "../../../contracts/content.ts";
export default {
  values,
  description: { template: "每层使转为灼烧时的威力保留提高3%，总保留不超过投入威力。", castPreview: false },
  id: "cinder",
  name: "余烬墨水",
  icon: "cinder",
  tag: "火焰",
  book: "flame",
  desc: "每层使转为灼烧时的威力保留提高3%，总保留不超过投入威力。",
  max: 3,
  grants: {
    burnPower: 1,
  },
} satisfies Relic;
