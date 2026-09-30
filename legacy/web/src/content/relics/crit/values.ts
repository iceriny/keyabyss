import { mul, ref } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "crit.multiplier": 2,
  "cast.critical": mul(ref("cast.hit"), ref("crit.multiplier")),
} satisfies ValueDefinitions;
