import type { Relic } from "../../../contracts/content.ts";
export default {
  id: "swiftbinding",
  command: "swiftbinding",
  name: "速朽装订",
  tag: "承载",
  icon: "swiftbinding",
  desc: "复写页每份成本降至8个人工有效字符，但纸页寿命缩至1秒。正常释放仍需1.8秒；须经防御消耗或遗响才能兑现短命纸页。",
  max: 1,
  grants: { swiftBinding: 1 },
  needs: ["carrier"],
  modifies: ["carrier", "guard", "release"],
} satisfies Relic;
