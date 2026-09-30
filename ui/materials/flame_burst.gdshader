shader_type canvas_item;
render_mode blend_add;
#include "res://ui/materials/soft_shapes.gdshaderinc"

uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float front = mix(0.06, 0.78, smoothstep(0.0, 0.82, progress));
	float fade = pow(1.0 - progress, 1.6);
	float curl = sin(angle * 5.0 - progress * 1.7) * 0.017 + sin(angle * 9.0 + 1.3) * 0.009;
	float arc_gap = pow(0.5 + 0.5 * sin(angle * 3.0 + 0.5 + sin(angle * 2.0) * 1.2), 2.0);
	float arc = soft_gaussian_line(radius - front - curl, 0.015) * arc_gap;
	float aura = soft_gaussian(radius - front - curl, 0.065) * arc_gap;
	float tip = pow(max(0.0, 0.5 + 0.5 * sin(angle * 7.0 + sin(angle * 3.0) * 0.7)), 13.0);
	float tip_end = front + 0.045 + 0.12 * tip * (1.0 - progress);
	float remnant = smoothstep(front - 0.015, front + 0.025, radius)
		* (1.0 - smoothstep(front + 0.025, tip_end, radius)) * tip * arc_gap;
	float flash = exp(-radius * radius * 62.0) * (1.0 - smoothstep(0.0, 0.26, progress));
	float alpha = (arc * 0.42 + aura * 0.06 + remnant * 0.12) * fade + flash * 0.65;
	vec3 color = mix(vec3(1.55, 0.52, 0.19), vec3(2.5, 1.28, 0.54), arc * 0.65 + remnant * 0.2);
	color = mix(color, vec3(2.8, 2.26, 1.5), clamp(flash * 1.5, 0.0, 1.0));
	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
