shader_type canvas_item;
#include "res://ui/materials/element_medium.gdshaderinc"
uniform sampler2D ice_grain : filter_linear_mipmap,repeat_disable;
uniform vec4 school : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float flash = 0.0;
uniform float frozen = 0.0;
uniform float burning = 0.0;
uniform float dissolve = 0.0;
uniform float visual_time = 0.0;
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float warm = smoothstep(0.02, 0.15, tex.r - tex.b);
	vec3 ink = tex.rgb * mix(school.rgb * 0.8 + 0.28, vec3(1.0), warm);
	float grain = hash(floor(UV * 256.0));
	ink *= 0.94 + grain * 0.10;
	if (frozen > 0.0) {
		float crystal=texture(ice_grain,UV*.72+.14).r;
		float frost=frozen*(0.2+smoothstep(.35,.64,crystal)*.45);
		ink=mix(ink,vec3(0.34,0.61,0.74),frost);
		ink+=vec3(.42,.63,.72)*smoothstep(.57,.73,crystal)*frozen*.45;
	}
	ink += vec3(0.75, 0.15, 0.025) * burning * element_fbm((UV-0.5)*(7.0+sin(visual_time)*0.2));
	ink = mix(ink, vec3(1.35, 1.4, 1.25), flash * 0.75);
	float erosion = smoothstep(dissolve - 0.08, dissolve + 0.1, grain * 0.35 + UV.y * 0.65);
	float edge = (1.0 - smoothstep(0.0, 0.1, abs(grain * 0.35 + UV.y * 0.65 - dissolve))) * step(0.01, dissolve);
	COLOR = vec4(ink + vec3(0.7, 0.5, 0.2) * edge, tex.a * (dissolve > 0.0 ? erosion : 1.0)) * item_tint;
}
