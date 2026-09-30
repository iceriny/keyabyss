shader_type canvas_item;
render_mode unshaded;
#include "res://ui/materials/soft_shapes.gdshaderinc"

uniform float flutter = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y /= 0.84 + flutter * 0.12;
	// Folded leaf silhouette: long sharp tip, two swept wings and an open tail.
	float width = mix(0.50, 0.0, smoothstep(-0.62, 0.82, p.x));
	float edge = max(abs(p.y) - width, max(p.x - 0.84, -0.70 - p.x));
	edge = max(edge, (-0.38 - p.x) - abs(p.y) * 0.65);
	float paper = soft_fill(edge, 0.015, 1.0);
	vec3 color = mix(vec3(0.48, 0.34, 0.64), vec3(0.88, 0.80, 0.98), smoothstep(-0.02, 0.025, p.y));
	float fold = soft_exponential_line(p.y, 0.01) * smoothstep(-0.45, -0.22, p.x);
	color = mix(color, vec3(1.12, 1.02, 1.22), fold * 0.8);
	float vein = soft_exponential_line(p.y - (0.25 - p.x * 0.25), 1.0 / 105.0) * smoothstep(-0.5, -0.2, p.x);
	color += vec3(0.10, 0.07, 0.14) * vein;
	COLOR = vec4(color * tint.rgb, paper * tint.a);
}
