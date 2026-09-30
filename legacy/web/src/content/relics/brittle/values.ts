import { add, mul, stat } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "frozen.multiplier": add(
    1.18,
    mul(stat("frozenVulnerability", "脆冰层数"), 0.4),
  ),
} satisfies ValueDefinitions;
