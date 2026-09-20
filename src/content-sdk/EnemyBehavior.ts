import type { Enemy, Point, Player, BulletOptions } from "../combat/model.ts";
import type { Mode } from "../contracts/content.ts";
export interface EnemyActionContext {
  readonly player: Player;
  readonly enemies: readonly Enemy[];
  readonly chapter: number;
  readonly mode: Mode;
  readonly pressure: { warning: number; attack: number };
  rng(): number;
  fire(enemy: Enemy, pattern?: string, options?: BulletOptions): void;
  laser(enemy: Enemy | null, boss?: boolean): void;
  makeBlast(
    x: number,
    y: number,
    r: number,
    warning?: number,
    source?: number | null,
    ring?: boolean,
  ): void;
  spawnEnemy(
    type?: string,
    x?: number,
    y?: number,
    small?: boolean,
    force?: boolean,
  ): Enemy | null;
  arc(
    from: Point,
    to: Point,
    color: string,
    width?: number,
    life?: number,
  ): void;
  ring(x: number, y: number, r: number, color: string, life?: number): void;
  schedule(delay: number, task: () => void, source?: number | null): void;
}
export type EnemyAction = (context: EnemyActionContext, enemy: Enemy) => void;
