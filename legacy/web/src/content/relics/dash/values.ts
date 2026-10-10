import { mul, when, stat, input } from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "dash.cooldown": mul(
    input("dashCD", "难度基础闪避间隔"),
    when(stat("extraDash", "持有闪避遗物"), 0.72, 1),
  ),
} satisfies ValueDefinitions;
