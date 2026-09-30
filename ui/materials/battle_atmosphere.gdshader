shader_type canvas_item;

uniform vec4 school_color : source_color = vec4(0.28, 0.72, 1.0, 1.0);
uniform float motion = 1.0;
uniform float visual_time = 0.0;
uniform vec2 player_uv = vec2(0.5);
uniform float activity = 0.0;
uniform sampler2D paper_noise : filter_linear_mipmap, repeat_enable;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	return texture(paper_noise, p * 0.125 + 0.5).r;
}

void fragment() {
	vec2 uv = UV;
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (uv - 0.5) * resolution / min(resolution.x, resolution.y);
	float t = visual_time * motion;
	float ink = noise(p * 3.2 + vec2(sin(t * 0.07), cos(t * 0.08)) * 0.02);
	float stain = noise(p * 8.3 - vec2(t * 0.009, t * 0.006));
	vec2 q = p + vec2(sin(p.y * 4.7 + t * 0.09), sin(p.x * 4.1 - t * 0.075)) * 0.12;
	float strand_a = abs(sin(q.x * 51.0 + q.y * 19.0 + sin(q.y * 9.2) * 2.1));
	float strand_b = abs(sin(q.y * 49.0 - q.x * 22.0 + sin(q.x * 8.1) * 2.3));
	float weave = (1.0 - smoothstep(0.0, 0.13 + fwidth(strand_a) * 2.0, strand_a)) + (1.0 - smoothstep(0.0, 0.13 + fwidth(strand_b) * 2.0, strand_b)) * 0.7;
	float reading_field = mix(0.12, 0.65, smoothstep(0.2, 0.8, length(p)));
	float relief = 0.52 + 0.48 * noise(p * 5.7 + vec2(t * 0.013, -t * 0.01));
	vec3 col = mix(vec3(0.003, 0.005, 0.006), vec3(0.005, 0.008, 0.009), ink);
	col += mix(vec3(0.004, 0.007, 0.006), vec3(0.007, 0.006, 0.004), stain) * weave * relief * reading_field * 0.45;
	col += vec3(0.002, 0.004, 0.004) * exp(-dot(p - vec2(-0.3, 0.0), p - vec2(-0.3, 0.0)) * 5.0);
	col += vec3(0.004, 0.003, 0.001) * exp(-dot(p - vec2(0.4, 0.2), p - vec2(0.4, 0.2)) * 5.0);
	vec2 dust_cell = floor(p * 24.0);
	vec2 dust_local = fract(p * 24.0) - vec2(hash(dust_cell), hash(dust_cell + 17.0));
	float stars = step(0.97, hash(dust_cell + 31.0)) * exp(-dot(dust_local, dust_local) * 1700.0);
	col += vec3(0.13, 0.16, 0.14) * stars;
	vec2 cast_delta = (uv - player_uv) * resolution / min(resolution.x, resolution.y);
	col += school_color.rgb * exp(-length(cast_delta) * 14.0) * activity * 0.025;
	col += (hash(floor(uv * resolution)) - 0.5) * 0.00025;
	col *= 1.0 - 0.25 * smoothstep(0.25, 0.8, length(uv - 0.5));
	COLOR = vec4(col, 1.0);
}

void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * (COLOR.rgb + vec3(.012)), LIGHT_COLOR.a);
}
