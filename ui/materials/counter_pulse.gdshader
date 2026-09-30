shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/soft_shapes.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_motion = false;
uniform bool guard = false;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(384.0);
	float distance_to_center = length(p);
	float eased = 1.0 - pow(1.0 - progress, 3.0);
	float radius = guard ? 54.0 : (reduced_motion ? 57.0 : mix(22.0, 160.0, eased));
	float fade = guard ? (1.0 - smoothstep(0.55, 1.0, progress)) : pow(1.0 - progress, 1.5);
	float flash = 1.0 - smoothstep(0.0, 0.22, progress);
	float band = distance_to_center - radius;
	float bloom = soft_gaussian(band, 18.0) * 0.16;
	float body = soft_gaussian(band, 5.0) * 0.4;
	float crest = soft_gaussian_line(band, 2.2) * 0.4;
	float inner = soft_gaussian(distance_to_center - radius * 0.76, 12.0) * 0.025;
	float contact = soft_gaussian(distance_to_center, 27.0) * flash * 0.035;
	float alpha = ((bloom + body + crest + inner) * fade + contact) * (guard ? 0.8 : 0.55);
	vec3 color = mix(vec3(0.67, 0.9, 0.49), vec3(1.1, 1.2, 0.84), clamp(crest * 2.0, 0.0, 1.0));
	COLOR = vec4(color, alpha);
}
