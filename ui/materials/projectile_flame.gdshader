shader_type canvas_item;
render_mode blend_add;
#include "res://ui/materials/soft_shapes.gdshaderinc"

uniform float empowered = 0.0;
uniform float visual_time = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float along = smoothstep(-1.0, 0.55, p.x);
	float width = mix(0.025, 0.34, along) * sqrt(max(0.0, 1.0 - pow((p.x + 0.10) / 0.98, 2.0)));
	float bend = sin(p.x * 5.0 - visual_time * 5.0) * (1.0 - along) * 0.045;
	float edge = abs(p.y - bend);
	float body = soft_fill(edge - width, 0.02, 1.5);
	body *= smoothstep(-1.0, -0.72, p.x) * (1.0 - smoothstep(0.48, 0.96, p.x));
	float fork_offset = 0.19 + sin(p.x * 6.0 + visual_time * 7.0) * 0.045;
	float fork_width = mix(0.04, 0.16, along);
	float upper = exp(-pow((p.y - fork_offset) / fork_width, 2.0) * 2.3);
	float lower = exp(-pow((p.y + fork_offset) / fork_width, 2.0) * 2.3);
	float forks = max(upper, lower) * smoothstep(-0.75, -0.2, p.x) * (1.0 - smoothstep(0.25, 0.87, p.x));
	float core = exp(-dot((p - vec2(0.34, 0.0)) * vec2(1.55, 3.4), (p - vec2(0.34, 0.0)) * vec2(1.55, 3.4)) * 9.0);
	float glow = exp(-pow(edge / max(width * 1.65, 0.09), 2.0) * 2.5);
	glow *= smoothstep(-1.0, -0.65, p.x) * (1.0 - smoothstep(0.55, 0.99, p.x));
	float alpha = (max(body * 0.65, core * 0.92) + glow * 0.10 + forks * empowered * 0.48) * (1.0 - smoothstep(0.65, 0.98, length(p * vec2(1.0, 0.45))));
	vec3 color = mix(vec3(1.45, 0.43, 0.16), vec3(2.4, 1.15, 0.46), clamp(body * 0.65 + core, 0.0, 1.0));
	color = mix(color, vec3(2.8, 2.12, 1.17), clamp(core * 0.88, 0.0, 1.0));
	COLOR = vec4(color * (1.0 + empowered * 0.18), clamp(alpha, 0.0, 1.0));
}
