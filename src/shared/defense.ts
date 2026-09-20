/** Real-time defense timings, independent of difficulty and world slow motion. */
export const DEFENSE = Object.freeze({
  window: 0.24,
  cooldown: 0.7,
  radius: 42,
  damage: 32,
  knockback: 2200,
  pulseRadius: 105,
  pulseKnockback: 1050,
  // Separate force falloff from eligibility so a smaller radius never weakens hits.
  pulseFalloffDistance: 185,
  pushDuration: 1.2,
  slowDuration: 0.52,
  slowHold: 0.06,
  slowScale: 0.06,
  dodgeInvulnerability: 1,
});
/** Exact integral of the hold + smoothstep recovery; independent of frame subdivision. */
export function counterWorldDelta(remaining: number, dt: number) {
  if (remaining <= 0) return dt;
  const duration = DEFENSE.slowDuration,
    hold = DEFENSE.slowHold,
    scale = DEFENSE.slowScale;
  const integral = (t: number) => {
    const u = Math.max(0, Math.min(1, (t - hold) / (duration - hold)));
    return (
      scale * Math.min(t, duration) +
      (1 - scale) * (duration - hold) * (u ** 3 - u ** 4 / 2) +
      Math.max(0, t - duration)
    );
  };
  const start = Math.max(0, duration - remaining);
  return integral(start + dt) - integral(start);
}
export const directionKeys: Readonly<Record<string, string>> = Object.freeze({
  ArrowLeft: "ArrowLeft",
  ArrowUp: "ArrowUp",
  ArrowDown: "ArrowDown",
  ArrowRight: "ArrowRight",
});
export function dodgeDirection(keys: Readonly<Record<string, boolean>>) {
  const held = (direction: string) =>
    Object.keys(keys).some(
      (key) => keys[key] && directionKeys[key] === direction,
    );
  return {
    x: Number(held("ArrowRight")) - Number(held("ArrowLeft")),
    y: Number(held("ArrowDown")) - Number(held("ArrowUp")),
  };
}
