shader_type canvas_item;
render_mode blend_add;

uniform vec4 tint : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float level = 0.0;
uniform float clock = 0.0;
uniform bool ready = false;
uniform bool active = false;

void fragment() {
	vec2 px = UV * vec2(300.0, 106.0);
	vec2 p = px - vec2(259.0, 45.0);
	float r = length(p);
	float angle = mod(atan(p.y, p.x) + 7.853982, 6.283185);
	float aa = max(length(fwidth(px)), 0.6);
	float arc = (1.0 - smoothstep(0.6, 0.6 + aa, abs(r - 27.0))) * (1.0 - smoothstep(level * 6.283185, level * 6.283185 + 0.04, angle));
	float fine = (1.0 - smoothstep(0.2, 0.2 + aa, abs(r - 32.0))) * pow(0.5 + 0.5 * sin(angle * 4.0), 3.0) * 0.14;
	float breathe = ready ? 0.82 + sin(clock * 1.5) * 0.18 : 0.35;
	float glow = exp(-r * r / 680.0) * (ready || active ? 0.12 * breathe : 0.013 + level * 0.035);
	float moving = pow(0.5 + 0.5 * sin(angle - clock * 0.5), 5.0);
	glow += exp(-pow((r - 27.0) / 4.0, 2.0)) * moving * (ready || active ? 0.1 : 0.02);
	float along = clamp((px.x - 8.0) / 282.0, 0.0, 1.0);
	float taper = pow(max(0.0, sin(along * 3.141593)), 0.8);
	float stroke = exp(-pow((px.y - 91.0) / 0.8, 2.0)) * taper;
	float fill = 1.0 - smoothstep(level, level + 0.008, along);
	float glint = exp(-pow((along - level) * 28.0, 2.0) - pow((px.y - 91.0) / 3.5, 2.0)) * taper * 0.12;
	vec3 metal = vec3(0.83, 0.67, 0.38);
	vec3 light = tint.rgb * glow + mix(metal, tint.rgb, 0.4) * (arc * 0.55 + fine);
	light += mix(metal * 0.12, metal * 0.75, fill) * stroke + metal * glint;
	COLOR = vec4(light, 1.0);
}
