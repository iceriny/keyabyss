import { clearArena, edgeWidth } from "./shared/arena.ts";
import { builtinContent } from "./bootstrap/content.ts";
import { CombatSimulation } from "./simulation/CombatSimulation.ts";
import { Sound } from "./combat/Sound";
import { OverlayRenderer } from "./rendering/OverlayRenderer.ts";
import * as Targeting from "./simulation/targeting/Targeting.ts";
import { createOverlayFrame } from "./application/overlay.ts";
import type { GameEvents } from "./contracts/game.ts";
import type { BattleRenderer } from "./combat/model";
const W = 1280,
  H = 800;
export interface Game {
  dpr: number;
  canvas: HTMLCanvasElement;
  frame: number;
  last: number;
  lastRenderStamp: string;
  lastUI: number;
  onResize: () => void;
  onVisibility: () => void;
  ox: number;
  oy: number;
  scale: number;
  overlay?: HTMLCanvasElement;
  nativeRenderer?: BattleRenderer;
  prepareRenderer: () => Promise<void>;
}
export class Game extends CombatSimulation {
  menuScene: import('./contracts/menu-scene.ts').MenuSceneFrame | null = null;
  private menuTime = 0;
  private lastMenuPaint = 0;
  declare sound: Sound;
  readonly overlayPainter: OverlayRenderer;
  get labels() {
    return this.overlayPainter.labels;
  }
  get castLabel() {
    return this.overlayPainter.castLabel;
  }
  override clickTarget = (x: number, y: number) => {
    Targeting.clickTarget.call(this, x, y, this.overlayPainter.hitTest(x, y));
  };
  constructor(canvas: HTMLCanvasElement, events: GameEvents = {}) {
    super(builtinContent, events, new Sound());
    this.canvas = canvas;
    this.overlayPainter = new OverlayRenderer(createOverlayFrame(this));
    this.last = performance.now();
    this.lastUI = 0;
    this.onResize = () => this.resize();
    window.addEventListener("resize", this.onResize);
    this.onVisibility = () => {
      this.last = performance.now();
      this.renderDirty = true;
      this.sound.update(this.player, this.state, document.hidden);
    };
    document.addEventListener("visibilitychange", this.onVisibility);
    this.resize();
    this.loop = this.loop.bind(this);
    this.frame = requestAnimationFrame(this.loop);
  }
  loop(now: number) {
    this.sound.update(this.player, this.state, document.hidden);
    const delta = Math.min(0.055, (now - this.last) / 1000 || 0);
    this.last = now;
    const paused = ["paused", "upgrade", "route", "result"].includes(
      this.state,
    );
    if (typeof document !== "undefined" && document.hidden) {
      if (!this.destroyed) this.frame = requestAnimationFrame(this.loop);
      return;
    }
    if (!paused && this.state !== "home") this.updateVisual(delta);
    if (this.state === 'home' && this.menuScene && !this.menuScene.reduced) this.menuTime += delta;
    if (this.state === "playing") {
      let remain = delta;
      if (this.hitStop > 0) {
        const stopped = Math.min(remain, this.hitStop);
        remain -= stopped;
        this.hitStop -= stopped;
      }
      while (remain > 0 && this.state === "playing") {
        const step = Math.min(remain, 1 / 90);
        this.update(step);
        remain -= step;
      }
    }
    const stamp = [
      this.state,
      this.options.fx,
      this.options.largeText,
      this.options.reduceMotion,
      this.target?.id,
      this.prefix,
    ].join(":");
    if (
      this.state === "playing" ||
      (this.state === 'home' && this.menuScene && !this.menuScene.reduced &&
        now - this.lastMenuPaint >= (this.options.fx < .5 ? 1000 / 30 : 1000 / 60)) ||
      this.renderDirty ||
      stamp !== this.lastRenderStamp
    ) {
      this.render();
      this.lastMenuPaint = now;
      this.renderDirty = false;
      this.lastRenderStamp = stamp;
    }
    if (now - this.lastUI > 90) {
      this.emit("hud");
      this.lastUI = now;
    }
    if (!this.destroyed) this.frame = requestAnimationFrame(this.loop);
  }

  render() {
    const labelDpr = Math.min(window.devicePixelRatio || 1, 2),
      canvas = this.overlay;
    if (!canvas) return;
    const w = Math.round(innerWidth * labelDpr),
      h = Math.round(innerHeight * labelDpr);
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
    const ui = canvas.getContext("2d");
    if (!ui) return;
    ui.setTransform(1, 0, 0, 1, 0, 0);
    ui.clearRect(0, 0, w, h);
    if (this.state === "home") {
      this.overlayPainter.clear();
      if (this.menuScene) this.nativeRenderer?.renderMenu(this.menuScene, this.menuTime);
      else this.nativeRenderer?.clear();
      return;
    }
    this.nativeRenderer?.render();
    ui.setTransform(
      labelDpr * this.scale,
      0,
      0,
      labelDpr * this.scale,
      this.ox * labelDpr,
      this.oy * labelDpr,
    );
    this.overlayPainter.render(ui);
  }

  resize() {
    this.renderDirty = true;
    this.scale = Math.min(innerWidth / W, innerHeight / H);
    this.ox = (innerWidth - W * this.scale) / 2;
    this.oy = (innerHeight - H * this.scale) / 2;
    this.arena = {
      l: -this.ox / this.scale,
      r: (innerWidth - this.ox) / this.scale,
      t: -this.oy / this.scale,
      b: (innerHeight - this.oy) / this.scale,
    };
    const edge = edgeWidth(this.arena) * this.scale;
    document.documentElement.style.setProperty(
      "--edge-x",
      `${(edge / innerWidth) * 100}%`,
    );
    document.documentElement.style.setProperty(
      "--edge-y",
      `${(edge / innerHeight) * 100}%`,
    );
    const safe = clearArena(this.arena, 32);
    for (const n of this.nodes) {
      n.x = Math.max(safe.l, Math.min(safe.r, n.x));
      n.y = Math.max(safe.t, Math.min(safe.b, n.y));
    }
    if (this.nativeRenderer) this.nativeRenderer.resize();
  }

  invalidate() {
    this.resize();
  }

  destroy() {
    super.destroy();
    cancelAnimationFrame(this.frame);
    window.removeEventListener("resize", this.onResize);
    this.sound.dispose();
    this.events = {};
    if (typeof document !== "undefined")
      document.removeEventListener("visibilitychange", this.onVisibility);
    this.overlayPainter.dispose();
    this.nativeRenderer?.dispose();
  }
}
