shader_type canvas_item;
render_mode blend_add;
#include "res://ui/materials/soft_shapes.gdshaderinc"

uniform float clock = 0.0;
uniform float quality = 1.0;
uniform float strength = 1.0;
uniform vec3 school_color : source_color = vec3(0.545, 0.871, 1.0);
varying vec4 item_modulate;

void vertex() {
	item_modulate = COLOR;
}

float ring(float radius, float at, float width, float energy) {
	// Convert the authored light profile to linear light BEFORE pixel integration.
	return soft_exponential_line(radius - at, width / 2.2) * pow(energy * strength, 2.2);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float wave = sin(angle * 5.0) * sin(angle * 3.0);
	float contour = 0.64 + wave * 0.008;
	float arc = pow(0.5 + 0.5 * sin(angle * 3.0 - clock * 0.65), 7.0);
	float ink = ring(radius, contour, 0.004, 0.22 + arc * 1.2);
	ink += ring(radius, 0.72, 0.002, 0.15 + pow(0.5 + 0.5 * cos(angle * 2.0 + clock * 0.35), 12.0) * 0.7);
	float spokes = pow(max(0.0, cos(angle * 12.0)), 42.0);
	ink += ring(radius, 0.79, 0.021, spokes * 0.46);
	float spark_glow = 0.0;
	if (quality > 0.4) {
		ink += ring(radius, 0.57 + 0.012 * sin(angle * 9.0), 0.002, arc * 0.38);
	}
	for (int i = 0; i < 18; i++) {
		float fi = float(i);
		if (fi > 6.0 + quality * 11.0) {
			break;
		}
		float orbit_angle = fi * 2.39996 + clock * (0.04 + mod(fi, 3.0) * 0.014);
		float orbit = 0.55 + mod(fi * 7.0, 11.0) * 0.024;
		vec2 q = p - vec2(cos(orbit_angle), sin(orbit_angle)) * orbit;
		float distance_to_point = length(q);
		float pulse = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(clock + fi), 2.0);
		ink += soft_gaussian_line(distance_to_point, 0.003) * pow(pulse * 1.3 * strength, 2.2);
		spark_glow += exp(-distance_to_point * 55.0) * pulse * 0.08;
	}
	float light = (ink + pow(spark_glow * strength, 2.2)) * (1.0 - smoothstep(0.87, 1.0, radius));
	vec3 web_rgb = mix(school_color, vec3(1.0, 0.96, 0.84), clamp(ink * 0.35, 0.0, 0.65));
	// MenuScene's raw ShaderMaterial did not invoke Three's colorspace_fragment.
	// Its framebuffer values were viewed as sRGB; encode once more for Godot HDR.
	vec3 hdr_rgb = pow(max(web_rgb, vec3(0.0)), vec3(2.2));
	COLOR = vec4(hdr_rgb, clamp(light, 0.0, 0.7)) * item_modulate;
}
