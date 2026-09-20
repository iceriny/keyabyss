import { effectQuality } from "./EffectQuality";
import { counterPulse } from './CounterPulse.ts';
import { ultimateEffects } from "./UltimateEffects";
import { MathUtils } from "three";
import type { RenderFrame } from "../contracts/render-frame.ts";
import type { Point, VisualEffect } from "../combat/model";
import { isArcEffect } from "../combat/model";
import type { InstancedBatch } from "./InstancedBatch";
const TAU = Math.PI * 2;
const clamp = (n: number, lo = 0, hi = 1) => MathUtils.clamp(n, lo, hi);
export class SpellBrush {
  constructor(
    private game: RenderFrame,
    private fx: InstancedBatch,
    private warp: InstancedBatch,
  ) {}
  crystal(
    batch: InstancedBatch,
    x: number,
    y: number,
    size: number,
    angle: number,
    color: string,
    alpha: number,
  ) {
    batch.add(x, y, size * 0.42, size, color, alpha * 0.32, 3, angle, 0, 0.65);
    batch.add(
      x,
      y,
      size * 0.12,
      size * 0.85,
      "#e5fbff",
      alpha * 0.85,
      3,
      angle,
      0,
      1.5,
    );
    const dx = Math.sin(angle) * size * 0.4,
      dy = -Math.cos(angle) * size * 0.4;
    batch.line(
      x - dx,
      y - dy,
      x + dx,
      y + dy,
      0.7,
      "#ecffff",
      alpha * 0.65,
      1.6,
    );
  }
  sigil(
    batch: InstancedBatch,
    x: number,
    y: number,
    r: number,
    alpha: number,
    time: number,
  ) {
    const style = {
      ...this.game.bookData.visual,
      color: this.game.bookData.color,
    };
    const rays = style.rays;
    for (let i = 0; i < rays; i++) {
      const a = (i / rays) * TAU + time * 0.12,
        end = a + (TAU / rays) * 0.7;
      this.arc(batch, x, y, r, a, end - a, style.color, alpha * 0.48, 1.2, 0.8);
      const px = x + Math.cos(a) * r,
        py = y + Math.sin(a) * r;
      batch.add(px, py, 5, 10, style.highlight, alpha * 0.8, 3, a, 0, 1.2);
      batch.line(
        px,
        py,
        x + Math.cos(end) * r * 0.65,
        y + Math.sin(end) * r * 0.65,
        0.8,
        style.color,
        alpha * 0.23,
        0.5,
      );
    }
  }
  trail(
    points: Point[] | undefined,
    color: string,
    width: number,
    alpha: number,
  ) {
    if (!points) return;
    for (let i = 1; i < points.length; i++) {
      const a = points[i - 1],
        b = points[i],
        fade = (alpha * i) / points.length;
      this.fx.line(a.x, a.y, b.x, b.y, width * 3, color, fade * 0.15, 1);
      this.fx.line(a.x, a.y, b.x, b.y, width, color, fade, 1.5);
    }
  }
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
    ratio = 1,
  ) {
    const count = Math.max(
      6,
      Math.ceil(
        (Math.abs(length) * r) /
          (20 - effectQuality(this.game.options.fx).layers * 3),
      ),
    );
    for (let i = 0; i < count; i++) {
      const a = angle + (i / count) * length,
        b = angle + ((i + 1) / count) * length;
      batch.line(
        x + Math.cos(a) * r,
        y + Math.sin(a) * r * ratio,
        x + Math.cos(b) * r,
        y + Math.sin(b) * r * ratio,
        width,
        color,
        alpha,
        emission,
      );
    }
  }
  effect(f: VisualEffect) {
    const quality = effectQuality(this.game.options.fx);
    const fx = this.fx,
      alpha = clamp(f.life / f.max),
      t = 1 - alpha;
    if (f.type === "text") return;
    if (f.type === "ring") {
      fx.ring(
        f.x,
        f.y,
        f.r * (0.2 + 0.8 * Math.pow(t, 0.6)),
        f.color,
        alpha,
        2 * alpha + 0.6,
        1,
      );
      return;
    }
    if (isArcEffect(f)) {
      const dx = f.tx - f.x,
        dy = f.ty - f.y,
        d = Math.hypot(dx, dy) || 1,
        n = Math.max(4, Math.ceil(d / 32));
      let x = f.x,
        y = f.y;
      for (let i = 1; i <= n; i++) {
        const jitter =
          i === n
            ? 0
            : Math.sin(i * 127.1 + (f.seed || 7)) * Math.min(17, d * 0.08);
        const tx = f.x + (dx * i) / n - (dy / d) * jitter,
          ty = f.y + (dy * i) / n + (dx / d) * jitter;
        fx.line(x, y, tx, ty, (f.width || 3) * 1.7, f.color, alpha * 0.08, 1);
        fx.line(x, y, tx, ty, f.width || 3, f.color, alpha, 1.6);
        fx.line(
          x,
          y,
          tx,
          ty,
          Math.max(0.8, (f.width || 3) * 0.3),
          "#fff9e9",
          alpha,
          2,
        );
        if (quality.layers > 1 && i < n && i % 2 === 0) {
          const side = i % 4 === 0 ? 1 : -1,
            bx = tx + (dx / n) * 0.45 - (dy / d) * side * 24,
            by = ty + (dy / n) * 0.45 + (dx / d) * side * 24;
          fx.line(tx, ty, bx, by, 1.1, f.color, alpha * 0.65, 1.3);
          fx.line(
            bx,
            by,
            bx + (dx / n) * 0.35 + (dy / d) * side * 9,
            by + (dy / n) * 0.35 - (dx / d) * side * 9,
            0.6,
            "#fff7dc",
            alpha * 0.5,
            1,
          );
        }
        x = tx;
        y = ty;
      }
      fx.glow(f.tx, f.ty, 25, f.color, alpha * 0.7, 1.4);
      return;
    }
    if (f.type === "burst") {
      if (f.kind === 'parry') {
        counterPulse(fx, this.warp, f, quality.layers, this.game.options.reduceMotion);
        return;
      }
      const r = f.r * (0.12 + 0.88 * Math.pow(t, 0.45));
      fx.glow(
        f.x,
        f.y,
        r,
        f.color,
        alpha * (f.kind === "ultimate" ? 0.42 : 0.3),
        1.1,
      );
      fx.glow(
        f.x,
        f.y,
        Math.min(38, r * 0.3),
        "#f6fbff",
        Math.pow(alpha, 4) * 0.8,
        2,
      );
      if (f.kind === "ultimate") {
        this.sigil(fx, f.x, f.y, r * 0.91, alpha, this.game.visualTime);
        ultimateEffects[this.game.bookData.visual.ultimate]?.(
          this,
          fx,
          f,
          r,
          alpha,
          t,
        );
      }
      if (
        [
          "shock",
          "ultimate",
          "electric",
          "implosion",
          "flame",
          "shard",
        ].includes(f.kind)
      ) {
        fx.ring(
          f.x,
          f.y,
          f.kind === "implosion" ? f.r * (0.2 + 0.8 * alpha) : r,
          f.color,
          alpha,
          (f.kind === "ultimate" ? 7 : 3) * alpha + 0.7,
          1.2,
        );
        fx.ring(f.x, f.y, r * 0.73, f.color, alpha * 0.35, 1, 1);
        if (!this.game.options.reduceMotion && this.warp.count < 32)
          this.warp.add(
            f.x,
            f.y,
            f.r * 2.5,
            f.r * 2.5,
            "#ffffff",
            alpha * (f.kind === "ultimate" ? 52 : 25),
            1,
            0,
            r / (f.r * 1.25),
          );
      }
      if (
        quality.layers > 1 &&
        ["shock", "ultimate", "flame", "shard", "electric"].includes(f.kind)
      ) {
        for (let layer = 1; layer < quality.layers; layer++)
          fx.ring(
            f.x,
            f.y,
            r * (1 - layer * 0.16),
            f.color,
            (alpha * 0.45) / layer,
            (4 - layer) * alpha + 0.5,
            1.4,
          );
      }
      const count =
        (f.kind === "shard" ? 5 : f.kind === "ultimate" ? 12 : 4) *
        quality.layers;
      for (let i = 0; i < count; i++) {
        const a = (i / count) * TAU + Math.sin((f.seed || 1) + i) * 0.18,
          length = r * (0.68 + 0.3 * Math.sin(i * 6.7 + (f.seed || 1)));
        const x = f.x + Math.cos(a) * length,
          y = f.y + Math.sin(a) * length;
        if (f.kind === "shard")
          fx.add(
            x,
            y,
            10 * alpha + 2,
            3 * alpha + 1,
            f.color,
            alpha,
            3,
            a,
            0,
            1.4,
          );
        else
          fx.line(
            f.x + Math.cos(a) * length * 0.55,
            f.y + Math.sin(a) * length * 0.55,
            x,
            y,
            2.2 * alpha + 0.5,
            f.color,
            alpha,
            1.5,
          );
      }
      return;
    }
    if (f.type === "slash")
      for (let i = 0; i < 2; i++)
        this.arc(
          fx,
          f.x,
          f.y,
          f.r * (0.3 + 0.7 * Math.pow(t, 0.45)),
          (f.angle || 0) + (i * Math.PI) / 2,
          2.7,
          f.color,
          alpha,
          3 * alpha + 1,
          1.7,
          0.32,
        );
  }
}
