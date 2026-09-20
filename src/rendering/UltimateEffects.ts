import { flameTongue } from "./FlameBrush";
import type { VisualEffect } from "../combat/model";
interface UltimateBrush {
  crystal(
    batch: InstancedBatch,
    x: number,
    y: number,
    size: number,
    angle: number,
    color: string,
    alpha: number,
  ): void;
  arc(
    batch: InstancedBatch,
    x: number,
    y: number,
    r: number,
    angle: number,
    length: number,
    color: string,
    alpha: number,
    width: number,
    emission: number,
    ratio?: number,
  ): void;
  effect(effect: VisualEffect): void;
}
import type { InstancedBatch } from "./InstancedBatch";
import type { BurstEffect } from "../combat/model";
const TAU = Math.PI * 2;
type Handler = (
  brush: UltimateBrush,
  fx: InstancedBatch,
  f: BurstEffect,
  r: number,
  alpha: number,
  t: number,
) => void;
export const ultimateEffects: Readonly<Record<string, Handler>> = {
  inferno(brush, fx, f, r, alpha, t) {
    for (let i = 0; i < 18; i++) {
      const angle = (i / 18) * TAU + t * 0.4,
        reach = r * (0.5 + 0.22 * (i % 3));
      flameTongue(
        fx,
        f.x + Math.cos(angle) * reach,
        f.y + Math.sin(angle) * reach,
        32 * alpha + 8,
        t * 8 + i,
        alpha,
        angle + Math.PI / 2,
      );
    }
    brush.arc(
      fx,
      f.x,
      f.y,
      r * 0.7,
      t * 2,
      4.4,
      "#ffbd65",
      alpha * 0.8,
      4,
      1.8,
    );
  },
  crystal(brush, fx, f, r, alpha, t) {
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * TAU,
        reach = r * (i % 2 ? 0.81 : 0.64);
      brush.crystal(
        fx,
        f.x + Math.cos(a) * reach,
        f.y + Math.sin(a) * reach,
        (i % 2 ? 30 : 48) * alpha + 5,
        a + Math.PI / 2,
        f.color,
        alpha,
      );
    }
  },
  orbit(brush, fx, f, r, alpha, t) {
    for (let i = 0; i < 5; i++)
      brush.arc(
        fx,
        f.x,
        f.y,
        r * (0.36 + i * 0.105),
        i * 1.4 + t * 2.1,
        2.2,
        f.color,
        alpha * 0.65,
        2.5,
        1.3,
        0.65,
      );
  },
  lightning(brush, fx, f, r, alpha, t) {
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * TAU,
        x = f.x + Math.cos(a) * r,
        y = f.y + Math.sin(a) * r;
      brush.effect({
        type: "lightning",
        x: f.x + Math.cos(a) * r * 0.65,
        y: f.y + Math.sin(a) * r * 0.65,
        tx: x,
        ty: y,
        width: 1.3,
        color: f.color,
        life: f.life,
        max: f.max,
        seed: i * 39 + f.seed,
      });
    }
  },
};
