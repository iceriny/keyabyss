import * as THREE from "three";
import { batchVertex, batchFragment } from "./shaders";
import { rgb } from "./palette";
export type AtlasRegion = [number, number, number, number];
/** Fixed GPU buffers. Frame submission only changes instance attributes. */
export class InstancedBatch {
  ownsMaterial = true;
  capacity: number;
  count: number;
  geometry: THREE.InstancedBufferGeometry;
  material: THREE.ShaderMaterial;
  mesh: THREE.Mesh;
  attributes: THREE.InstancedBufferAttribute[];
  constructor(
    atlas: THREE.Texture,
    capacity: number,
    fragmentShader = batchFragment,
  ) {
    this.capacity = capacity;
    this.count = 0;
    const plane = new THREE.PlaneGeometry(1, 1);
    this.geometry = new THREE.InstancedBufferGeometry();
    this.geometry.index = plane.index;
    this.geometry.attributes.position = plane.attributes.position;
    this.geometry.attributes.uv = plane.attributes.uv;
    this.attributes = [
      "instanceRect",
      "instanceStyle",
      "instanceColor",
      "instanceUV",
    ].map((name) => {
      const attr = new THREE.InstancedBufferAttribute(
        new Float32Array(capacity * 4),
        4,
      ).setUsage(THREE.DynamicDrawUsage);
      this.geometry.setAttribute(name, attr);
      return attr;
    });
    this.material = new THREE.ShaderMaterial({
      vertexShader: batchVertex,
      fragmentShader,
      transparent: true,
      depthTest: false,
      depthWrite: false,
      side: THREE.DoubleSide,
      uniforms: {
        atlas: { value: atlas },
        emissionOnly: { value: 0 },
        worldSpan: { value: new THREE.Vector2(1280, 800) },
      },
    });
    this.mesh = new THREE.Mesh(this.geometry, this.material);
    this.mesh.frustumCulled = false;
    this.geometry.instanceCount = 0;
  }
  reset() {
    this.count = 0;
  }
  add(
    x: number,
    y: number,
    w: number,
    h: number,
    color = "#ffffff",
    alpha = 1,
    kind = 1,
    angle = 0,
    extra = 0.02,
    emission = 0,
    uv: AtlasRegion | null = null,
  ) {
    if (this.count >= this.capacity || alpha <= 0) return;
    const i = this.count++ * 4,
      c = rgb(color),
      a = this.attributes;
    const rect = a[0].array,
      style = a[1].array,
      tint = a[2].array,
      region = a[3].array;
    rect[i] = x;
    rect[i + 1] = y;
    rect[i + 2] = w;
    rect[i + 3] = h;
    style[i] = angle;
    style[i + 1] = alpha;
    style[i + 2] = kind;
    style[i + 3] = extra;
    tint[i] = c.r;
    tint[i + 1] = c.g;
    tint[i + 2] = c.b;
    tint[i + 3] = emission;
    region[i] = uv?.[0] || 0;
    region[i + 1] = uv?.[1] || 0;
    region[i + 2] = uv?.[2] || 1;
    region[i + 3] = uv?.[3] || 1;
  }
  ring(
    x: number,
    y: number,
    r: number,
    color: string,
    alpha = 1,
    width = 1.5,
    emission = 0.5,
    ratio = 1,
  ) {
    this.add(
      x,
      y,
      r * 2,
      r * 2 * ratio,
      color,
      alpha,
      2,
      0,
      width / Math.max(r, 1),
      emission,
    );
  }
  glow(
    x: number,
    y: number,
    r: number,
    color: string,
    alpha = 1,
    emission = 1,
  ) {
    this.add(x, y, r * 2, r * 2, color, alpha, 5, 0, 0, emission);
  }
  line(
    x: number,
    y: number,
    tx: number,
    ty: number,
    width: number,
    color: string,
    alpha = 1,
    emission = 1,
  ) {
    const length = Math.hypot(tx - x, ty - y) + width;
    this.add(
      (x + tx) / 2,
      (y + ty) / 2,
      length,
      width,
      color,
      alpha,
      6,
      Math.atan2(ty - y, tx - x),
      length / width,
      emission,
    );
  }
  finish() {
    this.geometry.instanceCount = this.count;
    for (const attr of this.attributes) {
      attr.clearUpdateRanges();
      if (this.count) {
        attr.addUpdateRange(0, this.count * 4);
        attr.needsUpdate = true;
      }
    }
  }
  dispose() {
    this.geometry.dispose();
    if (this.ownsMaterial) this.material.dispose();
  }
}
