import { mul, input } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "echo.damage": mul(input("castBase", "施法基值"), 0.65),
} satisfies ValueDefinitions;
