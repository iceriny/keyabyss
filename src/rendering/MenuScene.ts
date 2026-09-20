import * as THREE from "three";
import { MenuDust } from './MenuDust';
import type { MenuSceneFrame } from "../contracts/menu-scene.ts";

const vertexShader = `varying vec2 vUv;
void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`;
const fragmentShader = `
varying vec2 vUv;
uniform float uTime, uQuality, uSchool, uStrength;
uniform vec3 uColor;
float ring(float r,float at,float width){return exp(-abs(r-at)/width);}
void main(){
  vec2 p=(vUv-.5)*2.; float r=length(p), a=atan(p.y,p.x), t=uTime;
  float wave=sin(a*(5.+uSchool)+t*.7)*sin(a*3.-t*.4);
  float contour=.64+wave*(.008+uSchool*.003);
  float arc=pow(.5+.5*sin(a*3.-t*.65),7.);
  float ink=ring(r,contour,.004)*(.22+arc*1.2);
  ink+=ring(r,.72,.002)*(.15+pow(.5+.5*cos(a*2.+t*.35),12.)*.7);
  float spokes=pow(max(0.,cos(a*(12.+uSchool*2.)+t*.13)),42.);
  ink+=spokes*ring(r,.79,.021)*.46;
  float mist=exp(-pow((r-.62)/.11,2.))*(.07+.045*wave);
  if(uQuality>.4){
    ink+=ring(r,.57+.012*sin(a*9.+t),.002)*arc*.38;
    mist+=exp(-pow((r-.75)/.12,2.))*.025;
  }
  for(int i=0;i<18;i++){
    float fi=float(i); if(fi>6.+uQuality*11.)break;
    float angle=fi*2.39996+t*(.04+mod(fi,3.)*.014);
    float orbit=.55+mod(fi*7.,11.)*.024;
    vec2 q=p-vec2(cos(angle),sin(angle))*orbit;
    float d=length(q); float pulse=.45+.55*pow(.5+.5*sin(t+fi),2.);
    ink+=exp(-d*270.)*pulse*1.9;
    mist+=exp(-d*55.)*pulse*.08;
  }
  float light=(ink+mist)*uStrength*(1.-smoothstep(.87,1.,r));
  gl_FragColor=vec4(mix(uColor,vec3(1.,.96,.84),clamp(ink*.35,0.,.65)),clamp(light,0.,.85));
}`;

/** Two small shader planes share the battle WebGL context; no extra RAF or post stack. */
export class MenuScene {
  readonly dust = new MenuDust();
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.OrthographicCamera(0, 1, 0, 1, -1, 1);
  readonly geometry = new THREE.PlaneGeometry(1, 1);
  constructor(){this.scene.add(this.dust.points);}
  readonly meshes = Array.from({ length: 2 }, () => {
    const material = new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader,
      uniforms: {
        uTime: { value: 0 },
        uQuality: { value: 1 },
        uSchool: { value: 0 },
        uStrength: { value: 1 },
        uColor: { value: new THREE.Color() },
      },
      transparent: true,
      depthTest: false,
      depthWrite: false,
      side: THREE.DoubleSide,
      blending: THREE.AdditiveBlending,
    });
    const mesh = new THREE.Mesh(this.geometry, material);
    mesh.frustumCulled = false;
    this.scene.add(mesh);
    return mesh;
  });
  render(
    renderer: THREE.WebGLRenderer,
    frame: MenuSceneFrame,
    time: number,
    quality: number,
  ) {
    const canvas = renderer.domElement;
    this.dust.update(frame.reduced?0:time,quality,frame.color);
    this.camera.right = canvas.clientWidth;
    this.camera.bottom = canvas.clientHeight;
    this.camera.updateProjectionMatrix();
    this.meshes.forEach((mesh, i) => {
      const anchor = frame.anchors[i];
      mesh.visible = !!anchor;
      if (!anchor) return;
      mesh.position.set(anchor.x, anchor.y, 0);
      mesh.scale.set(anchor.radius * 2, anchor.radius * 2, 1);
      const u = mesh.material.uniforms;
      u.uTime.value = frame.reduced ? 0 : time;
      u.uQuality.value = quality;
      u.uSchool.value = frame.school;
      u.uStrength.value = i === 0 ? 1 : 0.8;
      u.uColor.value.set(frame.color);
    });
    renderer.info.reset();
    renderer.setRenderTarget(null);
    renderer.setClearColor(0x080d16, 1);
    renderer.render(this.scene, this.camera);
  }
  dispose() {
    this.dust.dispose();
    this.meshes.forEach((m) => m.material.dispose());
    this.geometry.dispose();
    this.scene.clear();
  }
}
