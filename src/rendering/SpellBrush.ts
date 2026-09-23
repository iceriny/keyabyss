import { effectQuality } from "./EffectQuality";
import { smoothPaperTrail } from "../shared/spirit-flight.ts";
import { addShockwave, shockwaveProfile } from "./Shockwave.ts";
import { counterPulse } from "./CounterPulse.ts";
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
    points: readonly Point[] | undefined,
    color: string,
    width: number,
    alpha: number,
    smooth = false,
  ) {
    if (!points) return;
    if (smooth) {
      const reduced = this.game.options.reduceMotion;
      points = smoothPaperTrail(
        reduced ? points.slice(-6) : points,
        reduced ? 12 : 24 + effectQuality(this.game.options.fx).layers * 12,
      );
      if (reduced) alpha *= 0.55;
    }
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
        n = Math.max(4, Math.min(48, Math.ceil(d / 32)));
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
        if (quality.layers > 1 && i < n && i % (this.game.options.reduceMotion ? 4 : 2) === 0) {
          const side = i % 4 === 0 ? 1 : -1,
            reach = Math.min(30, d * 0.14) * (0.7 + 0.3 * Math.sin(i * 3.1 + (f.seed || 7))),
            bx = tx + (dx / n) * 0.45 - (dy / d) * side * reach,
            by = ty + (dy / n) * 0.45 + (dx / d) * side * reach;
          fx.line(tx, ty, bx, by, Math.min(1.1, (f.width || 3) * 0.35), f.color, alpha * 0.55, 1.3);
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
          if (quality.layers > 2 && !this.game.options.reduceMotion && i % 4 === 0)
            fx.line(bx, by, bx + dx / d * 9 - dy / d * side * 7,
              by + dy / d * 9 + dx / d * side * 7, 0.45, f.color, alpha * 0.3, 1);
        }
        x = tx;
        y = ty;
      }
      fx.glow(f.tx, f.ty, 25, f.color, alpha * 0.7, 1.4);
      return;
    }
    if (f.type === "burst") {
      if (f.kind === "parry") {
        counterPulse(
          fx,
          this.warp,
          f,
          quality.layers,
          this.game.options.reduceMotion,
        );
        return;
      }
      const wave = shockwaveProfile(f);
      const refracts = [
        "shock",
        "ultimate",
        "electric",
        "implosion",
        "flame",
        "shard",
      ].includes(f.kind);
      const r = refracts
        ? wave.radius
        : f.r * (0.12 + 0.88 * Math.pow(t, 0.45));
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
      if (refracts) {
        fx.ring(
          f.x,
          f.y,
          r,
          f.color,
          alpha,
          (f.kind === "ultimate" ? 7 : 3) * alpha + 0.7,
          1.2,
        );
        fx.ring(f.x, f.y, r * 0.73, f.color, alpha * 0.35, 1, 1);
        if (!this.game.options.reduceMotion && this.warp.count < 32)
          addShockwave(this.warp, f.x, f.y, wave);
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
      if (f.kind === "shard") {
        const mist = Math.sin(Math.PI * t) * alpha;
        for (let i = 0; i < quality.layers + 1; i++) {
          const angle = (f.seed || 0) + i * 2.4,
            spread = r * (this.game.options.reduceMotion ? 0.12 : 0.28 + t * 0.2);
          fx.add(f.x + Math.cos(angle) * spread, f.y + Math.sin(angle) * spread * 0.65,
            r * 1.4, r * 0.5, f.color, mist * 0.13, 5, angle * 0.15, 0, 0.4);
        }
      }
      for (let i = 0; i < count; i++) {
        const a = (i / count) * TAU + Math.sin((f.seed || 1) + i) * 0.18,
          length = r * (0.68 + 0.3 * Math.sin(i * 6.7 + (f.seed || 1)));
        const x = f.x + Math.cos(a) * length,
          y = f.y + Math.sin(a) * length;
        if (f.kind === "shard") {
          this.crystal(fx, x, y, (9 + (i % 3) * 4) * (0.3 + alpha), a + Math.PI / 2, f.color, alpha);
          if (quality.layers > 1 && i % 2 === 0) {
            const chipRadius = length * 1.18;
            fx.add(f.x + Math.cos(a + 0.13) * chipRadius, f.y + Math.sin(a + 0.13) * chipRadius,
              2, 4 * alpha + 1, "#e3faff", alpha * 0.6, 3, a, 0, 1.1);
          }
        }
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
    if (f.type === "slash" && f.cross) {
      const reduced = this.game.options.reduceMotion;
      const sweep = reduced ? 1 : Math.min(1, t / 0.32);
      const fade = Math.pow(alpha, 1.5);
      fx.glow(f.x, f.y, f.r * 0.55, "#f6ecff", Math.pow(alpha, 4) * 0.65, 1.7);
      for (const side of [-1, 1]) {
        const angle = f.angle + side * Math.PI * 0.24;
        const dx = Math.cos(angle), dy = Math.sin(angle);
        const point = (u: number) => {
          const along = (u * 2 - 1) * f.r;
          const bend = Math.sin(u * Math.PI * 2) * f.r * 0.08 * side;
          return { x: f.x + dx * along - dy * bend, y: f.y + dy * along + dx * bend };
        };
        let previous = point(0);
        for (let i = 1; i <= 18; i++) {
          const u = i / 18 * sweep, next = point(u);
          const width = Math.max(0.4, Math.sin(u * Math.PI) * 5 * fade);
          fx.line(previous.x, previous.y, next.x, next.y, width * 2.8, f.color, fade * 0.22, 1.3);
          fx.line(previous.x, previous.y, next.x, next.y, width, "#fff4ff", fade, 2);
          previous = next;
        }
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
