shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/element_medium.gdshaderinc"

uniform float progress = 0.0;
uniform float seed = 0.0;
uniform bool reduced_motion = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float t = progress;
	vec3 light;
	if (reduced_motion) {
		light = vec3(1.0, .38, .06) * exp(-r2 * 18.0) * .5 * (1.0 - t);
	} else {
		float core = exp(-r2 * 55.0) * exp(-t * 13.0);
		float heat = element_fbm(p * 8.0 + seed + p * t * 3.0);
		float envelope = exp(-r2 * mix(22.0, 9.0, t));
		float tongues = smoothstep(.35, .72, heat) * envelope * exp(-t * 5.5);
		light = vec3(6.5, 5.0, 2.4) * core;
		light += vec3(2.1, .65, .08) * tongues;
		light += vec3(.65, .17, .025) * exp(-r2 * 9.0) * exp(-t * 7.0);
	}
	COLOR = vec4(light * (1.0 - smoothstep(.65, 1.0, t)), 1.0);
}
