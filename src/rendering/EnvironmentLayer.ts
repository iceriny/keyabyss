import { effectQuality } from "./EffectQuality";
import type { RenderFrame } from "../contracts/render-frame.ts";
import type { InstancedBatch } from "./InstancedBatch";
import type { IUniform } from "three";
import { rgb } from "./palette";
export function drawEnvironment(
  g: RenderFrame,
  decor: InstancedBatch,
  uniforms: Record<string, IUniform>,
  t: number,
  activity: number,
) {
  const b = decor,
    col = g.bookData?.color || "#91d6ee";
  const parallaxX = g.options.reduceMotion ? 0 : (g.player.x - 640) * 0.016,
    parallaxY = g.options.reduceMotion ? 0 : (g.player.y - 400) * 0.012;
  for (
    let i = 0;
    i <
    (g.options.reduceMotion
      ? 0
      : Math.floor(effectQuality(g.options.fx).motes * 0.35));
    i++
  ) {
    const a = i * 2.39996,
      r = 295 + ((i * 73) % 350),
      depth = 0.4 + (i % 7) / 7;
    const x =
      640 +
      Math.cos(a) * r +
      Math.sin(t * 0.11 + i * 1.7) * (12 + depth * 9) +
      parallaxX * depth * 5;
    const y =
      399 +
      Math.sin(a) * r * 0.7 +
      Math.sin(t * 0.16 + i) * 16 * depth +
      parallaxY * depth * 5;
    const pulse = 0.55 + 0.45 * Math.sin(t * 0.45 + i * 2.4);
    const tint = i % 5 ? "#adcac5" : "#c8b78b";
    // A crisp subpixel core with a tight halo; no rectangular paper sprites.
    const size = 0.9 + depth * 0.6;
    b.add(x, y, size, size, tint, 0.32 + pulse * 0.3, 1, 0, 0, 0);
    b.glow(x, y, 2.4 + depth, tint, 0.055 + pulse * 0.04, 0);
  }
  const u = uniforms;
  u.time.value = t;
  u.activity.value = activity;
  u.school.value.copy(rgb(col));
  u.player.value.set(g.player.x, g.player.y);
  u.detail.value = g.options.fx < 0.6 ? 0.65 : g.options.fx < 0.9 ? 0.85 : 1;
}
