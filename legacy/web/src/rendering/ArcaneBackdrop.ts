/** Arcane Folio: shared menu/battle paper, computed in the existing GPU pass.
 * No SVG tree, textures, per-frame uploads, input listeners or independent clock.
 * All motion is driven by the owner's time (zero for reduced motion).
 */
export const arcaneBackdropFragment = /* glsl */ `
varying vec2 vUv;
uniform vec2 worldSpan, worldOrigin, player;
uniform vec3 school;
uniform float time, activity, detail, presence;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
  vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);
  return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+1.),f.x),f.y);
}
float stroke(float v,float width){return 1.-smoothstep(width,width+max(fwidth(v),.0006),abs(v));}
float contour(float phase,float softness){
  float d=abs(sin(phase));
  return 1.-smoothstep(.03,.045+max(fwidth(d),.008)*softness,d);
}
// Twelve original Arcane Folio SVG glyphs, expressed as line-distance strokes.
float segment(vec2 p,vec2 a,vec2 b){vec2 q=p-a,v=b-a;return length(q-v*clamp(dot(q,v)/dot(v,v),0.,1.));}
float rune(vec2 p,float id){float d=100.;
if(id<0.5){d=min(d,segment(p,vec2(0.0,-7.0),vec2(0.0,7.0)));d=min(d,segment(p,vec2(-4.0,-4.0),vec2(0.0,-7.0)));d=min(d,segment(p,vec2(0.0,-7.0),vec2(4.0,-4.0)));d=min(d,segment(p,vec2(-3.0,2.0),vec2(3.0,2.0)));}
else if(id<1.5){d=min(d,segment(p,vec2(-4.0,-6.0),vec2(3.0,0.0)));d=min(d,segment(p,vec2(3.0,0.0),vec2(-4.0,6.0)));d=min(d,segment(p,vec2(3.0,-6.0),vec2(3.0,6.0)));d=min(d,segment(p,vec2(-3.0,0.0),vec2(5.0,0.0)));}
else if(id<2.5){d=min(d,segment(p,vec2(-4.0,5.0),vec2(0.0,-7.0)));d=min(d,segment(p,vec2(0.0,-7.0),vec2(4.0,5.0)));d=min(d,segment(p,vec2(-3.0,1.0),vec2(3.0,1.0)));d=min(d,segment(p,vec2(0.0,5.0),vec2(0.0,8.0)));}
else if(id<3.5){d=min(d,segment(p,vec2(-4.0,-5.0),vec2(4.0,5.0)));d=min(d,segment(p,vec2(4.0,-5.0),vec2(-4.0,5.0)));d=min(d,segment(p,vec2(0.0,-7.0),vec2(0.0,-3.0)));d=min(d,segment(p,vec2(0.0,3.0),vec2(0.0,7.0)));}
else if(id<4.5){d=min(d,segment(p,vec2(0.0,-7.0),vec2(0.0,7.0)));d=min(d,segment(p,vec2(0.0,-5.0),vec2(4.0,-1.0)));d=min(d,segment(p,vec2(4.0,-1.0),vec2(0.0,2.0)));d=min(d,segment(p,vec2(0.0,2.0),vec2(-4.0,-1.0)));d=min(d,segment(p,vec2(-4.0,-1.0),vec2(0.0,-5.0)));}
else if(id<5.5){d=min(d,segment(p,vec2(-4.0,-5.0),vec2(4.0,-5.0)));d=min(d,segment(p,vec2(4.0,-5.0),vec2(-4.0,5.0)));d=min(d,segment(p,vec2(-4.0,5.0),vec2(4.0,5.0)));d=min(d,segment(p,vec2(0.0,-7.0),vec2(0.0,-5.0)));d=min(d,segment(p,vec2(0.0,5.0),vec2(0.0,7.0)));}
else if(id<6.5){d=min(d,segment(p,vec2(-4.0,-6.0),vec2(-4.0,6.0)));d=min(d,segment(p,vec2(4.0,-6.0),vec2(4.0,6.0)));d=min(d,segment(p,vec2(-4.0,0.0),vec2(0.0,-4.0)));d=min(d,segment(p,vec2(0.0,-4.0),vec2(4.0,0.0)));d=min(d,segment(p,vec2(0.0,-4.0),vec2(0.0,6.0)));}
else if(id<7.5){d=min(d,segment(p,vec2(-3.0,-6.0),vec2(3.0,0.0)));d=min(d,segment(p,vec2(3.0,0.0),vec2(-3.0,6.0)));d=min(d,segment(p,vec2(0.0,-7.0),vec2(0.0,-3.0)));d=min(d,segment(p,vec2(0.0,3.0),vec2(0.0,7.0)));}
else if(id<8.5){d=min(d,segment(p,vec2(-4.0,-2.0),vec2(0.0,-7.0)));d=min(d,segment(p,vec2(0.0,-7.0),vec2(4.0,-2.0)));d=min(d,segment(p,vec2(4.0,-2.0),vec2(0.0,3.0)));d=min(d,segment(p,vec2(0.0,3.0),vec2(-4.0,-2.0)));d=min(d,segment(p,vec2(0.0,3.0),vec2(0.0,7.0)));d=min(d,segment(p,vec2(-3.0,7.0),vec2(3.0,7.0)));}
else if(id<9.5){d=min(d,segment(p,vec2(-4.0,-6.0),vec2(0.0,-2.0)));d=min(d,segment(p,vec2(0.0,-2.0),vec2(4.0,-6.0)));d=min(d,segment(p,vec2(0.0,-2.0),vec2(0.0,7.0)));d=min(d,segment(p,vec2(-4.0,2.0),vec2(0.0,5.0)));d=min(d,segment(p,vec2(0.0,5.0),vec2(4.0,2.0)));}
else if(id<10.5){d=min(d,segment(p,vec2(-4.0,5.0),vec2(-4.0,-5.0)));d=min(d,segment(p,vec2(-4.0,-5.0),vec2(4.0,5.0)));d=min(d,segment(p,vec2(4.0,5.0),vec2(4.0,-5.0)));d=min(d,segment(p,vec2(-1.0,0.0),vec2(1.0,0.0)));}
else if(id<11.5){d=min(d,segment(p,vec2(0.0,-7.0),vec2(-4.0,0.0)));d=min(d,segment(p,vec2(-4.0,0.0),vec2(0.0,7.0)));d=min(d,segment(p,vec2(0.0,7.0),vec2(4.0,0.0)));d=min(d,segment(p,vec2(4.0,0.0),vec2(0.0,-7.0)));d=min(d,segment(p,vec2(-6.0,0.0),vec2(6.0,0.0)));}
return 1.-smoothstep(.28,.28+max(fwidth(p.x),fwidth(p.y)),d);
}
float seal(vec2 p,float radius,float phase){
  float r=length(p),a=atan(p.y,p.x)+phase;
  float cuts=smoothstep(-.35,.12,sin(a*3.+.8));
  float rings=(stroke(r-radius,.0009)+stroke(r-radius*.87,.0006)*.5)*cuts;
  rings+=stroke(r-radius*.69,.0008)*smoothstep(-.3,.2,sin(a*4.-1.));
  float ticks=stroke(sin(a*48.),.10)*(1.-smoothstep(.008,.022,abs(r-radius*1.025)));
  float runes=0.;
  if(abs(r-radius*.936)<.014){
    float pitch=6.2831853/38.;
    float slot=floor((a+3.14159265)/pitch);
    float sector=mod(a+3.14159265,pitch)-pitch*.5;
    vec2 glyph=vec2(sector*r,(r-radius*.936))*850.;
    if(mod(slot,11.)!=9. && mod(slot,13.)!=10.)
      runes=rune(glyph,floor(hash(vec2(slot,radius*100.))*12.));
  }
  float polygonRadius=radius*.65*cos(3.14159265/7.)/cos(mod(a,6.2831853/7.)-3.14159265/7.);
  float polygon=stroke(r-polygonRadius,.0005);
  return rings*.65+ticks*.32+runes*.9+polygon*.22;
}
void main(){
  vec2 uv=vec2(vUv.x,1.-vUv.y);
  vec2 w=worldOrigin+uv*worldSpan;
  float shortSide=min(worldSpan.x,worldSpan.y);
  vec2 aspect=worldSpan/shortSide;
  vec2 p=(uv-.5)*aspect;
  float t=time;
  float breath=.82+.18*sin(t*.38);
  float edge=smoothstep(.54,1.15,length((uv-.5)/vec2(.52,.58)));
  vec2 drift=vec2(sin(t*.071),cos(t*.083))*.026;
  float ink=noise(p*3.2+drift);
  float stain=noise(p*8.3-vec2(t*.009,t*.006));
  vec3 col=mix(vec3(.055,.077,.087),vec3(.080,.112,.119),ink);
  col*=.92+.08*presence;
  col+=vec3(.009,.013,.012)*(stain-.4)*presence;
  // Two equally weighted, warped directions: neither vertical bands nor a grid.
  vec2 q=p+vec2(sin(p.y*4.7+t*.09),sin(p.x*4.1-t*.075))*.12;
  float f=q.x*51.+q.y*19.+sin(q.y*9.2)*2.1;
  float h=q.y*49.-q.x*22.+sin(q.x*8.1)*2.3;
  // The reading field is soft and low-contrast, never empty: waves need texture.
  float softness=mix(2.5,1.,edge);
  float textureWeight=mix(.30,1.,edge);
  float weave=contour(f,softness)+contour(h,softness)*.70;
  float relief=.52+.48*noise(p*5.7+vec2(t*.013,-t*.01));
  col+=mix(vec3(.049,.074,.072),vec3(.079,.070,.050),stain)
    *weave*relief*textureWeight*breath*.60*presence;
  if(detail>.8){
    float islands=noise(p*4.8+drift*.5);
    col+=vec3(.019,.027,.025)*contour(islands*66.,softness)*textureWeight*breath*.25*presence;
  }
  // Stationary paper tooth avoids temporal grain shimmer.
  vec2 grain=floor(p*950.);
  col+=(hash(grain)-.5)*.0015;
  float fibers=step(.94,hash(floor(p*vec2(460.,920.))));
  col+=vec3(.006,.008,.007)*fibers*detail*textureWeight*presence;
  float etch=seal(p-vec2(-aspect.x*.52,-aspect.y*.28),.46,t*.013);
  etch+=seal(p-vec2(aspect.x*.54,aspect.y*.34),.42,-t*.011+.7);
  col+=vec3(.105,.097,.071)*etch*(.7+.3*breath)*presence;
  // Broad cool/warm illumination travels on its own, without pointer input.
  vec2 lightA=p-vec2(sin(t*.12)*.46,cos(t*.095)*.26);
  vec2 lightB=p+vec2(cos(t*.10)*.63,sin(t*.13)*.33);
  col+=vec3(.008,.019,.017)*exp(-dot(lightA,lightA)*5.)*breath*presence;
  col+=vec3(.016,.010,.004)*exp(-dot(lightB,lightB)*4.)*(1.25-breath*.5)*presence;
  // Linear light in the battle target; encode only on direct menu output.
  col=pow(max(col,vec3(0.)),vec3(2.2));
  float castLight=exp(-length(w-player)/175.)*activity;
  col+=school*castLight*(.025+ink*.045);
  col*=1.-.24*smoothstep(.25,.73,length(uv-.5));
  gl_FragColor=vec4(col,1.);
  #include <colorspace_fragment>
}`;
