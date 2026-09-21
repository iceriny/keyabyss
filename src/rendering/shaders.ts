export const batchVertex = /* glsl */ `
attribute vec4 instanceRect;
attribute vec4 instanceStyle;
attribute vec4 instanceColor;
attribute vec4 instanceUV;
varying vec2 vLocal;
varying vec4 vStyle;
varying vec4 vColor;
varying vec4 vAtlas;
void main() {
  vLocal = position.xy * 2.;
  vStyle = instanceStyle;
  vColor = instanceColor;
  vAtlas = instanceUV;
  float a = instanceStyle.x;
  vec2 p = position.xy * instanceRect.zw;
  p = mat2(cos(a), sin(a), -sin(a), cos(a)) * p;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(p + instanceRect.xy, 0., 1.);
}`;

export const batchFragment = /* glsl */ `
uniform sampler2D atlas;
uniform float emissionOnly;
varying vec2 vLocal;
varying vec4 vStyle;
varying vec4 vColor;
varying vec4 vAtlas;
void main() {
  float kind = vStyle.z;
  float d = length(vLocal);
  float aa = max(fwidth(d), .002);
  vec4 col = vec4(vColor.rgb, vStyle.y);
  if (kind < .5) {
    vec2 uv = vec2(vLocal.x * .5 + .5, .5 - vLocal.y * .5);
    vec4 texel = texture2D(atlas, vAtlas.xy + uv * vAtlas.zw);
    // Only cold-zone actors pass softness; clear-zone sprites retain one sample.
    if (vStyle.w > .0001) {
      vec2 blur = vec2(vStyle.w);
      texel *= .4;
      texel += texture2D(atlas, vAtlas.xy + clamp(uv + vec2(blur.x,0.),0.,1.) * vAtlas.zw) * .15;
      texel += texture2D(atlas, vAtlas.xy + clamp(uv - vec2(blur.x,0.),0.,1.) * vAtlas.zw) * .15;
      texel += texture2D(atlas, vAtlas.xy + clamp(uv + vec2(0.,blur.y),0.,1.) * vAtlas.zw) * .15;
      texel += texture2D(atlas, vAtlas.xy + clamp(uv - vec2(0.,blur.y),0.,1.) * vAtlas.zw) * .15;
    }
    col *= texel;
    if(emissionOnly > .5) col.rgb *= smoothstep(.12, .65, max(texel.r, max(texel.g, texel.b)));
  } else if (kind < 1.5) {
    col.a *= 1. - smoothstep(1. - aa, 1., d);
  } else if (kind < 2.5) {
    col.a *= 1. - smoothstep(vStyle.w, vStyle.w + aa, abs(d - 1. + vStyle.w));
  } else if (kind < 3.5) {
    float diamond = abs(vLocal.x) + abs(vLocal.y);
    col.a *= 1. - smoothstep(1. - aa, 1., diamond);
  } else if (kind < 4.5) {
    vec2 coverage = smoothstep(vec2(0.), max(fwidth(vLocal),vec2(.001)), 1.-abs(vLocal));
    col.a *= coverage.x * coverage.y;
  } else if (kind < 5.5) {
    col.a *= exp(-d*d*4.5) * (1. - smoothstep(.65, 1., d));
  } else if (kind < 6.5) {
    vec2 capsule=vec2(max(abs(vLocal.x)*vStyle.w-(vStyle.w-1.),0.),vLocal.y);
    float edge=length(capsule);
    col.a *= 1.-smoothstep(1.-max(fwidth(edge),.002),1.,edge);
  }
  if (kind > 6.5) {
    float h=clamp((1.-vLocal.y)*.5,0.,1.);
    float sway=sin(h*7.+vStyle.w)*h*.19;
    float width=(1.-h)*(.55+.15*sin(h*10.+vStyle.w))+.025;
    float edge=abs(vLocal.x-sway)/max(width,.01);
    col.a *= (1.-smoothstep(.65,1.,edge))*smoothstep(0.,.12,h)*(1.-smoothstep(.85,1.,h));
  }
  if (emissionOnly > .5) col.rgb *= vColor.a;
  if(col.a < .002) discard;
  gl_FragColor = col;
}`;

// Each field stores visible motion, not texture lookup offsets. RG is positive, BA negative;
// additive unsigned buffers work without floating point framebuffer extensions.
export const displacementFragment = /* glsl */ `
uniform vec2 worldSpan;
varying vec2 vLocal;
varying vec4 vStyle;
varying vec4 vColor;
varying vec4 vAtlas;
void main() {
  float r = length(vLocal);
  if(r >= 1.) discard;
  vec2 direction = vLocal / max(r, .03);
  float edge = 1. - smoothstep(.55, 1., r);
  vec2 offset;
  if(vStyle.z < .5) {
    offset = (-direction * .7 + vec2(-direction.y, direction.x) * 1.4)
      * sin(r * 3.14159) * edge * vStyle.y;
  } else if(vStyle.z < 1.5) {
    float width = max(vAtlas.x, .005);
    float q = (r - vStyle.w) / width;
    // Compression crest and weaker restoring wake follow the travel direction.
    float polarity = vAtlas.y;
    float band = exp(-q*q) - .24*exp(-pow((q+1.35*polarity)/.85,2.));
    offset = direction * band * vStyle.y * polarity * smoothstep(0.,width*.25,r);
  }
  if(vStyle.z >= 1.5) {
    offset = vec2(sin(vLocal.y*10.+vStyle.w*1.5), cos(vLocal.x*8.-vStyle.w*1.2))
      * edge * sin(r*3.14159) * vStyle.y;
  }
  float a=vStyle.x;
  offset=mat2(cos(a),sin(a),-sin(a),cos(a))*offset;
  offset *= vec2(1., -1.) / worldSpan;
  gl_FragColor = vec4(max(offset, 0.), max(-offset, 0.)) * 8.;
}`;

export const screenVertex = /* glsl */ `
varying vec2 vUv;
void main(){ vUv=uv; gl_Position=vec4(position.xy,0.,1.); }
`;

export const environmentFragment = /* glsl */ `
varying vec2 vUv;
uniform vec2 worldSpan;
uniform vec2 worldOrigin;
uniform vec2 player;
uniform vec3 school;
uniform float time;
uniform float activity;
uniform float detail;
float hash(vec2 p){return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p), f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
float cloud(vec2 p){return noise(p)*.55+noise(p*2.03)*.28+noise(p*4.1)*.12;}
void main(){
  vec2 w=worldOrigin+vec2(vUv.x,1.-vUv.y)*worldSpan;
  vec2 center=w-vec2(640.,399.);
  vec2 q=center/380.;
  float radius=length(q), angle=atan(q.y,q.x);
  float fog=cloud(q*2.1+vec2(time*.025,-time*.018));
  float farFog=cloud(q*3.3-vec2(time*.018,time*.012));
  float periphery=smoothstep(.35,1.3,radius);
  vec3 col=mix(vec3(.0025,.005,.011),vec3(.009,.021,.030),fog);
  col+=vec3(.009,.016,.021)*farFog*periphery*detail;
  float lens=length(center/vec2(1.,.76));
  float ring=abs(mod(lens+21.,92.)-46.);
  float cuts=smoothstep(.15,.35,sin(angle*9.+floor(lens/92.)*2.+time*.035));
  float etching=(1.-smoothstep(.5,1.4,ring))*cuts*periphery;
  col+=vec3(.025,.042,.050)*etching;
  float strata=sin(q.x*15.+sin(q.y*7.+time*.025)*.35+time*.015);
  float tracery=pow(max(0.,strata),36.)*smoothstep(.15,.75,radius);
  col+=vec3(.007,.016,.022)*tracery*detail;
  float lighting=exp(-length(w-player)/160.)*activity;
  col+=school*lighting*(.025+fog*.07);
  col*=1.-.32*smoothstep(.5,1.,length(vUv-.5));
  gl_FragColor=vec4(col,1.);
}`;

export const compositeFragment = /* glsl */ `
uniform sampler2D environment;
uniform sampler2D displacement;
uniform sampler2D actors;
uniform sampler2D bloom;
uniform float bloomStrength;
uniform float hitFlash;
uniform float warpStrength;
uniform vec2 worldSpan;
varying vec2 vUv;
void main(){
  vec4 field=texture2D(displacement,vUv);
  vec2 motion=(field.rg-field.ba)*warpStrength/8.*worldSpan;
  // Length clamp preserves radial symmetry on every aspect ratio.
  motion*=min(1.,44./max(length(motion),.001));
  // Inverse mapping: outward-moving features sample nearer the center.
  vec2 sceneUV=clamp(vUv-motion/worldSpan,vec2(.001),vec2(.999));
  vec3 env=texture2D(environment,sceneUV).rgb;
  vec4 world=texture2D(actors,sceneUV);
  vec3 col=env*(1.-world.a)+world.rgb;
  col+=texture2D(bloom,sceneUV).rgb*bloomStrength;
  col+=vec3(.28,.015,.035)*hitFlash*smoothstep(.22,.65,length(vUv-.5));
  gl_FragColor=vec4(col,1.);
  #include <colorspace_fragment>
}`;
