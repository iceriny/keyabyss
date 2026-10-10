shader_type canvas_item;
uniform bool paper = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape = paper ? max(abs(p.x + p.y * 0.22), abs(p.y) * 0.8) : abs(p.x) * 1.8 + abs(p.y) * 0.8;
	float aa = max(fwidth(shape), 0.1);
	float mask = 1.0 - smoothstep(0.8 - aa, 0.8 + aa, shape);
	float fold = p.x + p.y * 0.25;
	float fold_pixel = max(fwidth(fold), 0.001);
	vec3 facet = mix(vec3(0.45, 0.65, 0.8), vec3(1.2), smoothstep(-fold_pixel, fold_pixel, fold));
	COLOR = vec4(COLOR.rgb * facet, COLOR.a * mask);
}
