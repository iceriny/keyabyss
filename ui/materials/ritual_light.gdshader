shader_type canvas_item;
render_mode unshaded;

// CanvasGroup supplies only the ritual's premultiplied light, never its text.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float clock = 0.0;
uniform float core_softness = 0.45;
uniform float core_light = 1.35;
uniform float halo_light = 1.0;
uniform float spread = 0.0;
uniform float metal_strength = 0.7;
uniform float highlight_energy = 1.0;

vec4 diffuse_light(vec2 uv, float level, vec2 pixel) {
	vec2 radius = pixel * level;
	vec4 light = vec4(0.0);
	// Sample only the cleared full-resolution group region. Shared backbuffer
	// mip levels retain neighbouring groups and reveal their rectangular bounds.
	for (int y = -2; y <= 2; y++) {
		float wy = y == 0 ? 6.0 : (abs(y) == 1 ? 4.0 : 1.0);
		for (int x = -2; x <= 2; x++) {
			float wx = x == 0 ? 6.0 : (abs(x) == 1 ? 4.0 : 1.0);
			light += textureLod(screen_texture, uv + vec2(float(x), float(y)) * radius, 0.0) * wx * wy / 256.0;
		}
	}
	return light;
}

void fragment() {
	vec4 core = diffuse_light(SCREEN_UV, core_softness * 0.35, SCREEN_PIXEL_SIZE);
	vec4 near_glow = diffuse_light(SCREEN_UV, 0.9 + spread, SCREEN_PIXEL_SIZE);
	vec4 far_glow = diffuse_light(SCREEN_UV, 2.0 + spread, SCREEN_PIXEL_SIZE);
	vec2 pixel = SCREEN_PIXEL_SIZE;
	float left = textureLod(screen_texture, SCREEN_UV - vec2(pixel.x, 0), 0.0).a;
	float right = textureLod(screen_texture, SCREEN_UV + vec2(pixel.x, 0), 0.0).a;
	float up = textureLod(screen_texture, SCREEN_UV - vec2(0, pixel.y), 0.0).a;
	float down = textureLod(screen_texture, SCREEN_UV + vec2(0, pixel.y), 0.0).a;
	// Coverage gradients give the engraved strokes a small rounded metal bevel.
	vec3 normal = normalize(vec3((left - right) * 2.5, (up - down) * 2.5, 0.55));
	vec3 lamp = normalize(vec3(-0.55 + sin(clock * 0.13) * 0.35, -0.65, 0.8));
	float facet = max(dot(normal, lamp), 0.0);
	vec2 p = FRAGCOORD.xy * SCREEN_PIXEL_SIZE.y;
	float reflection = 0.5 + 0.5 * sin(dot(p, vec2(8.0, -5.5)) - clock * 0.24);
	vec3 halfway = normalize(lamp + vec3(0.0, 0.0, 1.0));
	float glint = pow(reflection, 48.0) * pow(max(dot(normal, halfway), 0.0), 12.0) * highlight_energy * 1.6;
	vec3 metal = mix(vec3(0.38, 0.24, 0.11), vec3(1.12, 0.98, 0.73), facet * (0.60 + reflection * 0.40));
	metal += vec3(1.2, 1.02, 0.72) * glint;
	vec4 light = core * core_light;
	light.rgb *= mix(vec3(1.0), metal, metal_strength);
	vec4 halo = (near_glow * 0.65 + far_glow * 0.75) * halo_light;
	// Reflections brighten short sections; broad soft emission stays subordinate.
	halo.rgb *= 0.55 + glint * 1.5;
	light += halo;
	// Preserve the group's coverage when resolving premultiplied samples.
	COLOR *= vec4(light.rgb / max(light.a, 0.0001), min(light.a, 1.0));
}
