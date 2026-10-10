shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://ui/materials/soft_shapes.gdshaderinc"

uniform vec4 gold : source_color = vec4(0.79, 0.63, 0.34, 1.0);
uniform vec4 glint : source_color = vec4(1.0, 0.92, 0.72, 1.0);
uniform float clock = 0.0;
uniform float path_length = 160.0;
uniform float phase = 0.0;
uniform float activity = 0.0;
uniform float pulse = 0.0;
uniform float trigger_time = -1000.0;
uniform bool motion_enabled = true;

void fragment() {
	// Broad, slow illumination keeps each control's seeded rhythm on interaction.
	// Shared root distance carries that illumination through the faint offshoots.
	float spread = clamp(path_length*0.24, 20.0, 42.0);
	float period = path_length+spread*3.0;
	float front = mod(clock*mix(12.0,19.0,phase)+phase*period,period)-spread*1.5;
	float age = max(0.0,clock-trigger_time);
	float response = exp(-age/1.6)*(1.0-exp(-age/0.2));
	float behind = front - UV.x;
	float head = exp(-pow(behind/spread, 2.0));
	float wake = exp(-abs(behind)/(spread*1.5)) * smoothstep(0.0,spread,behind);
	float flow = motion_enabled ? head + wake*0.2 : 0.0;
	float metal = soft_gaussian_line(UV.y, 0.42);
	float sheen = soft_gaussian_line(UV.y+0.38, 0.2);
	float glow = exp(-UV.y*UV.y/12.0);
	float end_fade = 1.0 - smoothstep(4.0, 7.0, abs(UV.y));
	float light = flow*(0.16+activity*0.09) + response*0.08 + pulse*0.04;
	vec3 core = mix(gold.rgb*0.52, glint.rgb, light);
	vec3 radiance = core*metal*(0.42+activity*0.08+light*0.4);
	radiance += glint.rgb*sheen*(0.035+light*0.08);
	radiance += gold.rgb*glow*(0.004+light*0.05);
	COLOR = vec4(radiance, COLOR.a * end_fade);
}
