shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;

void fragment() {
	// Keep the original glyph coverage sharp; only its metal reflectance changes.
	vec2 p = FRAGCOORD.xy * SCREEN_PIXEL_SIZE.y;
	float band = 0.5 + 0.5 * sin(dot(p, vec2(8.0, -5.5)) - clock * 0.24);
	float polish = 0.5 + 0.5 * sin(dot(p, vec2(31.0, 18.0)) + 0.7);
	vec3 gold = mix(vec3(0.42, 0.28, 0.12), vec3(1.12, 0.97, 0.68), band * 0.75 + polish * 0.25);
	gold += vec3(0.95, 0.82, 0.58) * pow(band, 42.0);
	COLOR.rgb *= gold;
}
