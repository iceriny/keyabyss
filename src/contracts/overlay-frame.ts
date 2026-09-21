import type { RenderFrame } from "./render-frame.ts";
import type { CombatTarget, Point } from "../combat/model.ts";
import type { EliteDefinition } from "./content.ts";

export interface OverlayFrame extends Pick<
  RenderFrame,
  | "arena"
  | "blasts"
  | "bookData"
  | "enemies"
  | "lasers"
  | "options"
  | "player"
  | "prefix"
  | "target"
  | "visualTime"
  | "fx"
  | "content"
> {
  readonly safePoint: Readonly<Point> | null;
  readonly assaultDirection: number;
  readonly state: import("./game.ts").GameState;
  readonly bossRoom: boolean;
  readonly targets: readonly Readonly<CombatTarget>[];
  readonly elites: Readonly<Record<string, EliteDefinition>>;
}
