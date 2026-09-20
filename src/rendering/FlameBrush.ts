import type { InstancedBatch } from "./InstancedBatch";
import type { Field, Shot, Enemy } from "../combat/model";
const TAU = Math.PI * 2;
/** Fire uses the shared instanced shader and existing bloom/displacement passes. */
export function flameTongue(
  batch: InstancedBatch,
  x: number,
  y: number,
  size: number,
  phase: number,
  alpha = 1,
  angle = 0,
) {
  batch.glow(x, y, size * 0.85, "#ff6c22", alpha * 0.3, 1.1);
  batch.add(
    x,
    y - size * 0.16,
    size * 0.7,
    size * 1.6,
    "#ff7228",
    alpha * 0.82,
    7,
    angle,
    phase,
    1.4,
  );
  batch.add(
    x,
    y - size * 0.04,
    size * 0.36,
    size * 0.9,
    "#ffdb79",
    alpha,
    7,
    angle,
    phase + 1.2,
    2,
  );
}
export function fireField(
  ground: InstancedBatch,
  fx: InstancedBatch,
  warp: InstancedBatch,
  field: Readonly<Field>,
  time: number,
  fade: number,
  reduced: boolean,
  layers = 3,
) {
  ground.glow(field.x, field.y, field.r, "#ad3820", fade * 0.34, 0.45);
  for (let i = 0; i < 6 * layers; i++) {
    const a = (i / (6 * layers)) * TAU + (field.seed || 0) * 6,
      radius = field.r * (0.28 + 0.6 * (((i * 7) % 13) / 13));
    const size = 14 + 8 * Math.sin(time * 3 + i);
    flameTongue(
      fx,
      field.x + Math.cos(a) * radius,
      field.y + Math.sin(a) * radius * 0.7,
      size,
      time * 4 + i,
      fade * 0.5,
    );
    ground.line(
      field.x + Math.cos(a) * radius * 0.45,
      field.y + Math.sin(a) * radius * 0.45,
      field.x + Math.cos(a) * radius,
      field.y + Math.sin(a) * radius,
      1,
      "#fda14b",
      fade * 0.45,
      0.8,
    );
  }
  if (!reduced)
    warp.add(
      field.x,
      field.y,
      field.r * 2.1,
      field.r * 2.1,
      "#fff",
      fade * (2.1 + Math.sin(time * 3) * 0.6),
      2,
      0,
      time,
    );
}
export function fireProjectile(
  fx: InstancedBatch,
  shot: Readonly<Shot>,
  time: number,
) {
  const size = shot.empowered ? 29 : 17,
    angle = Math.atan2(shot.vy, shot.vx) + Math.PI / 2;
  flameTongue(fx, shot.x, shot.y, size, time * 7 + shot.seed, 1, angle);
  for (let i = 0; i < shot.trail.length; i += 2) {
    const p = shot.trail[i];
    fx.glow(
      p.x,
      p.y,
      (size * (i + 1)) / shot.trail.length,
      "#ff8335",
      0.15 + (0.2 * i) / shot.trail.length,
      1,
    );
  }
}
export function burningEnemy(
  fx: InstancedBatch,
  enemy: Readonly<Enemy>,
  time: number,
) {
  if (!enemy.burn) return;
  for (let i = 0; i < Math.min(5, enemy.burn.stacks); i++) {
    const a = i * 2.4 + enemy.id;
    flameTongue(
      fx,
      enemy.x + Math.cos(a) * enemy.r * 0.75,
      enemy.y + enemy.r * 0.55,
      10 + enemy.burn.stacks * 1.4,
      time * 5 + i,
      0.7,
    );
  }
}
