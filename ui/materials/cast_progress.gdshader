shader_type canvas_item;
render_mode unshaded;
#include "res://ui/materials/soft_shapes.gdshaderinc"
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 gold : source_color = vec4(0.86, 0.72, 0.47, 1.0);
uniform vec4 silver : source_color = vec4(0.64, 0.70, 0.70, 1.0);
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }
void fragment() {
	float y = (UV.y - 0.5) * 12.0;
	float end_fade = smoothstep(0.0, 0.07, UV.x) * smoothstep(0.0, 0.07, 1.0 - UV.x);
	float filled = (1.0 - smoothstep(progress - fwidth(UV.x), progress, UV.x)) * step(0.0001, progress);
	float tip = soft_gaussian_line(UV.x - progress, 1.0 / 180.0) * step(0.0001, progress);
	float core = soft_fill(abs(y) - 0.7, 0.3, 0.5);
	float halo = exp(-y*y / 2.0);
	vec3 metal = mix(silver.rgb, gold.rgb, filled);
	metal = mix(metal, vec3(1.0, 0.94, 0.78), tip * 0.6);
	COLOR = vec4(metal, (core * (0.18 + filled * 0.5) + halo * filled * 0.012) * end_fade) * item_modulate;
}
