shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(1920.0, 1080.0);
uniform float clock = 0.0;
uniform float dust_amount = 0.25;
// Linear density data: periodic clustered points, filtered at the pixel scale.
uniform sampler2D dust_field : repeat_enable, filter_linear_mipmap;

vec2 hash2(vec2 p) {
	// Shared lattice corners must hash identically from either neighbouring cell.
	// The sin/dot float hash produced mismatched corners on the target GPU,
	// exposing straight seams. Integer mixing keeps those corners exact.
	uvec2 cell = uvec2(ivec2(p));
	uvec2 h = uvec2(cell.x * 1597334677u ^ cell.y * 3812015801u);
	h ^= uvec2(0x68bc21ebu, 0x02e5be93u);
	h = (h ^ (h >> 16u)) * 0x7feb352du;
	h = (h ^ (h >> 15u)) * 0x846ca68bu;
	h ^= h >> 16u;
	return vec2(h >> 8u) * (1.0 / 16777216.0);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1, 0)).x, u.x),
		mix(hash2(i + vec2(0, 1)).x, hash2(i + vec2(1)).x, u.x), u.y);
}

float motes(vec2 p, float density, float speed, float grain_size) {
	vec2 grid = p * density + vec2(clock * speed * 0.18, -clock * speed);
	vec2 cell = floor(grid);
	vec2 seed = hash2(cell);
	vec2 d = fract(grid) - (0.15 + seed * 0.7);
	float radius = max(mix(0.55, 1.0, seed.x) * grain_size, fwidth(grid.x) * 0.45);
	float light = exp(-dot(d, d) / (radius * radius));
	float haze = exp(-dot(d, d) / (radius * radius * 12.0)) * 0.08;
	return (light + haze) * pow(seed.y, 7.0) * (0.7 + 0.3 * sin(clock * 0.3 + seed.x * 50.0));
}

vec2 dust_flow(vec2 p, float phase) {
	// Oblique travelling waves deform the *point coordinates*, transporting
	// clusters and their empty spaces together rather than revealing a fixed grid.
	vec2 q = p + clock * vec2(0.0032 + sin(phase) * 0.001, -0.0019 + cos(phase) * 0.002);
	q += vec2(0.035, 0.047) * sin(dot(p, vec2(3.7, -2.8)) + clock * 0.16 + phase);
	q += vec2(-0.022, 0.018) * sin(dot(p, vec2(6.1, 4.3)) - clock * 0.11 + phase * 1.7);
	return q;
}

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.385)) * canvas_size / canvas_size.y;
	float r = length(p);
	float cloud = noise(p * 5.0 + vec2(clock * 0.004, 0.0));
	cloud = cloud * 0.65 + noise(p * 12.0 - clock * 0.002) * 0.25 + noise(p * 28.0) * 0.1;
	float halo = exp(-r * r * 8.0);
	vec3 ink = vec3(0.0005, 0.0018, 0.0025);
	ink += vec3(0.012, 0.015, 0.011) * halo;
	ink += vec3(0.0009, 0.0015, 0.0014) * cloud * exp(-r * r * 1.8);
	ink += vec3(0.008, 0.006, 0.0025) * exp(-r * r * 75.0);
	vec2 flow = dust_flow(p, 0.0);
	vec2 deep_flow = dust_flow(p, 2.3);
	// Broad moving illumination only locates the dust around the seal. Actual
	// particle counts, clustering and voids are baked into the sampled field.
	vec2 left = p - vec2(-0.45 + 0.035 * sin(clock * 0.09), 0.035 + 0.045 * sin(clock * 0.13));
	vec2 right = p - vec2(0.46 + 0.04 * sin(clock * 0.08 + 2.0), 0.04 + 0.05 * sin(clock * 0.11 + 1.0));
	float veil = exp(-dot(left / vec2(0.24, 0.19), left / vec2(0.24, 0.19)));
	veil += exp(-dot(right / vec2(0.25, 0.18), right / vec2(0.25, 0.18)));
	veil += exp(-pow((r - 0.36) * 5.0, 2.0)) * 0.07;
	vec2 uv_a = mat2(vec2(0.83, 0.56), vec2(-0.56, 0.83)) * flow + vec2(0.31, 0.67);
	vec2 uv_b = mat2(vec2(0.61, -0.79), vec2(0.79, 0.61)) * deep_flow * 1.37 + vec2(0.73, 0.19);
	float fine = texture(dust_field, uv_a).r * 0.24 + texture(dust_field, uv_b).r * 0.14;
	fine *= veil;
	float near = motes(p, 9.0, 0.008, 0.025) * 0.13;
	ink += vec3(0.0028, 0.0020, 0.0008) * veil * dust_amount;
	ink += vec3(0.55, 0.34, 0.12) * (fine + near) * dust_amount;
	COLOR = vec4(ink, 1.0);
}
