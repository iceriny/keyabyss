import { effectQuality } from "./EffectQuality";
import * as THREE from "three";
import {
  BatchedRenderer,
  ParticleSystem,
  CircleEmitter,
  ConstantValue,
  IntervalValue,
  ConstantColor,
  ColorOverLife,
  Gradient,
  SizeOverLife,
  PiecewiseBezier,
  Bezier,
  Vector3,
  Vector4,
  RenderMode,
} from "three.quarks";
import type { RenderFrame } from "../contracts/render-frame.ts";
import type { VisualEffect } from "../combat/model";

/** Quarks owns particle simulation, recycling and GPU batches. Slots bound simultaneous emitters. */
export class ParticleLayer {
  readonly object = new THREE.Group();
  readonly batch = new BatchedRenderer();
  private readonly texture = this.makeTexture();
  private readonly material = new THREE.MeshBasicMaterial({
    map: this.texture,
    transparent: true,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    depthTest: false,
    side: THREE.DoubleSide,
    toneMapped: false,
  });
  private readonly systems: ParticleSystem[] = [];
  private cueSequence = 0;
  private cueSession = -1;
  private roomVisit = -1;
  private cursor = 0;
  private lastTime = 0;
  private configuration: RenderFrame["config"] | undefined;

  constructor() {
    this.object.add(this.batch);
    for (let i = 0; i < 16; i++) {
      const system = new ParticleSystem({
        duration: 0.08,
        looping: false,
        autoDestroy: false,
        shape: new CircleEmitter({ radius: 3, thickness: 1 }),
        startLife: new IntervalValue(0.3, 0.85),
        startSpeed: new IntervalValue(24, 115),
        startSize: new IntervalValue(3, 9),
        startColor: new ConstantColor(new Vector4(1, 1, 1, 1)),
        emissionOverTime: new ConstantValue(0),
        emissionBursts: [
          {
            time: 0,
            count: new ConstantValue(20),
            cycle: 1,
            interval: 0,
            probability: 1,
          },
        ],
        behaviors: [
          new SizeOverLife(
            new PiecewiseBezier([[new Bezier(1, 0.9, 0.4, 0), 0]]),
          ),
          new ColorOverLife(
            new Gradient(
              [[new Vector3(1, 1, 1), 0]],
              [
                [1, 0],
                [0.7, 0.4],
                [0, 1],
              ],
            ),
          ),
        ],
        material: this.material,
        renderMode: RenderMode.BillBoard,
        worldSpace: true,
        renderOrder: 3,
      });
      system.stop();
      this.object.add(system.emitter);
      this.batch.addSystem(system);
      this.systems.push(system);
    }
  }

  private makeTexture() {
    // One reusable 512px optical sprite; never uploaded again during combat.
    const size = 512,
      data = new Uint8Array(size * size * 4);
    for (let y = 0; y < size; y++)
      for (let x = 0; x < size; x++) {
        const dx = ((x + 0.5) / size) * 2 - 1,
          dy = ((y + 0.5) / size) * 2 - 1;
        const r = Math.hypot(dx, dy),
          core = Math.pow(Math.max(0, 1 - r), 3);
        const rays =
          Math.exp(-Math.min(dx * dx, dy * dy) * 180) *
          Math.pow(Math.max(0, 1 - r), 5);
        const offset = (y * size + x) * 4;
        data[offset] = data[offset + 1] = data[offset + 2] = 255;
        data[offset + 3] = Math.round(Math.min(1, core + rays * 0.5) * 255);
      }
    const texture = new THREE.DataTexture(data, size, size);
    texture.magFilter = THREE.LinearFilter;
    texture.minFilter = THREE.LinearFilter;
    texture.needsUpdate = true;
    return texture;
  }

  update(game: RenderFrame) {
    const reset =
      this.configuration !== game.config || this.roomVisit !== game.roomVisit;
    this.object.visible = !game.options.reduceMotion;
    if (reset) {
      this.configuration = game.config;
      this.roomVisit = game.roomVisit;
      this.cueSequence = 0;
      this.cueSession = game.cues.session;
      for (const system of this.systems) system.stop();
      this.lastTime = game.visualTime;
    }
    const delta = Math.max(0, Math.min(0.05, game.visualTime - this.lastTime));
    this.lastTime = game.visualTime;
    let emitted = false;
    if (this.cueSession !== game.cues.session) {
      this.cueSession = game.cues.session;
      this.cueSequence = 0;
    }
    for (const cue of game.cues.after(this.cueSequence)) {
      this.cueSequence = cue.sequence;
      if (cue.value.room !== game.roomVisit) continue;
      const effect = cue.value.effect;
      if (effect.type !== "burst" || game.options.reduceMotion) continue;
      const system = this.systems[this.cursor++ % this.systems.length];
      system.stop();
      const ultimate = effect.kind === "ultimate";
      const color = new THREE.Color(effect.color);
      system.startColor = new ConstantColor(
        new Vector4(color.r * 1.6, color.g * 1.6, color.b * 1.6, 0.85),
      );
      system.startSpeed = new IntervalValue(
        ultimate ? 70 : 20,
        ultimate ? 340 : 165,
      );
      system.startSize = new IntervalValue(ultimate ? 5 : 3, ultimate ? 15 : 9);
      system.emissionBursts[0].count = new ConstantValue(
        Math.round(
          (ultimate ? 150 : 36) * effectQuality(game.options.fx).particles,
        ),
      );
      system.emitter.position.set(effect.x, effect.y, 0);
      system.emitter.updateMatrixWorld(true);
      system.restart();
      emitted = true;
    }
    // A new burst can arrive in a frozen preview. Otherwise zero delta preserves pause exactly.
    // Even update(0) reevaluates Quarks' life curves, so don't simulate a frozen frame.
    if (delta > 0 || emitted || reset)
      this.batch.update(delta || (emitted ? 0.001 : 0));
  }

  get count() {
    return this.systems.reduce((sum, system) => sum + system.particleNum, 0);
  }
  dispose() {
    for (const system of this.systems) {
      this.batch.deleteSystem(system);
      system.dispose();
    }
    for (const batch of this.batch.batches) batch.dispose();
    this.object.clear();
    this.material.dispose();
    this.texture.dispose();
  }
}
