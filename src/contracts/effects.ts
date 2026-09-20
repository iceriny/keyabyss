import type { Enemy, Point, SpellOptions } from "../combat/model.ts";
export interface EffectSource {
  readonly session: number;
  readonly room: number;
  readonly entity?: number;
}
export type EffectRequest = { source: EffectSource } & (
  | {
      kind: "damage";
      target: Enemy;
      amount: number;
      depth?: number;
      direct?: boolean;
      from?: Point;
    }
  | { kind: "cold"; target: Enemy; amount: number }
  | {
      kind: "projectile";
      from: Point;
      target: Enemy;
      projectile: string;
      damage: number;
      options?: SpellOptions;
    }
  | { kind: "heal"; amount: number }
  | { kind: "spawn"; enemy: string; x?: number; y?: number }
);
