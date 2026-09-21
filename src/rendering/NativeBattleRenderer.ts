import { edgeWidth } from "../shared/arena.ts";
import { effectQuality } from "./EffectQuality";
import { MenuScene } from "./MenuScene.ts";
import { fireField, fireProjectile, burningEnemy } from "./FlameBrush";
import * as THREE from "three";
import type {
  RenderFrame,
  PresentationPort,
} from "../contracts/render-frame.ts";
import { SpellBrush } from "./SpellBrush";
import { drawEnvironment } from "./EnvironmentLayer";
import { BloomLayer } from "./BloomLayer";
import { ParticleLayer } from "./ParticleLayer";
import { InstancedBatch } from "./InstancedBatch";
import { createAtlas } from "./ActorAtlas";
import { screen, target } from "./ScreenPass";
import {
  displacementFragment,
  environmentFragment,
  compositeFragment,
} from "./shaders";
const TAU = Math.PI * 2;
const clamp = (n: number, lo = 0, hi = 1) => THREE.MathUtils.clamp(n, lo, hi);
export class NativeBattleRenderer {
  readonly menu = new MenuScene();
  game: RenderFrame;
  renderer: THREE.WebGLRenderer;
  atlas: ReturnType<typeof createAtlas>;
  camera: THREE.OrthographicCamera;
  screenCamera: THREE.Camera;
  environmentTarget: THREE.WebGLRenderTarget;
  actorTarget: THREE.WebGLRenderTarget;
  displacementTarget: THREE.WebGLRenderTarget;
  glowTarget: THREE.WebGLRenderTarget;
  bloom: BloomLayer;
  particles: ParticleLayer;
  brush: SpellBrush;
  targets: THREE.WebGLRenderTarget[];
  world: THREE.Scene;
  environmentScene: THREE.Scene;
  displacementScene: THREE.Scene;
  decor: InstancedBatch;
  ground: InstancedBatch;
  actors: InstancedBatch;
  actorPages: InstancedBatch[];
  readonly spriteRuns: InstancedBatch[] = [];
  spriteRunIndex = -1;
  spritePage = -1;
  atlasInstances: number[] = [];
  effects: InstancedBatch;
  warp: InstancedBatch;
  batches: InstancedBatch[];
  environment: ReturnType<typeof screen>;
  composite: ReturnType<typeof screen>;
  passes: ReturnType<typeof screen>[];
  lost = false;
  ready = false;
  disposed = false;
  width = 1;
  height = 1;
  mediumWidth = 1;
  mediumHeight = 1;
  onLost: (event: Event) => void;
  onRestored: () => void;

  readonly port: PresentationPort;
  constructor(canvas: HTMLCanvasElement, port: PresentationPort) {
    this.port = port;
    const game = port.frame;
    this.game = game;
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: false,
      powerPreference: "high-performance",
    });
    this.renderer.setPixelRatio(1);
    this.renderer.autoClear = true;
    this.renderer.info.autoReset = false;
    this.atlas = createAtlas(game, this.renderer.capabilities.maxTextureSize);
    this.camera = new THREE.OrthographicCamera(0, 1280, 0, 800, -10, 10);
    this.screenCamera = new THREE.Camera();
    const precision = this.renderer.extensions.has("EXT_color_buffer_float")
      ? THREE.HalfFloatType
      : THREE.UnsignedByteType;
    this.environmentTarget = target(precision);
    this.actorTarget = target(precision);
    this.displacementTarget = target(precision);
    this.glowTarget = target(precision);
    this.bloom = new BloomLayer(this.renderer, precision);
    this.particles = new ParticleLayer();
    this.targets = [
      this.environmentTarget,
      this.actorTarget,
      this.displacementTarget,
      this.glowTarget,
    ];
    this.world = new THREE.Scene();
    this.environmentScene = new THREE.Scene();
    this.displacementScene = new THREE.Scene();
    this.decor = new InstancedBatch(this.atlas.texture, 1600);
    this.ground = new InstancedBatch(this.atlas.texture, 4096);
    this.actorPages = this.atlas.pages.map(
      (texture) => new InstancedBatch(texture, 700),
    );
    this.actors = this.actorPages[0];
    // Preserve transparent sprite order across page/material switches. Runs share prewarmed materials.
    if (this.actorPages.length > 1)
      for (let i = 0; i < 700; i++) {
        const batch = new InstancedBatch(this.atlas.texture, 32);
        batch.material.dispose();
        batch.ownsMaterial = false;
        batch.material = this.actorPages[0].material;
        batch.mesh.material = batch.material;
        batch.mesh.renderOrder = 1 + (i + 1) / 1000;
        this.spriteRuns.push(batch);
      }

    this.effects = new InstancedBatch(this.atlas.texture, 16384);
    this.warp = new InstancedBatch(
      this.atlas.texture,
      32,
      displacementFragment,
    );
    this.warp.material.blending = THREE.CustomBlending;
    this.warp.material.blendSrc = THREE.OneFactor;
    this.warp.material.blendDst = THREE.OneFactor;
    this.warp.material.blendEquation = THREE.AddEquation;
    this.displacementScene.add(this.warp.mesh);
    this.world.add(
      this.ground.mesh,
      ...this.actorPages.map((page) => page.mesh),
      ...this.spriteRuns.map((batch) => batch.mesh),
      this.effects.mesh,
      this.particles.object,
    );
    this.brush = new SpellBrush(game, this.effects, this.warp);
    this.ground.mesh.renderOrder = 0;
    for (const page of this.actorPages) page.mesh.renderOrder = 1;
    this.effects.mesh.renderOrder = 2;
    this.batches = [
      this.decor,
      this.ground,
      ...this.actorPages,
      ...this.spriteRuns,
      this.effects,
      this.warp,
    ];
    const environment = screen(environmentFragment, {
      worldSpan: { value: new THREE.Vector2() },
      worldOrigin: { value: new THREE.Vector2() },
      player: { value: new THREE.Vector2(640, 400) },
      school: { value: new THREE.Color("#91d6ee") },
      time: { value: 0 },
      activity: { value: 0 },
      detail: { value: 1 },
      presence: { value: 1 },
    });
    this.environment = environment;
    this.environmentScene.add(this.decor.mesh);
    this.composite = screen(compositeFragment, {
      environment: { value: this.environmentTarget.texture },
      actors: { value: this.actorTarget.texture },
      displacement: { value: this.displacementTarget.texture },
      bloom: { value: this.bloom.texture },
      bloomStrength: { value: 1 },
      hitFlash: { value: 0 },
      warpStrength: { value: 1 },
      worldSpan: { value: new THREE.Vector2(1280, 800) },
    });
    this.passes = [environment, this.composite];
    this.lost = false;
    this.onLost = (event: Event) => {
      event.preventDefault();
      this.lost = true;
      port.contextLost();
    };
    this.onRestored = () => {
      this.lost = false;
      this.ready = false;
      void this.prepare()
        .then(() => port.contextRestored())
        .catch(() => port.contextRestoreFailed());
    };
    canvas.addEventListener("webglcontextlost", this.onLost);
    canvas.addEventListener("webglcontextrestored", this.onRestored);
    this.resize();
  }

  resize() {
    const g = this.game;
    // 1080P pixel budget independent of DPR; UI text retains its own DPR.
    const density = Math.min(
      window.devicePixelRatio || 1,
      1920 / innerWidth,
      1080 / innerHeight,
    );
    const w = Math.max(1, Math.round(innerWidth * density)),
      h = Math.max(1, Math.round(innerHeight * density));
    const quality = effectQuality(g.options.fx).scale;
    const mw = Math.max(1, Math.round(w * quality)),
      mh = Math.max(1, Math.round(h * quality));
    this.renderer.setSize(w, h, false);
    this.environmentTarget.setSize(w, h);
    this.actorTarget.setSize(w, h);
    for (const t of [this.displacementTarget, this.glowTarget])
      t.setSize(mw, mh);
    this.bloom.resize(mw, mh);
    this.width = w;
    this.height = h;
    this.mediumWidth = mw;
    this.mediumHeight = mh;
    this.port.setDensity(density);
    const left = -g.ox / g.scale,
      top = -g.oy / g.scale,
      spanX = innerWidth / g.scale,
      spanY = innerHeight / g.scale;
    Object.assign(this.camera, {
      left,
      right: left + spanX,
      top,
      bottom: top + spanY,
    });
    this.camera.updateProjectionMatrix();
    this.environment.material.uniforms.worldSpan.value.set(spanX, spanY);
    this.environment.material.uniforms.worldOrigin.value.set(left, top);
    this.warp.material.uniforms.worldSpan.value.set(spanX, spanY);
    this.composite.material.uniforms.worldSpan.value.set(spanX, spanY);
  }

  async prepare() {
    if (this.ready) return;
    for (const texture of this.atlas.pages) this.renderer.initTexture(texture);
    for (const t of this.targets) this.renderer.initRenderTarget(t);
    for (const scene of [
      this.world,
      this.environment.scene,
      this.environmentScene,
      this.displacementScene,
      this.composite.scene,
      this.menu.scene,
    ]) {
      if (this.disposed) return;
      await this.renderer.compileAsync(
        scene,
        scene === this.world ||
          scene === this.environmentScene ||
          scene === this.displacementScene
          ? this.camera
          : scene === this.menu.scene
            ? this.menu.camera
            : this.screenCamera,
      );
    }
    if (this.disposed) return;
    // Exercise every material and render target while the loading screen is up.
    this.render();
    this.clear();
    this.ready = true;
  }

  populate() {
    const g = this.game,
      p = g.player,
      col = g.bookData?.color || "#91d6ee";
    const t = g.options.reduceMotion ? 0 : g.visualTime;
    const charge = g.target
      ? clamp((g.prefix?.length || 0) / g.target.word.length)
      : 0;
    const ultimate = g.ultimateTime > 0 ? 1 : 0;
    const activity = 0.14 + charge * 0.65 + ultimate * 0.85;
    for (const b of this.batches) b.reset();
    this.spriteRunIndex = -1;
    this.spritePage = -1;
    this.atlasInstances.fill(0);
    drawEnvironment(
      g,
      this.decor,
      this.environment.material.uniforms,
      t,
      activity,
    );
    const ground = this.ground,
      actors = this.actors,
      fx = this.effects;
    for (const d of g.decals)
      ground.add(
        d.x,
        d.y,
        d.r * 3,
        d.r * 1.3,
        d.color,
        Math.min(1, d.life / 3) * 0.1,
        5,
      );
    for (const f of g.fields) {
      const fade = clamp(Math.min(f.life / 0.5, f.age / 0.2));
      const color =
        f.kind === "fire"
          ? "#ff994e"
          : f.kind === "frost"
            ? "#8cdeff"
            : f.kind === "storm"
              ? "#f4d187"
              : "#b19bfa";
      ground.glow(f.x, f.y, f.r * 1.15, color, fade * 0.18, 0.5);
      ground.ring(f.x, f.y, f.r, color, fade * 0.35, 1.3, 0.5);
      if (f.kind === "fire")
        fireField(
          ground,
          fx,
          this.warp,
          f,
          t,
          fade,
          g.options.reduceMotion,
          effectQuality(g.options.fx).layers,
          g.fields,
        );
      else if (f.kind === "gravity") {
        if (!g.options.reduceMotion)
          this.warp.add(
            f.x,
            f.y,
            f.r * 2.6,
            f.r * 2.6,
            "#ffffff",
            fade * (f.ultimate ? 30 : 21),
            0,
          );
        for (let i = 0; i < 3; i++)
          this.brush.arc(
            ground,
            f.x,
            f.y,
            f.r * (0.36 + i * 0.21),
            t * 0.4 + i * 2,
            4.6,
            color,
            fade * 0.4,
            1.7,
            0.8,
            0.72,
          );
        ground.glow(f.x, f.y, f.r * 0.3, "#080d1e", fade * 0.75, 0);
      } else if (f.kind === "frost") {
        for (let i = 0; i < 4 * effectQuality(g.options.fx).layers; i++) {
          const a = (i / 12) * TAU + (f.seed || 0);
          this.brush.crystal(
            ground,
            f.x + Math.cos(a) * f.r * 0.82,
            f.y + Math.sin(a) * f.r * 0.82,
            10 + (i % 3) * 7,
            a + Math.PI / 2,
            color,
            fade * 0.62,
          );
        }
        for (let i = 0; i < 6; i++) {
          const a = (i / 6) * TAU,
            dx = Math.cos(a),
            dy = Math.sin(a);
          ground.line(
            f.x,
            f.y,
            f.x + dx * f.r * 0.72,
            f.y + dy * f.r * 0.72,
            1,
            color,
            fade * 0.22,
            0.4,
          );
          for (let k = 1; k < 4; k++)
            for (const sign of [-1, 1]) {
              const x = f.x + dx * f.r * k * 0.18,
                y = f.y + dy * f.r * k * 0.18;
              ground.line(
                x,
                y,
                x - dx * 12 - dy * sign * 12,
                y - dy * 12 + dx * sign * 12,
                1,
                color,
                fade * 0.3,
                0.5,
              );
            }
        }
      } else
        for (let i = 0; i < 3; i++)
          this.brush.arc(
            ground,
            f.x,
            f.y,
            f.r * 0.76,
            t * 0.5 + (i * TAU) / 3,
            1.3,
            color,
            fade * 0.7,
            2,
            1,
          );
    }
    for (const tr of g.trails)
      actors.add(
        tr.x,
        tr.y,
        28,
        36,
        col,
        (tr.life / tr.max) * 0.24,
        3,
        (tr.angle || 0) + Math.PI / 2,
        0,
        0.3,
      );
    for (const d of g.corpses) {
      ground.add(
        d.x,
        d.y,
        d.r * 2,
        d.r * 0.7,
        "#000000",
        clamp(d.life / 0.6) * 0.25,
        1,
      );
      actors.add(
        d.x,
        d.y - d.z,
        d.r * 2,
        d.r * 1.2,
        d.ice ? d.color : "#55717c",
        clamp(d.life / 0.6) * 0.8,
        3,
        d.angle,
        0,
        0.15,
      );
    }
    if (g.decoy && g.decoy.life > 0)
      this.sprite(
        "player-spirit",
        g.decoy.x,
        g.decoy.y,
        128,
        128,
        0,
        clamp(g.decoy.life * 0.28),
        0.5,
      );
    for (const n of g.nodes)
      if (!n.dead) {
        const y = n.y + Math.sin(t * 2 + n.phase) * 3;
        const color = n.kind === "rune" ? "#86ffd5" : "#ffc76f";
        const sides = n.kind === "rune" ? 6 : 4;
        ground.glow(n.x, y, 23, color, 0.15, 0.4);
        actors.add(n.x, y, 21, 21, "#112d2a", 0.95, 3);
        for (let i = 0; i < sides; i++) {
          const a = (i * TAU) / sides - Math.PI / 2,
            b = ((i + 1) * TAU) / sides - Math.PI / 2;
          fx.line(
            n.x + Math.cos(a) * 16,
            y + Math.sin(a) * 16,
            n.x + Math.cos(b) * 16,
            y + Math.sin(b) * 16,
            1.8,
            color,
            0.9,
            1,
          );
        }
        fx.add(n.x, y, 7, 7, color, 0.9, 3, 0, 0, 1.2);
        this.brush.arc(
          ground,
          n.x,
          y,
          24,
          -Math.PI / 2,
          TAU * clamp(1 - n.age / n.life),
          n.kind === "rune" ? "#86d1b8" : "#dbbd7f",
          0.45,
          1,
          0.4,
        );
      }
    // Draw order uses entity y without mutating the simulation array.
    for (const e of [...g.enemies].sort((a, b) => a.y - b.y))
      if (!e.dead) {
        const edgeDistance = Math.min(e.x - g.arena.l, g.arena.r - e.x, e.y - g.arena.t, g.arena.b - e.y);
        const clarity = clamp((edgeDistance - e.r) / edgeWidth(g.arena));
        const visibility = e.combatLocked ? 1 : 0.06 + 0.94 * clarity * clarity;
        const alpha = visibility * (e.grace > 0 ? 0.45 + 0.2 * Math.sin(e.age * 5) : 1),
          size = 128;
        this.sprite(
          e.boss
            ? g.content.bosses[
                e.bossId ?? g.content.chapters[g.chapter].bossId!
              ].appearance
            : g.content.enemies[e.type].appearance,
          e.x,
          e.y + Math.sin(t * 1.7 + (e.phase || 0)) * 1.3,
          size * (1 + (e.squash || 0)),
          size * (1 - (e.squash || 0) * 0.6),
          e.tilt || 0,
          alpha,
          e.flash > 0 ? 2 : 0.12,
          e.freeze > 0 ? "#c7efff" : "#ffffff",
          e.combatLocked ? 0 : (1 - clarity) * 0.085,
        );
        burningEnemy(fx, e, t);
        if (e.flash > 0)
          fx.glow(e.x, e.y, e.r * 2.1, "#f3f5de", clamp(e.flash * 5), 2);
        if (e.freeze > 0) {
          ground.ring(e.x, e.y, e.r + 8, "#a7def4", 0.65, 1.5, 0.6);
          for (let i = 0; i < 3; i++)
            this.brush.crystal(
              fx,
              e.x + (i - 1) * e.r * 0.65,
              e.y + e.r * 0.4,
              18 + (i % 2) * 10,
              (i - 1) * 0.35,
              "#9cddf5",
              0.8,
            );
        }
        if (
          e.boss &&
          g.enemies.some(
            (n) =>
              !n.dead &&
              g.content.bosses[
                e.bossId ?? g.content.chapters[g.chapter].bossId!
              ].shieldUnits.includes(n.type),
          )
        )
          ground.ring(e.x, e.y, 49, "#bda4d7", 0.6, 1.7, 0.5);
      }
    if (g.bookData) {
      const radius = 23 + charge * 15 + ultimate * 14;
      ground.glow(
        p.x,
        p.y + 5,
        65 + charge * 38 + ultimate * 60,
        col,
        activity * 0.25,
        1,
      );
      ground.ring(
        p.x,
        p.y + 9,
        radius,
        col,
        0.25 + charge * 0.6 + ultimate * 0.15,
        1.5,
        0.9,
        0.52,
      );
      if (charge || ultimate)
        this.brush.sigil(
          ground,
          p.x,
          p.y,
          radius + 14,
          charge * 0.7 + ultimate * 0.6,
          t,
        );
      if (charge || ultimate)
        for (let i = 0; i < 8; i++) {
          const a = (i / 8) * TAU + t * 0.6;
          ground.line(
            p.x + Math.cos(a) * (radius - 4),
            p.y + 9 + Math.sin(a) * (radius - 4) * 0.52,
            p.x + Math.cos(a) * (radius + 6),
            p.y + 9 + Math.sin(a) * (radius + 6) * 0.52,
            1.5,
            col,
            0.75,
            1.1,
          );
        }
      this.sprite(
        g.bookData.appearance,
        p.x - Math.cos(p.lean || 0) * (p.recoil || 0) * 13,
        p.y -
          Math.sin(p.lean || 0) * (p.recoil || 0) * 13 +
          Math.sin(t * 2.3) * 1.3,
        128,
        128,
        0,
        p.invuln > 0 ? 0.8 + 0.2 * Math.sin(t * 16) : 1,
        0.4 + charge,
      );
      if (p.parryTime > 0) {
        fx.ring(p.x, p.y, 42, "#dcffd0", 0.95, 2.4, 1.8);
        fx.glow(p.x, p.y, 48, "#a9f5d5", 0.24, 1.3);
      }
      if (p.shield > 0) fx.ring(p.x, p.y, 26, "#c7ace1", 0.65, 1.3, 0.65);
      if (p.invuln > 0)
        this.brush.arc(fx, p.x, p.y, 23, -t * 2, 4.9, col, 0.65, 1.6, 0.75);
      fx.glow(
        p.x + 14.5,
        p.y - 19,
        12 + charge * 15 + ultimate * 15,
        col,
        0.4 + charge * 0.5,
        1.5,
      );
      fx.add(
        p.x + 14.5,
        p.y - 19,
        4 + charge * 4,
        6 + charge * 6,
        "#f2faff",
        0.65 + charge * 0.35,
        3,
        0,
        0,
        2,
      );
      if (charge) {
        fx.glow(p.x - 8, p.y, 11 + charge * 8, col, charge * 0.65, 1.3);
        fx.glow(p.x + 8, p.y, 11 + charge * 8, col, charge * 0.65, 1.3);
      }
    }
    for (const e of g.enemies) {
      if (e.dead || e.grace > 0 || e.shoot > 0.75 || e.shoot < 0) continue;
      const profile = g.content.enemies[e.type]?.behavior;
      if (
        !profile?.ranged ||
        Math.hypot(e.x - p.x, e.y - p.y) > (profile.attackRange ?? 310)
      )
        continue;
      fx.ring(
        e.x,
        e.y,
        e.r + 12,
        "#ffc3a2",
        0.35 + (1 - e.shoot / 0.75) * 0.6,
        1.6,
        1.2,
      );
    }
    for (const s of g.spirits) {
      if (s.trail) {
        this.brush.trail(s.trail, "#c7a5ff", 2.5, 0.6);
        for (let i = 2; i < s.trail.length; i += 3) {
          const p = s.trail[i];
          fx.add(
            p.x,
            p.y,
            3,
            7,
            "#e4ceff",
            (i / s.trail.length) * 0.4,
            3,
            s.angle + t * 0.5,
            0,
            1.1,
          );
        }
      }
      this.sprite(
        "paper-spirit",
        s.x,
        s.y,
        128,
        128,
        s.mode === "orbit" ? Math.sin(t + s.i) * 0.3 : s.angle + Math.PI / 2,
        1,
        1,
      );
      fx.glow(s.x, s.y, 17, "#bd9af5", 0.3, 1);
    }
    for (const b of g.bullets)
      if (!b.dead) {
        fx.glow(b.x, b.y, b.r * 3, b.color, 0.35, 0.7);
        fx.add(
          b.x,
          b.y,
          b.heavy ? b.r * 2 : 13,
          b.heavy ? b.r * 2 : 7,
          b.color,
          1,
          b.heavy ? 1 : 3,
          Math.atan2(b.vy, b.vx),
          0,
          0.55,
        );
        fx.add(
          b.x,
          b.y,
          b.heavy ? 4 : 5,
          2,
          "#fff2dc",
          0.95,
          3,
          Math.atan2(b.vy, b.vx),
          0,
          1.2,
        );
      }
    for (const laser of g.lasers)
      if (laser.warning <= 0) {
        const a = g.arena,
          x = laser.vertical ? laser.pos : a.l,
          y = laser.vertical ? a.t : laser.pos;
        const tx = laser.vertical ? laser.pos : a.r,
          ty = laser.vertical ? a.b : laser.pos;
        fx.line(x, y, tx, ty, laser.width * 1.6, "#efc3b6", 0.65, 0.8);
        fx.line(x, y, tx, ty, 2, "#ffe0bb", 1, 1.6);
      }
    for (const blast of g.blasts)
      if (!blast.dead && blast.warning <= 0) {
        fx.glow(blast.x, blast.y, blast.r, "#ffc09b", 0.45, 0.8);
        fx.ring(blast.x, blast.y, blast.r, "#ffc3a0", 0.8, 2, 1);
      }
    for (const s of g.shots)
      if (!s.dead) {
        if (s.kind === "fire") {
          fireProjectile(fx, s, t);
          continue;
        }
        const color =
          s.kind === "ice" ? "#a9eaff" : s.kind === "echo" ? col : "#d6b4ff";
        this.brush.trail(s.trail, color, s.empowered ? 4 : 2, 0.85);
        const size = s.kind === "ice" ? (s.empowered ? 52 : 35) : 25,
          angle = Math.atan2(s.vy, s.vx);
        fx.glow(s.x, s.y, size * 0.8, color, 0.5, 1.3);
        fx.add(
          s.x,
          s.y,
          size,
          s.empowered ? 15 : 9,
          color,
          1,
          3,
          angle,
          0,
          1.3,
        );
        fx.add(s.x, s.y, size * 0.7, 2, "#f6ffff", 1, 4, angle, 0, 2);
      }
    for (const particle of g.particles) {
      const alpha = clamp(particle.life / particle.max);
      if (particle.kind === "spark")
        fx.line(
          particle.x,
          particle.y,
          particle.x - particle.vx * 0.033,
          particle.y - particle.vy * 0.033,
          particle.r * 0.7,
          particle.color,
          alpha,
          1.5,
        );
      else
        fx.add(
          particle.x,
          particle.y,
          particle.r * 3,
          particle.r * 1.6,
          particle.color,
          alpha,
          3,
          particle.angle,
          0,
          0.65,
        );
    }
    for (const f of g.fx) this.brush.effect(f);
    for (const b of this.batches) b.finish();
  }

  sprite(
    key: string,
    x: number,
    y: number,
    w: number,
    h: number,
    angle = 0,
    alpha = 1,
    emission = 0.3,
    tint = "#ffffff",
    softness = 0,
  ) {
    const handle = this.atlas.entries.get(key);
    if (!handle) return;
    let batch = this.actorPages[handle.page];
    if (this.spriteRuns.length) {
      const previous = this.spriteRuns[this.spriteRunIndex];
      if (
        this.spritePage !== handle.page ||
        !previous ||
        previous.count === previous.capacity
      ) {
        if (this.spriteRunIndex + 1 >= this.spriteRuns.length) return;
        this.spriteRunIndex++;
        this.spritePage = handle.page;
      }
      batch = this.spriteRuns[this.spriteRunIndex];
      batch.material = this.actorPages[handle.page].material;
      batch.mesh.material = batch.material;
    }
    batch.add(x, y, w, h, tint, alpha, 0, angle, softness, emission, handle.uv);
    this.atlasInstances[handle.page] =
      (this.atlasInstances[handle.page] || 0) + 1;
  }

  renderMenu(
    frame: import("../contracts/menu-scene.ts").MenuSceneFrame,
    time: number,
  ) {
    if (this.disposed || this.lost || !this.ready) return;
    this.menu.render(this.renderer, frame, time, this.game.options.fx);
  }
  render() {
    if (this.disposed || this.lost) return;
    const r = this.renderer,
      g = this.game;
    r.info.reset();
    this.populate();
    this.particles.update(g);
    const motion = g.options.reduceMotion ? 0 : g.options.shake;
    this.world.position.set(
      (g.kickX || 0) * motion +
        Math.sin(g.visualTime * 88) * (g.shake || 0) * motion * 0.42,
      (g.kickY || 0) * motion +
        Math.cos(g.visualTime * 103) * (g.shake || 0) * motion * 0.36,
      0,
    );
    r.setClearColor(0x000000, 0);
    r.setRenderTarget(this.environmentTarget);
    r.render(this.environment.scene, this.screenCamera);
    r.autoClear = false;
    r.render(this.environmentScene, this.camera);
    r.autoClear = true;
    r.setRenderTarget(this.displacementTarget);
    r.render(this.displacementScene, this.camera);
    r.setRenderTarget(this.actorTarget);
    r.render(this.world, this.camera);
    for (const b of [this.ground, ...this.actorPages, this.effects])
      b.material.uniforms.emissionOnly.value = 1;
    r.setRenderTarget(this.glowTarget);
    r.render(this.world, this.camera);
    for (const b of [this.ground, ...this.actorPages, this.effects])
      b.material.uniforms.emissionOnly.value = 0;
    this.bloom.render(r, this.glowTarget);
    this.composite.material.uniforms.bloomStrength.value = effectQuality(
      g.options.fx,
    ).bloom;
    this.composite.material.uniforms.warpStrength.value = effectQuality(
      g.options.fx,
    ).warp;
    this.composite.material.uniforms.hitFlash.value = g.options.reduceMotion
      ? 0
      : g.hitFlash || 0;
    r.setRenderTarget(null);
    r.render(this.composite.scene, this.screenCamera);
  }
  clear() {
    if (!this.lost && !this.disposed) {
      this.renderer.setRenderTarget(null);
      this.renderer.setClearColor(0x000000, 0);
      this.renderer.clear();
    }
  }
  diagnostics() {
    return {
      backend: "three-native",
      quality: effectQuality(this.game.options.fx).name,
      layerOrder: { ground: 0, actors: 1, effects: 2, particles: 3 },
      bloomLibrary: "postprocessing",
      particleLibrary: "three.quarks",
      particles: this.particles.count,
      resolution: [this.width, this.height],
      displacement: [this.mediumWidth, this.mediumHeight],
      bloom: [this.mediumWidth, this.mediumHeight],
      atlas: [this.atlas.width, this.atlas.height],
      atlasPages: this.atlas.pages.length,
      atlasVersion: this.atlas.texture.version,
      calls: this.renderer.info.render.calls,
      textures: this.renderer.info.memory.textures,
      geometries: this.renderer.info.memory.geometries,
      instances: Object.fromEntries(
        (["decor", "ground", "actors", "effects", "warp"] as const).map(
          (key) => [key, this[key].count],
        ),
      ),
      ready: this.ready,
      lost: this.lost,
    };
  }
  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    const canvas = this.renderer.domElement;
    canvas.removeEventListener("webglcontextlost", this.onLost);
    canvas.removeEventListener("webglcontextrestored", this.onRestored);
    for (const b of this.batches) b.dispose();
    for (const t of this.targets) t.dispose();
    for (const pass of this.passes) {
      pass.material.dispose();
      pass.mesh.geometry.dispose();
    }
    this.bloom.dispose();
    this.menu.dispose();
    this.particles.dispose();
    for (const texture of this.atlas.pages) texture.dispose();
    this.renderer.dispose();
  }
}
