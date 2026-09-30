import { canvasFont } from "../shared/typography.ts";
import type { Book, EnemyDefinition } from "../contracts/content.ts";
import type { RenderFrame } from "../contracts/render-frame.ts";
import type { Enemy, RuneNode, Player } from "../combat/model";
import { MathUtils } from "three";
const { clamp } = MathUtils,
  TAU = Math.PI * 2,
  ENTITY_SCALE = 0.66;
export class ActorPainter {
  prefix = "";
  visualTime = 0;
  chapter = 0;
  book: string = "frost";
  bookData: Book;
  readonly types: Readonly<Record<string, EnemyDefinition>>;
  enemies: Enemy[] = [];
  player: Player;
  constructor(game: RenderFrame) {
    this.player = { ...game.player };
    this.bookData = Object.values(game.content.books)[0];
    this.types = game.content.enemies;
  }

  drawNode(c: CanvasRenderingContext2D, n: RuneNode) {
    c.save();
    c.translate(n.x, n.y + Math.sin(this.visualTime * 2 + n.phase) * 3);
    const color = n.kind === "rune" ? "#86d1b8" : "#dbbd7f";
    c.shadowColor = color;
    c.shadowBlur = 0;
    c.strokeStyle = color;
    c.fillStyle = "#122f32";
    c.lineWidth = 1.5;
    c.rotate(Math.PI / 4);
    c.beginPath();
    c.roundRect(-13, -13, 26, 26, 4);
    c.fill();
    c.stroke();
    c.rotate(-Math.PI / 4);
    c.shadowBlur = 0;
    c.font = canvasFont(17);
    c.textAlign = "center";
    c.textBaseline = "middle";
    c.fillStyle = color;
    c.fillText(n.kind === "rune" ? "↶" : "✦", 0, 0);
    c.globalAlpha = 0.35;
    c.beginPath();
    c.arc(0, 0, 24, -Math.PI / 2, -Math.PI / 2 + TAU * (1 - n.age / n.life));
    c.stroke();
    c.restore();
  }

  drawEnemy(
    c: CanvasRenderingContext2D,
    entity: Enemy,
    colorOverride?: string,
  ) {
    const e = { ...entity, r: entity.r / ENTITY_SCALE };
    const type = this.types[e.type];
    const color = e.boss
      ? "#d7b595"
      : e.freeze > 0
        ? "#a7def4"
        : (colorOverride ?? type?.color ?? "#adcac3");
    c.save();
    c.translate(e.x, e.y);
    c.scale(ENTITY_SCALE, ENTITY_SCALE);
    c.rotate(e.tilt || 0);
    c.scale(1 + (e.squash || 0), 1 - (e.squash || 0) * 0.6);
    c.globalAlpha = e.grace > 0 ? 0.45 + 0.2 * Math.sin(e.age * 5) : 1;
    c.fillStyle = "#0003";
    c.beginPath();
    c.ellipse(0, e.r * 0.8, e.r * 1.1, e.r * 0.35, 0, 0, TAU);
    c.fill();
    if (e.freeze > 0) {
      c.strokeStyle = "#98d6ee66";
      c.lineWidth = 2;
      c.beginPath();
      c.arc(0, 0, e.r + 9, 0, TAU);
      c.stroke();
    }
    c.translate(0, Math.sin(e.age * 1.7 + (e.phase || 0)) * 2);
    c.lineWidth = 1.6;
    c.strokeStyle = color;
    c.fillStyle = e.flash > 0 ? "#e0ecd0" : "#162931";
    c.shadowColor = color;
    c.shadowBlur = 0;
    if (e.boss) {
      this.drawBoss(c, e, color);
    } else if (
      [
        "ram",
        "mortar",
        "priest",
        "binder",
        "mirror",
        "brood",
        "reaper",
        "vortex",
      ].includes(e.type)
    ) {
      this.drawSpecial(c, e, color);
    } else if (e.type === "nib" || e.type === "leech") {
      const r = e.r;
      c.beginPath();
      c.moveTo(0, -r);
      c.bezierCurveTo(r * 1.5, -r * 0.6, r * 0.95, r * 0.75, r * 0.3, r * 0.72);
      c.lineTo(0, r + 4);
      c.lineTo(-r * 0.4, r * 0.7);
      c.bezierCurveTo(-r * 1.4, r * 0.1, -r, -r, 0, -r);
      c.closePath();
      c.fill();
      c.stroke();
      c.shadowBlur = 0;
      c.fillStyle = color;
      c.fillRect(-7, -3, 4, 4);
      c.fillRect(4, -3, 4, 4);
      c.strokeStyle = color;
      c.beginPath();
      c.moveTo(-3, 7);
      c.lineTo(3, 7);
      c.stroke();
    } else if (e.type === "quill") {
      c.beginPath();
      c.moveTo(-30, -13);
      c.lineTo(-11, -6);
      c.lineTo(0, -24);
      c.lineTo(11, -6);
      c.lineTo(30, -13);
      c.lineTo(17, 8);
      c.lineTo(0, 19);
      c.lineTo(-17, 8);
      c.closePath();
      c.fill();
      c.stroke();
      c.beginPath();
      c.moveTo(-10, 3);
      c.lineTo(0, -9);
      c.lineTo(10, 3);
      c.stroke();
      c.fillStyle = color;
      c.fillRect(-4, 2, 8, 3);
    } else if (
      e.type === "guard" ||
      e.type === "sentinel" ||
      e.type === "tower"
    ) {
      const r = e.r;
      c.beginPath();
      c.moveTo(-r * 0.8, -r);
      c.lineTo(r * 0.8, -r);
      c.lineTo(r, r * 0.4);
      c.lineTo(0, r + 7);
      c.lineTo(-r, r * 0.4);
      c.closePath();
      c.fill();
      c.stroke();
      c.strokeStyle = color;
      c.beginPath();
      c.roundRect(-r * 0.55, -r * 0.6, r * 1.1, r * 0.95, 3);
      c.stroke();
      c.fillStyle = color;
      c.fillRect(-10, -4, 5, 4);
      c.fillRect(5, -4, 5, 4);
      if (e.type === "tower") {
        c.beginPath();
        c.moveTo(-8, -r - 7);
        c.lineTo(0, -r - 17);
        c.lineTo(8, -r - 7);
        c.stroke();
      } else {
        c.beginPath();
        c.moveTo(-r - 3, 4);
        c.lineTo(-r - 9, 14);
        c.moveTo(r + 3, 4);
        c.lineTo(r + 9, 14);
        c.stroke();
      }
    } else if (e.type === "split") {
      c.beginPath();
      c.moveTo(-25, -17);
      c.quadraticCurveTo(-12, -21, 0, -12);
      c.quadraticCurveTo(12, -21, 25, -17);
      c.lineTo(23, 15);
      c.quadraticCurveTo(12, 12, 0, 23);
      c.quadraticCurveTo(-12, 12, -23, 15);
      c.closePath();
      c.fill();
      c.stroke();
      c.beginPath();
      c.moveTo(0, -12);
      c.lineTo(-4, 0);
      c.lineTo(4, 8);
      c.lineTo(0, 23);
      c.stroke();
      c.fillStyle = color;
      c.fillRect(-14, -1, 5, 3);
      c.fillRect(9, -1, 5, 3);
    } else if (e.type === "wisp") {
      c.beginPath();
      c.moveTo(0, -25);
      c.bezierCurveTo(-1, -7, 24, -2, 12, 13);
      c.bezierCurveTo(-5, 30, -27, 9, -8, -9);
      c.lineTo(-6, 2);
      c.closePath();
      c.fill();
      c.stroke();
      c.fillStyle = "#e9cfa1";
      c.beginPath();
      c.ellipse(1, 7, 4, 7, 0, 0, TAU);
      c.fill();
    } else {
      c.beginPath();
      c.arc(0, 0, 20, 0, TAU);
      c.fill();
      c.stroke();
      c.beginPath();
      c.moveTo(-27, 15);
      c.lineTo(25, -20);
      c.stroke();
      c.fillStyle = color;
      c.fillRect(-6, -5, 4, 4);
      c.fillRect(4, -5, 4, 4);
    }
    c.shadowBlur = 0;
    if (!e.boss && e.hp < e.maxHp) {
      c.fillStyle = "#162027";
      c.fillRect(-21, e.r + 12, 42, 3);
      c.fillStyle = e.freeze > 0 ? "#a7ddf0" : "#a9c9b3";
      c.fillRect(-21, e.r + 12, 42 * clamp(e.hp / e.maxHp, 0, 1), 3);
    }
    c.restore();
  }

  drawBoss(c: CanvasRenderingContext2D, e: Enemy, color: string) {
    const ch = this.chapter;
    c.save();
    c.rotate(Math.sin(e.age * 0.7) * 0.055);
    c.strokeStyle = color;
    c.fillStyle = e.flash > 0 ? "#dbd5b9" : "#1c2e34";
    if (ch === 0) {
      c.beginPath();
      c.moveTo(-47, -35);
      c.lineTo(-25, -57);
      c.lineTo(0, -48);
      c.lineTo(25, -57);
      c.lineTo(47, -35);
      c.lineTo(57, 27);
      c.lineTo(30, 43);
      c.lineTo(0, 55);
      c.lineTo(-30, 43);
      c.lineTo(-57, 27);
      c.closePath();
      c.fill();
      c.stroke();
      c.beginPath();
      c.roundRect(-29, -25, 58, 54, 9);
      c.stroke();
      c.fillStyle = "#e8ca94";
      c.fillRect(-20, -13, 11, 7);
      c.fillRect(9, -13, 11, 7);
      c.beginPath();
      c.moveTo(-19, 12);
      c.lineTo(19, 12);
      c.lineTo(10, 28);
      c.lineTo(-10, 28);
      c.closePath();
      c.fill();
    } else if (ch === 1) {
      c.save();
      c.rotate(e.age * 0.17);
      for (let i = 0; i < 4; i++) {
        c.rotate(Math.PI / 2);
        c.beginPath();
        c.moveTo(25, -10);
        c.lineTo(63, -33);
        c.lineTo(78, 0);
        c.lineTo(42, 24);
        c.closePath();
        c.fill();
        c.stroke();
      }
      c.restore();
      c.beginPath();
      c.arc(0, 0, 30, 0, TAU);
      c.fill();
      c.stroke();
      c.fillStyle = "#d2b5ed";
      c.beginPath();
      c.ellipse(0, 0, 17, 9, 0, 0, TAU);
      c.fill();
      c.fillStyle = "#162632";
      c.beginPath();
      c.arc(0, 0, 5, 0, TAU);
      c.fill();
    } else {
      c.beginPath();
      c.moveTo(-36, -36);
      c.lineTo(-20, -57);
      c.lineTo(0, -44);
      c.lineTo(20, -57);
      c.lineTo(36, -36);
      c.lineTo(27, 3);
      c.lineTo(51, 51);
      c.lineTo(12, 39);
      c.lineTo(0, 55);
      c.lineTo(-12, 39);
      c.lineTo(-51, 51);
      c.lineTo(-27, 3);
      c.closePath();
      c.fill();
      c.stroke();
      c.fillStyle = "#101f27";
      c.beginPath();
      c.ellipse(0, -14, 23, 22, 0, 0, TAU);
      c.fill();
      c.stroke();
      c.fillStyle = "#e9ca9b";
      c.fillRect(-14, -17, 8, 5);
      c.fillRect(6, -17, 8, 5);
      c.strokeStyle = "#d08d90";
      c.lineWidth = 4;
      c.beginPath();
      c.moveTo(44, 33);
      c.lineTo(67, -50);
      c.stroke();
      c.fillStyle = "#efbda0";
      c.beginPath();
      c.moveTo(63, -46);
      c.lineTo(72, -66);
      c.lineTo(71, -43);
      c.closePath();
      c.fill();
    }
    c.restore();
    if (this.enemies.some((x) => !x.dead && x.type === "tower")) {
      c.strokeStyle = "#bda4d788";
      c.lineWidth = 2;
      c.beginPath();
      c.arc(0, 0, 74, 0, TAU);
      c.stroke();
    }
  }

  drawPlayer(c: CanvasRenderingContext2D) {
    const p = this.player;
    if (!this.bookData) return;
    c.save();
    c.translate(
      p.x - Math.cos(p.lean || 0) * (p.recoil || 0) * 13,
      p.y - Math.sin(p.lean || 0) * (p.recoil || 0) * 13,
    );
    c.scale(ENTITY_SCALE, ENTITY_SCALE);
    const bob = Math.sin(this.visualTime * 2.3) * 2;
    c.fillStyle = "#0004";
    c.beginPath();
    c.ellipse(0, 20, 29, 9, 0, 0, TAU);
    c.fill();
    if (p.invuln > 0) {
      c.globalAlpha = 0.75;
      c.strokeStyle = this.bookData.color;
      c.lineWidth = 2;
      c.beginPath();
      c.arc(0, 0, 35, -this.visualTime * 2, TAU - this.visualTime * 2);
      c.stroke();
    }
    if (p.shield > 0) {
      c.strokeStyle = "#c7ace18a";
      c.lineWidth = 2;
      c.beginPath();
      c.arc(0, 0, 39, 0, TAU);
      c.stroke();
    }
    c.translate(0, bob);
    c.globalAlpha =
      p.invuln > 0 ? 0.7 + 0.3 * Math.sin(this.visualTime * 16) : 1;
    c.strokeStyle = this.bookData.color;
    c.lineWidth = 1.5;
    c.fillStyle =
      this.book === "frost"
        ? "#224754"
        : this.book === "storm"
          ? "#4a3b28"
          : this.bookData.visual.shadow;
    c.shadowColor = this.bookData.color;
    c.shadowBlur = 0;
    c.beginPath();
    c.moveTo(0, -29);
    c.lineTo(18, -14);
    c.lineTo(12, 4);
    c.lineTo(25, 28);
    c.lineTo(0, 21);
    c.lineTo(-24, 28);
    c.lineTo(-12, 4);
    c.lineTo(-18, -14);
    c.closePath();
    c.fill();
    c.stroke();
    c.fillStyle = "#0b1820";
    c.beginPath();
    c.ellipse(0, -9, 11, 12, 0, 0, TAU);
    c.fill();
    c.fillStyle = "#f2dda9";
    c.fillRect(-7, -10, 4, 3);
    c.fillRect(3, -10, 4, 3);
    c.shadowBlur = 0;
    c.strokeStyle = "#e0c492";
    c.lineWidth = 2;
    c.beginPath();
    c.moveTo(27, 21);
    c.lineTo(22, -29);
    c.stroke();
    c.fillStyle = this.bookData.color;
    c.beginPath();
    c.moveTo(22, -37);
    c.lineTo(28, -28);
    c.lineTo(22, -21);
    c.lineTo(16, -28);
    c.closePath();
    c.fill();
    c.restore();
    if (this.prefix) {
      for (let i = 0; i < Math.min(this.prefix.length, 12); i++) {
        const a =
          this.visualTime * 2 + (i / Math.min(this.prefix.length, 12)) * TAU;
        c.fillStyle = this.bookData.color;
        c.shadowColor = this.bookData.color;
        c.shadowBlur = 0;
        c.beginPath();
        c.arc(p.x + Math.cos(a) * 32, p.y - 10 + Math.sin(a) * 27, 2.5, 0, TAU);
        c.fill();
      }
      c.shadowBlur = 0;
    }
  }

  drawSpecial(c: CanvasRenderingContext2D, e: Enemy, color: string) {
    const r = e.r;
    c.lineWidth = 1.8;
    c.strokeStyle = color;
    c.fillStyle = e.flash > 0 ? "#eff1d8" : "#1a2935";
    if (e.type === "ram") {
      c.beginPath();
      c.moveTo(-r, -r * 0.55);
      c.lineTo(-r * 0.4, -r);
      c.lineTo(r * 0.6, -r * 0.6);
      c.lineTo(r, r * 0.25);
      c.lineTo(r * 0.3, r);
      c.lineTo(-r * 0.8, r * 0.75);
      c.closePath();
      c.fill();
      c.stroke();
      c.lineWidth = 3;
      c.beginPath();
      c.moveTo(-r - 8, -r * 0.6);
      c.lineTo(-r - 12, -r - 9);
      c.moveTo(r + 3, -r * 0.6);
      c.lineTo(r + 12, -r - 8);
      c.stroke();
      c.fillStyle = "#ffe2ae";
      c.fillRect(-11, -4, 6, 4);
      c.fillRect(5, -4, 6, 4);
    } else if (e.type === "priest" || e.type === "binder") {
      c.beginPath();
      c.moveTo(0, -r - 8);
      c.lineTo(r * 0.75, -r * 0.35);
      c.lineTo(r * 0.42, r * 0.22);
      c.lineTo(r, r);
      c.lineTo(-r, r);
      c.lineTo(-r * 0.42, r * 0.22);
      c.lineTo(-r * 0.75, -r * 0.35);
      c.closePath();
      c.fill();
      c.stroke();
      c.beginPath();
      c.arc(0, -r - 9, 12, 0, TAU);
      c.stroke();
      c.font = canvasFont(18);
      c.fillStyle = color;
      c.textAlign = "center";
      c.fillText(e.type === "priest" ? "+" : "⌘", 0, 10);
      c.beginPath();
      c.moveTo(-r - 8, 0);
      c.lineTo(-r - 8, r + 8);
      c.stroke();
    } else if (e.type === "mortar") {
      c.beginPath();
      c.roundRect(-r, -r * 0.4, r * 2, r * 1.25, 6);
      c.fill();
      c.stroke();
      c.save();
      c.rotate(-0.5);
      c.beginPath();
      c.rect(-7, -r - 14, 14, r + 12);
      c.fill();
      c.stroke();
      c.restore();
      c.beginPath();
      c.arc(0, 4, 10, 0, TAU);
      c.stroke();
      c.fillStyle = color;
      for (const x of [-20, 20]) {
        c.beginPath();
        c.arc(x, r * 0.8, 6, 0, TAU);
        c.fill();
      }
    } else if (e.type === "mirror") {
      c.rotate(Math.sin(e.age) * 0.1);
      c.beginPath();
      c.moveTo(0, -r - 8);
      c.lineTo(r + 5, 0);
      c.lineTo(0, r + 8);
      c.lineTo(-r - 5, 0);
      c.closePath();
      c.fill();
      c.stroke();
      c.strokeStyle = "#ecddff";
      c.beginPath();
      c.moveTo(-r * 0.4, -2);
      c.lineTo(r * 0.25, -r * 0.45);
      c.moveTo(-r * 0.2, r * 0.5);
      c.lineTo(r * 0.55, -2);
      c.stroke();
    } else if (e.type === "brood") {
      for (let i = 0; i < 3; i++) {
        const x = (i - 1) * 13;
        c.beginPath();
        c.ellipse(x, i % 2 ? -8 : 4, 15, 23, (i - 1) * 0.25, 0, TAU);
        c.fill();
        c.stroke();
      }
      c.fillStyle = color;
      for (let i = 0; i < 3; i++) c.fillRect((i - 1) * 13 - 2, -2, 4, 4);
    } else if (e.type === "reaper") {
      c.beginPath();
      c.moveTo(0, -r - 9);
      c.lineTo(r * 0.8, -r * 0.2);
      c.lineTo(r * 0.4, r);
      c.lineTo(0, r * 0.65);
      c.lineTo(-r * 0.5, r + 4);
      c.lineTo(-r * 0.8, -r * 0.2);
      c.closePath();
      c.fill();
      c.stroke();
      c.beginPath();
      c.moveTo(r + 5, r + 8);
      c.lineTo(r + 4, -r - 11);
      c.quadraticCurveTo(-3, -r - 27, -r - 9, -r - 1);
      c.stroke();
      c.fillStyle = color;
      c.fillRect(-6, -6, 4, 3);
      c.fillRect(3, -6, 4, 3);
    } else if (e.type === "vortex") {
      c.save();
      c.rotate(e.age * 0.8);
      for (let i = 0; i < 4; i++) {
        c.rotate(Math.PI / 2);
        c.beginPath();
        c.moveTo(8, -4);
        c.quadraticCurveTo(r + 10, -r - 3, 0, -r - 10);
        c.quadraticCurveTo(r + 18, -r - 10, r + 6, 8);
        c.closePath();
        c.fill();
        c.stroke();
      }
      c.restore();
      c.fillStyle = "#030611";
      c.beginPath();
      c.arc(0, 0, 11, 0, TAU);
      c.fill();
      c.stroke();
    }
  }
}
