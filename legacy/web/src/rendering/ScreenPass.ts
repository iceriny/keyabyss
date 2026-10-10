import * as THREE from "three";
import { screenVertex } from "./shaders";
export function screen(
  fragmentShader: string,
  uniforms: Record<string, THREE.IUniform>,
) {
  const material = new THREE.ShaderMaterial({
    vertexShader: screenVertex,
    fragmentShader,
    uniforms,
    depthTest: false,
    depthWrite: false,
  });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), material);
  const scene = new THREE.Scene();
  scene.add(mesh);
  return { scene, material, mesh };
}
export function target(type: THREE.TextureDataType) {
  return new THREE.WebGLRenderTarget(1, 1, {
    type,
    depthBuffer: false,
    stencilBuffer: false,
  });
}
