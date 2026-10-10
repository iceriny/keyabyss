import type { BurstEffect } from "../combat/model.ts";
import type { InstancedBatch } from "./InstancedBatch.ts";
import { addShockwave, shockwaveProfile } from "./Shockwave.ts";
/** Sharp contact flash -> expanding pressure ring -> separated, fading shards. */
export function counterPulse(
  fx: InstancedBatch,
  warp: InstancedBatch,
  effect: BurstEffect,
  layers: number,
  reduceMotion: boolean,
) {
  const t = 1 - Math.max(0, effect.life / effect.max);
  const fade = (1 - t) ** 1.5;
  const wave = shockwaveProfile(effect);
  const radius = reduceMotion ? 57 : wave.radius;
  const flash = Math.max(0, 1 - t / 0.22);
  fx.glow(effect.x, effect.y, 22 + flash * 18, "#fff9dc", flash * 0.55, 1.7);
  fx.line(
    effect.x - 48 * flash,
    effect.y,
    effect.x + 48 * flash,
    effect.y,
    2 * flash + 0.3,
    "#ffffff",
    flash * 0.7,
    2,
  );
  fx.ring(
    effect.x,
    effect.y,
    radius,
    "#eaffed",
    fade * 0.65,
    1.2 + flash * 2,
    1.3,
  );
  fx.ring(
    effect.x,
    effect.y,
    Math.max(1, radius - wave.width * 1.3),
    "#89e9cd",
    fade * 0.25,
    1.1,
    0.8,
  );
  if (layers > 1) {
    fx.ring(effect.x, effect.y, radius + 2, "#f6d89b", fade * 0.1, 0.7, 0.7);
  }
  const count = 6 + layers * 2;
  for (let i = 0; i < count; i++) {
    const angle = (i / count) * Math.PI * 2 + (effect.seed % 31) * 0.04;
    const reach = radius * (1.03 + (i % 3) * 0.1);
    const length = (reduceMotion ? 6 : 5 + 22 * (1 - t)) * fade;
    const x = effect.x + Math.cos(angle) * reach;
    const y = effect.y + Math.sin(angle) * reach;
    fx.line(
      x,
      y,
      x + Math.cos(angle) * length,
      y + Math.sin(angle) * length,
      1.1,
      i % 2 ? "#c7ffee" : "#ffe5b7",
      fade * 0.85,
      1.8,
    );
    if (layers > 2 && i % 2 === 0)
      fx.add(
        x,
        y,
        2 + 3 * fade,
        6 + 5 * fade,
        "#f5ffe8",
        fade * 0.45,
        3,
        angle,
        0,
        1.4,
      );
  }
  if (!reduceMotion && warp.count < 32) {
    addShockwave(warp, effect.x, effect.y, wave);
  }
}
