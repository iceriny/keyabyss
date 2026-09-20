import { BloomEffect } from "postprocessing";
import type { TextureDataType, WebGLRenderer, WebGLRenderTarget } from "three";

/** The scene already provides an emission mask; let postprocessing handle the blur pyramid. */
export class BloomLayer {
  private readonly effect = new BloomEffect({
    mipmapBlur: true,
    levels: 5,
    radius: 0.65,
    intensity: 1,
  });

  constructor(renderer: WebGLRenderer, precision: TextureDataType) {
    this.effect.luminancePass.enabled = false;
    this.effect.initialize(renderer, true, precision);
  }

  get texture() {
    return this.effect.texture;
  }
  resize(width: number, height: number) {
    this.effect.setSize(width, height);
  }
  render(renderer: WebGLRenderer, emission: WebGLRenderTarget) {
    this.effect.update(renderer, emission, 0);
  }
  dispose() {
    this.effect.dispose();
  }
}
