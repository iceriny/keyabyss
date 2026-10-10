import { add, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "burn.duration": add(3, stat("burnDuration", "灼烧延时层数")),
} satisfies ValueDefinitions;
