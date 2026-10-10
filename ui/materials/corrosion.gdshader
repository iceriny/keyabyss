shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float strength = 1.0;
uniform float fade = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);
}
void fragment() {
    vec2 p=UV*2.-1.;
    vec2 q=p*5.+seed;
    float grains=noise(q)+.35*noise(q*2.9);
    float edge=1.-smoothstep(.52,.94,length(p)+.15*(grains-.65));
    float pits=smoothstep(.61,.74,grains);
    float vein=(1.-smoothstep(.025,.10,abs(grains-.68)))*edge;
    float pulse=.78+.22*sin(clock*2.6+grains*8.);
    vec3 ink=mix(vec3(.055,.09,.073),vec3(.22,.48,.29),pits);
    vec3 light=vec3(.36,.69,.39)*vein*pulse;
    COLOR=vec4(ink+light,edge*(.19+.28*pits+.20*vein)*strength*fade);
}
