import {
  add,
  mul,
  when,
  stat,
  input,
} from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "cold.amount": mul(45, stat("coldStacks", "寒气层数")),
  "cold.duration": when(
    input("boss", "Boss目标"),
    0.8,
    add(1.55, mul(0.45, stat("coldStacks", "寒气层数"))),
  ),
} satisfies ValueDefinitions;
