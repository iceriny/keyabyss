import type { CombatSimulation } from "../simulation/CombatSimulation.ts";
import type { OverlayFrame } from "../contracts/overlay-frame.ts";

export function createOverlayFrame(game: CombatSimulation): OverlayFrame {
  const keys = [
    "arena",
    "assaultDirection",
    "state",
    "bossRoom",
    "blasts",
    "bookData",
    "enemies",
    "lasers",
    "options",
    "player",
    "prefix",
    "safePoint",
    "target",
    "visualTime",
    "fx",
    "content",
  ] as const;
  const descriptors: PropertyDescriptorMap = {
    targets: { get: () => game.targets(), enumerable: true },
    elites: { get: () => game.content.elites, enumerable: true },
  };
  for (const key of keys)
    descriptors[key] = { get: () => game[key], enumerable: true };
  return Object.freeze(
    Object.defineProperties({}, descriptors),
  ) as OverlayFrame;
}
