// Compatibility exports for tools and UI; simulation imports the pure modules directly.
export * from "../shared/math.ts";
export * from "../vocabulary/index.ts";
export { BOOKS, MODES, RELICS } from "../content/catalog.ts";
import { modeRegistry, MODES, chapterRegistry } from "../content/catalog.ts";
import { Campaign } from "../simulation/progression/Campaign.ts";
import { difficulty as calculateDifficulty } from "../simulation/progression/difficulty.ts";
import type { Mode } from "../contracts/content.ts";
const campaign = new Campaign(chapterRegistry.list());
export function difficulty(
  mode: Mode | string,
  stage = 0,
  time = 0,
  elite = false,
  position = campaign.at(stage),
) {
  const m =
    typeof mode === "string"
      ? modeRegistry.has(mode)
        ? modeRegistry.get(mode)
        : MODES.normal
      : mode;
  return calculateDifficulty(m, stage, time, elite, position);
}
