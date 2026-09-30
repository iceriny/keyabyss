shader_type canvas_item;
render_mode unshaded;

uniform float reach = 106.0;
uniform float half_angle = 0.82;
uniform float heading = 0.0;
uniform float charge = 0.0;
uniform float strike = -1.0;
uniform vec4 warning_color : source_color = vec4(0.91, 0.64, 0.45, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 256.0;
	float radius = length(p);
	float angle = atan(p.y, p.x) - heading;
	angle = atan(sin(angle), cos(angle));
	float aa = max(fwidth(radius), 0.7);
	float angular = 1.0 - smoothstep(half_angle - 0.015, half_angle + 0.015, abs(angle));
	float inside = (1.0 - smoothstep(reach - aa, reach + aa, radius)) * angular;
	float rim = exp(-pow((radius - reach) / 1.2, 2.0)) * angular;
	float gather = exp(-pow((radius - reach * charge) / 3.0, 2.0)) * angular;
	float alpha = inside * (0.035 + charge * 0.035) + rim * (0.2 + charge * 0.43) + gather * charge * 0.17;
	vec3 tint = warning_color.rgb;
	if (strike >= 0.0) {
		float blade_angle = mix(-half_angle, half_angle, smoothstep(0.0, 0.85, strike));
		float blade = exp(-pow((angle - blade_angle) * max(radius, 10.0) / 6.0, 2.0));
		float fade = 1.0 - smoothstep(0.55, 1.0, strike);
		alpha = (inside * 0.12 + rim * 0.48 + blade * inside * 0.7) * fade;
		tint = mix(tint, vec3(1.0, 0.9, 0.7), blade * 0.8);
	}
	COLOR = vec4(tint, alpha * smoothstep(10.0, 24.0, radius));
}
