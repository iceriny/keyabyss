import * as THREE from "three";
/** One fixed point buffer for drifting background dust, shared with the menu scene. */
export class MenuDust {
  readonly geometry = new THREE.BufferGeometry();
  readonly material = new THREE.ShaderMaterial({
    uniforms: {
      time: { value: 0 },
      tint: { value: new THREE.Color("#b2dbe7") },
    },
    vertexShader: `uniform float time; varying float alpha;
      void main(){float seed=position.z; vec2 p=position.xy;
      p.y=mod(p.y+1.+time*(.006+seed*.01),2.)-1.;p.x+=sin(time*.12+seed*31.)*.025;
      alpha=(.25+.5*pow(.5+.5*sin(time*.6+seed*35.),2.))*smoothstep(0.,.16,1.-abs(p.y));
      gl_Position=vec4(p,0.,1.);gl_PointSize=3.+seed*6.;}`,
    fragmentShader: `uniform vec3 tint;varying float alpha;void main(){float d=length(gl_PointCoord-.5)*2.;if(d>1.)discard;gl_FragColor=vec4(tint,exp(-d*d*6.)*alpha*.65);}`,
    transparent: true,
    depthTest: false,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  readonly points: THREE.Points;
  constructor() {
    const positions = new Float32Array(96 * 3);
    for (let i = 0; i < 96; i++) {
      positions[i * 3] = ((i * 73 + 11) % 101) / 50 - 1;
      positions[i * 3 + 1] = ((i * 43 + 19) % 97) / 48 - 1;
      positions[i * 3 + 2] = ((i * 17) % 31) / 31;
    }
    this.geometry.setAttribute(
      "position",
      new THREE.BufferAttribute(positions, 3),
    );
    this.points = new THREE.Points(this.geometry, this.material);
    this.points.frustumCulled = false;
    this.points.renderOrder = -1;
  }
  update(time: number, quality: number, color: string) {
    this.material.uniforms.time.value = time;
    this.material.uniforms.tint.value.set(color);
    this.geometry.setDrawRange(0, quality < 0.5 ? 24 : quality < 0.9 ? 56 : 96);
  }
  dispose() {
    this.geometry.dispose();
    this.material.dispose();
  }
}
