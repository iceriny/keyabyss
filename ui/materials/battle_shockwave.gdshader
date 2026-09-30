shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 waves[4]; // center.xy, radius, strength
uniform float aspect = 1.7777778;

void fragment() {
	vec2 displacement = vec2(0.0);
	float light = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 delta = (SCREEN_UV - waves[i].xy) * vec2(aspect, 1.0);
		float distance_to_center = length(delta);
		float rim = exp(-pow((distance_to_center - waves[i].z) / 0.025, 2.0));
		vec2 direction = delta / max(distance_to_center, 0.0001);
		displacement += direction * rim * waves[i].w;
		light += rim * abs(waves[i].w) * 2.5;
	}
	displacement *= min(1.0, 0.009 / max(length(displacement), 0.00001));
	vec2 sample_uv = clamp(SCREEN_UV + displacement / vec2(aspect, 1.0), vec2(0.001), vec2(0.999));
	COLOR = vec4(texture(screen_texture, sample_uv).rgb + vec3(0.65, 0.8, 0.8) * light, 1.0);
}
