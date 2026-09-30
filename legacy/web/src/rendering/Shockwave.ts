import type { BurstEffect } from "../combat/model.ts";
import type { InstancedBatch } from "./InstancedBatch.ts";

/** One travelling front shared by the visible ring and the refraction field. */
export function shockwaveProfile(effect: BurstEffect) {
  const t = Math.max(0, Math.min(1, 1 - effect.life / effect.max));
  const inward = effect.kind === "implosion";
  const extent = effect.r * (effect.kind === "parry" ? 1.85 : 1);
  const progress = 1 - (1 - t) ** 1.25;
  const radius =
    extent * (inward ? 0.96 - 0.88 * progress : 0.08 + 0.92 * progress);
  const width = Math.max(8, Math.min(34, extent * 0.12)) * (0.8 + 0.2 * t);
  // Keep displacement proportional to band width to avoid folding/doubled images.
  const envelope = Math.min(1, t / 0.07) * (1 - t) ** 0.65;
  return {
    radius,
    width,
    amplitude: width * 0.21 * envelope * (effect.kind === "flame" ? 0.55 : 1),
    direction: inward ? -1 : 1,
    opacity: envelope,
  };
}

export function addShockwave(
  warp: InstancedBatch,
  x: number,
  y: number,
  wave: ReturnType<typeof shockwaveProfile>,
) {
  const extent = wave.radius + wave.width * 3;
  warp.add(
    x,
    y,
    extent * 2,
    extent * 2,
    "#ffffff",
    wave.amplitude,
    1,
    0,
    wave.radius / extent,
    0,
    [wave.width / extent, wave.direction, 0, 0],
  );
}
