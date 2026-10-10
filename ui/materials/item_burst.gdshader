shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/element_medium.gdshaderinc"

uniform float progress = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform int style = 0;
uniform float seed = 0.0;
uniform bool reduced_motion = false;
uniform float radius = 255.0;

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * 1.2;
	float r = length(p);
	float t = progress;
	vec2 world = p * radius;
	float edge = 1.0 - smoothstep(.92, 1.15, r);
	vec3 white = mix(tint.rgb, vec3(1.0), .8);
	float core_width = style == 0 ? 31.0 : (style == 3 ? 23.0 : 28.0);
	float ignition = exp(-dot(world, world) / (core_width * core_width));
	vec3 light;
	if (reduced_motion) {
		light = tint.rgb * exp(-dot(world, world) / 6400.0) * .6 * (1.0 - t);
	} else {
		// A single brief bright beat. Large-scale movement belongs to the shards.
		float force = style == 0 ? 2.0 : (style == 3 ? 1.1 : 1.0);
		light = white * ignition * exp(-t * 13.0) * (style == 2 ? 7.5 : 8.0 * force);
		float glow = exp(-dot(world, world) / 8100.0) * exp(-t * 7.0);
		light += tint.rgb * glow * .65 * force;
		vec2 axis = p / max(r, .001);
		float reach = .08 + .82 * (1.0 - exp(-t * 6.0));
		float front_distance = (length(world) - radius * reach) / 16.0;
		float band = exp(-front_distance * front_distance);
		float opening = smoothstep(.10, .28, r);
		// Cartesian patches avoid radial wedges and long, petal-shaped streaks.
		float fragments = pow(smoothstep(.54, .82, element_fbm(world / 9.0 + seed)), 2.0);
		light += white * fragments * band * opening * exp(-t * 3.5) * .65 * force;
		vec2 drift = world / 58.0 + seed;
		float mist = element_fbm(drift + axis * t * .55);
		float wisps = smoothstep(.4, .75, mist) * element_noise(drift * 3.1);
		float haze = exp(-r * r * 4.0) * opening * sin(t * 3.141593);
		// Wisps support the light; their peak contribution stays below five percent.
		light += tint.rgb * wisps * haze * .085;
	}
	COLOR = vec4(light * edge * (1.0 - smoothstep(.7, 1.0, t)), 1.0);
}
