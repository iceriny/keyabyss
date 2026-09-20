import { effectQuality } from "./EffectQuality";
import type { RenderFrame } from "../contracts/render-frame.ts";
import type { InstancedBatch } from "./InstancedBatch";
import type { IUniform } from "three";
import { rgb } from "./palette";
const TAU = Math.PI * 2;
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
  for (let ring = 0; ring < 5; ring++) {
    const r = 235 + ring * 74;
    for (let i = 0; i < 42; i++) {
      if ((i + ring * 3) % 11 < 3) continue;
      const a = (i / 42) * TAU + t * 0.004 * (ring % 2 ? 1 : -1),
        end = a + 0.084;
      const cx = 640 + parallaxX * ring,
        cy = 399 + parallaxY * ring;
      const color = (i + ring) % 9 === 0 ? col : "#496977";
      b.line(
        cx + Math.cos(a) * r,
        cy + Math.sin(a) * r * 0.73,
        cx + Math.cos(end) * r,
        cy + Math.sin(end) * r * 0.73,
        ring % 2 ? 1.3 : 0.7,
        color,
        0.16 + ring * 0.026,
        0,
      );
      if (i % 3 === 0)
        b.line(
          cx + Math.cos(a) * (r - 4),
          cy + Math.sin(a) * (r - 4) * 0.73,
          cx + Math.cos(a) * (r + 7),
          cy + Math.sin(a) * (r + 7) * 0.73,
          1,
          color,
          0.36,
          0,
        );
    }
  }
  for (let i = 0; i < effectQuality(g.options.fx).motes; i++) {
    const a = i * 2.39996,
      r = 295 + ((i * 73) % 350),
      depth = 0.4 + (i % 7) / 7;
    const x = 640 + Math.cos(a) * r + parallaxX * depth * 5;
    const y =
      399 +
      Math.sin(a) * r * 0.7 +
      Math.sin(t * 0.2 + i) * 5 * depth +
      parallaxY * depth * 5;
    if (i % 3) {
      b.glow(x, y, 3 + depth * 2, "#88b8c5", 0.16, 0);
      continue;
    }
    const spin = a + Math.sin(t * 0.13 + i) * 0.12;
    b.add(x, y, 8 + depth * 11, 15 + depth * 16, "#395360", 0.4, 4, spin, 0, 0);
    b.line(x - 3, y - 6, x + 5, y + 1, 0.8, "#8da5aa", 0.24, 0);
  }
  // Three quiet geometric strata: opposite orbital directions and depth-dependent drift.
  for (let layer = 0; layer < effectQuality(g.options.fx).layers; layer++) {
    const spacing = 135 + layer * 73;
    const drift = t * (layer % 2 ? -1 : 1) * (1.5 + layer * 0.6);
    for (let i = -2; i < 12; i++) {
      const x = g.arena.l + i * spacing + (drift % spacing);
      const y = 400 + Math.sin(i * 1.8 + layer) * (130 + layer * 35);
      const radius = 34 + layer * 19;
      for (let side = 0; side < 6; side++) {
        const a = (side * TAU) / 6 + layer * 0.22 + t * 0.005 * (layer + 1);
        const z = a + TAU / 6;
        b.line(
          x + Math.cos(a) * radius,
          y + Math.sin(a) * radius,
          x + Math.cos(z) * radius,
          y + Math.sin(z) * radius,
          0.65,
          "#567d89",
          0.065,
          0,
        );
      }
    }
  }
  // Sparse interior reference marks make local displacement perceptible.
  for (let y = g.arena.t + 65; y < g.arena.b; y += 66)
    for (let x = g.arena.l + 45; x < g.arena.r; x += 83) {
      b.line(x - 2, y, x + 2, y, 0.75, "#476773", 0.35, 0);
      if ((x + y) % 3 === 0)
        b.line(x, y - 3, x, y + 3, 0.75, "#476773", 0.25, 0);
    }
  const u = uniforms;
  u.time.value = t;
  u.activity.value = activity;
  u.school.value.copy(rgb(col));
  u.player.value.set(g.player.x, g.player.y);
  u.detail.value = g.options.fx < 0.6 ? 0.65 : 1;
}
