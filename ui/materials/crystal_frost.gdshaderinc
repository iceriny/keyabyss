// One spatial frost field for the menu veil and embedded relic materials.
float crystal_frost(vec2 uv, float t, float speed) {
	float bend = 0.16 * sin(uv.y * 6.0 + t * 0.13)
		+ 0.07 * sin(uv.x * 5.0 - uv.y * 3.0 + t * 0.09);
	float wave = 0.5 + 0.5 * sin(6.283185 * (uv.x * 1.35 + uv.y * 0.22 + bend - t * speed));
	return smoothstep(0.20, 0.82, wave);
}
