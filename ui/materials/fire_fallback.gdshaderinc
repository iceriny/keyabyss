// Top-down combustion identity without a transport grid: dark fuel pockets,
// curling hot ridges, and a feathered paid boundary. Clock zero freezes motion.
vec4 field_fire(vec2 p, float clock) {
	float radius = length(p);
	vec2 q = p * 9.0 + vec2(clock * 0.12, -clock * 0.16);
	vec2 curl = vec2(element_fbm(q + 3.7), element_fbm(q - 6.2)) - 0.5;
	float fuel = element_fbm(q + curl * 1.7);
	float tongues = element_noise(p * 19.0 + curl * 3.0 + clock * 0.17);
	float edge = 1.0 - smoothstep(0.73, 1.04, radius + (fuel - 0.5) * 0.16);
	float heat = smoothstep(0.46, 0.83, fuel + tongues * 0.14);
	vec3 color = mix(vec3(0.10, 0.006, 0.001), vec3(0.8, 0.12, 0.008), heat);
	color = mix(color, vec3(1.25, 0.65, 0.08), pow(heat, 5.0));
	return vec4(color, edge * (0.025 + heat * 0.22));
}
