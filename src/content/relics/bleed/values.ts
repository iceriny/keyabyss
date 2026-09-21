import { mul, stat, input } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "bleed.damage": mul(
    8,
    stat("bleedStacks", "腐蚀遗物层数"),
    input("dotStacks", "腐蚀状态层数"),
  ),
} satisfies ValueDefinitions;
