import {
  add,
  mul,
  when,
  stat,
  input,
} from "../../../content-sdk/value-builders.ts";
import type { ValueDefinitions } from "../../../contracts/values.ts";
export default {
  "fire.radius": add(
    when(input("empowered", "强化施法"), 115, 55),
    mul(25, stat("fireRadius", "坩埚层数")),
  ),
} satisfies ValueDefinitions;
