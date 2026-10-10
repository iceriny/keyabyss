import {
  add,
  mul,
  min,
  when,
  stat,
  input,
} from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "cast.combo": add(
    1,
    mul(
      min(input("combo", "连笔"), 10),
      0.025,
      when(stat("comboPower", "持有连笔字帖"), 2, 1),
    ),
  ),
} satisfies ValueDefinitions;
