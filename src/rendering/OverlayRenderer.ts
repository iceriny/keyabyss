import { clamp } from "../shared/math.ts";
import { layoutWordLabels } from "./WordLabelLayout.ts";
import type { Box, Enemy, Label } from "../combat/model.ts";
import type { OverlayFrame } from "../contracts/overlay-frame.ts";
const W = 1280,
  H = 800,
  TAU = Math.PI * 2;
const dist = (a: { x: number; y: number }, b: { x: number; y: number }) =>
  Math.hypot(a.x - b.x, a.y - b.y);
/** Owns text layout and pointer hit boxes; never changes simulation state. */
export class OverlayRenderer {
  readonly textMetrics = new Map<string, number>();
  labels: Label[] = [];
  castLabel: (Box & { text: string }) | null = null;
  constructor(private readonly frame: OverlayFrame) {}
  hitTest(x: number, y: number): number | undefined {
    for (let i = this.labels.length - 1; i >= 0; i--) {
      const l = this.labels[i];
      if (x >= l.x && x <= l.x + l.w && y >= l.y && y <= l.y + l.h)
        return l.target.id;
    }
    return undefined;
  }
  clear() {
    this.labels = [];
    this.castLabel = null;
  }
  dispose() {
    this.clear();
    this.textMetrics.clear();
  }
  render(ui: CanvasRenderingContext2D) {
    // Only judgement-critical overlays and text use Canvas. Never uploaded to GPU.
    this.drawTelegraphs(ui);
    this.drawLasers(ui);
    this.drawSafe(ui);
    for (const e of this.frame.enemies)
      if (!e.dead) {
        this.drawEnemyStatus(ui, e);
        if (!e.boss && e.hp < e.maxHp) {
          ui.fillStyle = "#162027";
          ui.fillRect(e.x - 14, e.y + e.r + 8, 28, 2);
          ui.fillStyle = "#a9c9b3";
          ui.fillRect(
            e.x - 14,
            e.y + e.r + 8,
            28 * clamp(e.hp / e.maxHp, 0, 1),
            2,
          );
        }
      }
    for (const f of this.frame.fx)
      if (f.type === "text") {
        const alpha = clamp(f.life / f.max, 0, 1),
          t = 1 - alpha;
        ui.save();
        ui.globalAlpha = alpha;
        ui.font = `700 ${f.size * (1 + Math.sin(Math.min(1, t * 5) * Math.PI) * 0.22)}px Consolas,monospace`;
        ui.textAlign = "center";
        ui.lineWidth = 3;
        ui.strokeStyle = "#0a111ce0";
        ui.strokeText(f.text, f.x, f.y - t * 32);
        ui.fillStyle = f.color;
        ui.fillText(f.text, f.x, f.y - t * 32);
        ui.restore();
      }
    this.drawTargetLock(ui);
    this.drawLabels(ui);
    this.drawCastPreview(ui);
  }

  drawSafe(c: CanvasRenderingContext2D) {
    if (!this.frame.safePoint || this.frame.player.dash < 1) return;
    const p = this.frame.safePoint;
    const alpha = 0.5 + 0.1 * Math.sin(this.frame.visualTime * 3);
    c.strokeStyle = `rgba(139,198,183,${alpha})`;
    c.lineWidth = 1;
    c.setLineDash([3, 6]);
    c.beginPath();
    c.arc(p.x, p.y, 18, 0, TAU);
    c.stroke();
    c.setLineDash([]);
  }

  drawLasers(c: CanvasRenderingContext2D) {
    for (const l of this.frame.lasers) {
      if (l.warning <= 0) continue;
      const warning = l.warning > 0,
        a = this.frame.arena;
      c.save();
      c.fillStyle = warning ? "#e6aa9320" : "#efc3b6b0";
      c.strokeStyle = warning ? "#e9b29b88" : "#ffe0bb";
      c.lineWidth = warning ? 1 : 2;
      if (warning) c.setLineDash([8, 9]);
      const half = warning ? l.width : l.width * 0.8;
      c.beginPath();
      if (l.vertical) {
        c.fillRect(l.pos - half, a.t, half * 2, a.b - a.t);
        c.moveTo(l.pos, a.t);
        c.lineTo(l.pos, a.b);
      } else {
        c.fillRect(a.l, l.pos - half, a.r - a.l, half * 2);
        c.moveTo(a.l, l.pos);
        c.lineTo(a.r, l.pos);
      }
      c.stroke();
      c.setLineDash([]);
      if (warning) {
        c.font = "14px monospace";
        c.fillStyle = "#e3ac9d";
        c.textAlign = "center";
        if (l.vertical) c.fillText(l.warning.toFixed(1), l.pos, a.t + 20);
        else c.fillText(l.warning.toFixed(1), a.l + 27, l.pos - 8);
      }
      c.restore();
    }
  }

  textWidth(c: CanvasRenderingContext2D, text: string) {
    const key = c.font + "|" + text;
    let width = this.textMetrics.get(key);
    if (width === undefined) {
      width = c.measureText(text).width;
      if (this.textMetrics.size > 2000) this.textMetrics.clear();
      this.textMetrics.set(key, width);
    }
    return width;
  }

  castPreviewBox(c: CanvasRenderingContext2D) {
    if (!this.frame.prefix) return null;
    c.font = "600 22px Consolas,'DejaVu Sans Mono',monospace";
    const w = this.textWidth(c, this.frame.prefix) + 35,
      h = 36;
    return {
      x: clamp(
        this.frame.player.x - w / 2,
        this.frame.arena.l,
        this.frame.arena.r - w,
      ),
      y: this.frame.player.y - 70,
      w,
      h,
    };
  }

  drawCastPreview(c: CanvasRenderingContext2D) {
    const box = this.castPreviewBox(c);
    this.castLabel = box ? { ...box, text: this.frame.prefix } : null;
    if (!box) return;
    const { x, y, w, h } = box;
    c.save();
    c.fillStyle = "#091420f5";
    c.strokeStyle = this.frame.bookData.color;
    c.lineWidth = 1.5;
    c.shadowColor = this.frame.bookData.color;
    c.shadowBlur = 0;
    c.beginPath();
    c.roundRect(x, y, w, h, 7);
    c.fill();
    c.stroke();
    c.shadowBlur = 0;
    c.beginPath();
    c.moveTo(this.frame.player.x - 4, y + h);
    c.lineTo(this.frame.player.x, y + h + 5);
    c.lineTo(this.frame.player.x + 4, y + h);
    c.fill();
    c.font = "600 22px Consolas,'DejaVu Sans Mono',monospace";
    c.fillStyle = "#f3fbff";
    c.textBaseline = "middle";
    c.textAlign = "left";
    c.fillText(this.frame.prefix, x + 12, y + h / 2);
    if (
      this.frame.options.reduceMotion ||
      Math.sin(this.frame.visualTime * 7) > -0.35
    ) {
      c.fillStyle = this.frame.bookData.color;
      c.fillRect(x + w - 14, y + 9, 2, 18);
    }
    c.restore();
  }

  drawTargetLock(c: CanvasRenderingContext2D) {
    const t = this.frame.target;
    if (!t || t.dead) return;
    const p = this.frame.player,
      motion = this.frame.options.reduceMotion ? 0 : this.frame.visualTime;
    const r = t.r + 19,
      spin = motion * 0.5,
      progress = (this.frame.prefix?.length || 0) / t.word.length;
    c.save();
    c.lineWidth = 1.2;
    c.strokeStyle = "#f9d89570";
    c.setLineDash([3, 9]);
    c.lineDashOffset = -motion * 20;
    c.beginPath();
    c.moveTo(p.x, p.y - 12);
    c.lineTo(t.x, t.y);
    c.stroke();
    c.setLineDash([]);
    c.translate(t.x, t.y);
    c.strokeStyle = "#ffdea0";
    c.lineWidth = 2;
    c.shadowColor = "#ffd77c";
    c.shadowBlur = 0;
    for (let i = 0; i < 4; i++) {
      c.save();
      c.rotate((i * TAU) / 4 + Math.PI / 4);
      c.beginPath();
      c.moveTo(r - 4, -8);
      c.lineTo(r + 2, -8);
      c.lineTo(r + 2, 8);
      c.lineTo(r - 4, 8);
      c.stroke();
      c.restore();
    }
    c.shadowBlur = 0;
    c.strokeStyle = "#f8d28d90";
    c.lineWidth = 1;
    for (let i = 0; i < 3; i++) {
      c.beginPath();
      c.arc(0, 0, r + 7, spin + (i * TAU) / 3, spin + (i * TAU) / 3 + 0.65);
      c.stroke();
    }
    if (progress) {
      c.lineWidth = 3;
      c.strokeStyle = "#aaf2e5";
      c.beginPath();
      c.arc(0, 0, r + 11, -Math.PI / 2, -Math.PI / 2 + TAU * progress);
      c.stroke();
    }
    c.restore();
  }

  drawLabels(c: CanvasRenderingContext2D) {
    const labels = layoutWordLabels(this.frame, (word, font) => {
      c.font = `600 ${font}px Consolas,'DejaVu Sans Mono',monospace`;
      return this.textWidth(c, word);
    });
    this.labels = labels;
    for (const l of labels) {
      const t = l.target,
        locked = this.frame.target === t;
      const col = locked
        ? "#f8e3ab"
        : t.kind === "rune"
          ? "#8bd3b8"
          : t.kind === "ink"
            ? "#d6b474"
            : t.boss
              ? "#dcb7a1"
              : "#adc4c3";
      c.lineWidth = 1;
      c.strokeStyle = locked ? "#d6c68c99" : "#89a9a02e";
      c.beginPath();
      c.moveTo(t.x, t.y);
      c.lineTo(l.x + l.w / 2, l.y + l.h / 2);
      c.stroke();
      c.lineWidth = locked ? 2 : 1;
      c.fillStyle = locked ? "#263c47fa" : "#0a131df5";
      c.strokeStyle = locked ? "#ffe0a1" : t.kind ? "#77b59a70" : "#72928744";
      c.beginPath();
      c.roundRect(l.x, l.y, l.w, l.h, 6);
      c.fill();
      c.stroke();
      c.font = `600 ${l.font}px Consolas,'DejaVu Sans Mono',monospace`;
      c.textAlign = "left";
      c.textBaseline = "middle";
      c.fillStyle = col;
      c.fillText(t.word, l.x + 12, l.y + l.h / 2 + 0.5);
      if (this.frame.prefix && t.word.startsWith(this.frame.prefix)) {
        c.fillStyle = locked ? "#79d5b9" : "#6ba69b";
        c.fillText(this.frame.prefix, l.x + 12, l.y + l.h / 2 + 0.5);
      }
      if (locked) {
        c.fillStyle = "#ffe0a1";
        c.fillRect(l.x + 5, l.y + 5, 3, l.h - 10);
        const textW = this.textWidth(c, this.frame.prefix);
        const nextW = this.textWidth(c, t.word[this.frame.prefix.length] || "");
        c.fillStyle = "#e5c990";
        c.fillRect(l.x + 12 + textW, l.y + l.h - 4, nextW, 1.5);
      }
      c.textBaseline = "alphabetic";
    }
  }

  drawTelegraphs(c: CanvasRenderingContext2D) {
    for (const b of this.frame.blasts) {
      if (b.dead || b.warning <= 0) continue;
      const ratio = clamp(1 - b.warning / b.max, 0, 1);
      c.save();
      c.translate(b.x, b.y);
      c.fillStyle = b.warning > 0 ? "#fc869915" : "#ffc09b55";
      c.beginPath();
      c.arc(0, 0, b.r, 0, TAU);
      c.fill();
      c.lineWidth = 2;
      c.strokeStyle = "#f4a09988";
      c.setLineDash([9, 6]);
      c.stroke();
      c.setLineDash([]);
      c.strokeStyle = "#ffc3a0";
      c.beginPath();
      c.arc(0, 0, b.r, -Math.PI / 2, -Math.PI / 2 + TAU * ratio);
      c.stroke();
      c.fillStyle = "#f8bea8";
      c.font = "15px monospace";
      c.textAlign = "center";
      c.fillText(b.warning > 0 ? "!" : "", 0, 5);
      c.restore();
    }
    for (const e of this.frame.enemies) {
      if (e.dead) continue;
      if (e.windup > 0) {
        const dx = e.aimX - e.x,
          dy = e.aimY - e.y,
          a = Math.atan2(dy, dx),
          length = Math.hypot(dx, dy) + 130;
        c.save();
        c.translate(e.x, e.y);
        c.rotate(a);
        c.fillStyle = "#ffa38618";
        c.fillRect(0, -e.r, length, e.r * 2);
        c.strokeStyle = "#ffb190";
        c.lineWidth = 1.5;
        c.setLineDash([10, 8]);
        c.beginPath();
        c.moveTo(0, 0);
        c.lineTo(length, 0);
        c.stroke();
        c.setLineDash([]);
        c.fillStyle = "#ffc6a4";
        c.beginPath();
        c.moveTo(length, 0);
        c.lineTo(length - 15, -8);
        c.lineTo(length - 15, 8);
        c.closePath();
        c.fill();
        c.restore();
      }
      if (e.type === "binder" && e.grace <= 0) {
        c.strokeStyle = "#ebb69335";
        c.lineWidth = 1;
        c.setLineDash([4, 10]);
        c.beginPath();
        c.arc(e.x, e.y, 220, 0, TAU);
        c.stroke();
        c.setLineDash([]);
        for (const n of this.frame.enemies)
          if (n !== e && !n.dead && dist(n, e) < 220) {
            c.strokeStyle = "#dfaf8265";
            c.beginPath();
            c.moveTo(e.x, e.y);
            c.lineTo(n.x, n.y);
            c.stroke();
          }
      }
      if (e.type === "vortex") {
        c.strokeStyle = "#c29ceb25";
        c.beginPath();
        c.arc(e.x, e.y, 230, 0, TAU);
        c.stroke();
      }
    }
  }

  drawEnemyStatus(c: CanvasRenderingContext2D, e: Readonly<Enemy>) {
    c.save();
    c.translate(e.x, e.y);
    if (e.freeze > 0) {
      c.strokeStyle = "#c5f0ff";
      c.fillStyle = "#9adaff20";
      c.lineWidth = 1.2;
      c.beginPath();
      for (let i = 0; i < 6; i++) {
        const a = (i / 6) * TAU + Math.PI / 6,
          r = e.r + 9;
        i
          ? c.lineTo(Math.cos(a) * r, Math.sin(a) * r)
          : c.moveTo(Math.cos(a) * r, Math.sin(a) * r);
      }
      c.closePath();
      c.fill();
      c.stroke();
    }
    if (e.burn && e.burn.life > 0) {
      c.fillStyle = "#ffd090";
      c.font = "bold 13px Consolas,monospace";
      c.textAlign = "center";
      c.fillText(`灼烧 ${e.burn.stacks}`, 0, e.r + (e.elite ? 44 : 25));
    }
    if (e.conduct > 0) {
      c.fillStyle = "#ffe1a0";
      c.shadowBlur = 0;
      c.shadowColor = "#ffce73";
      for (let i = 0; i < e.conduct; i++) {
        const a = this.frame.visualTime * 1.5 + (i / 3) * TAU;
        c.beginPath();
        c.arc(Math.cos(a) * (e.r + 8), Math.sin(a) * (e.r + 8), 3.5, 0, TAU);
        c.fill();
      }
      c.shadowBlur = 0;
    }
    if (e.mark > 0) {
      c.strokeStyle = "#dbb9ff";
      c.lineWidth = 1.5;
      const s = e.r + 10;
      for (let i = 0; i < 4; i++) {
        c.save();
        c.rotate((i / 4) * TAU + Math.PI / 4);
        c.beginPath();
        c.moveTo(s - 6, -7);
        c.lineTo(s, 0);
        c.lineTo(s - 6, 7);
        c.stroke();
        c.restore();
      }
    }
    if (this.frame.content.enemies[e.type]?.behavior.mirror && e.mirror > 0) {
      c.strokeStyle = "#eed9ff85";
      c.lineWidth = 2;
      c.beginPath();
      c.arc(0, 0, e.r + 11, 0, TAU);
      c.stroke();
    }
    if (e.elite) {
      const data = this.frame.elites[e.elite];
      c.strokeStyle = data.color;
      c.lineWidth = 1.4;
      c.setLineDash([3, 4]);
      c.beginPath();
      c.arc(0, 0, e.r + 7, 0, TAU);
      c.stroke();
      c.setLineDash([]);
      c.font = "14px sans-serif";
      c.textAlign = "center";
      c.fillStyle = data.color;
      c.fillText(data.name, 0, e.r + 27);
    }
    c.restore();
  }
}
