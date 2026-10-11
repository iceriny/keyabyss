shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// The page's existing capture precedes both the reading veil and these leaves.
// Premultiplied coverage preserves reflections from previously drawn leaves.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 cold : source_color = vec4(0.52, 0.70, 0.74, 1.0);
uniform vec4 gold : source_color = vec4(0.88, 0.74, 0.46, 1.0);
uniform float clock = 0.0;
uniform float arrival : hint_range(0.0, 1.0) = 1.0;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float refraction_pixels = 2.4;
uniform float dispersion_pixels = 0.22;
varying vec3 face_normal;
varying float coverage;
varying float pixel_scale;

void vertex() {
	face_normal = COLOR.rgb * 2.0 - 1.0;
	coverage = COLOR.a;
	pixel_scale = length(CANVAS_MATRIX[0].xy);
	COLOR = vec4(1.0);
}

float bell(float x, float width) {
	return exp(-x * x / (width * width));
}

void fragment() {
	float s = UV.x;
	float v = UV.y;
	// Continuous spatial pulse: the periodic seam lies in the dark tail.
	float distance = mod(s - clock * 14.0 + 240.0, 960.0) - 480.0;
	float flow = bell(distance, distance < 0.0 ? 72.0 : 18.0);
	vec3 n = normalize(face_normal + vec3(0.008 * sin(clock * 0.19 + s * 0.009), 0.012 * sin(clock * 0.23 + s * 0.012), 0.0));
	vec3 reflected = reflect(vec3(0.0, 0.0, -1.0), n);
	float broad = bell(reflected.x + 0.36, 0.7) * bell(reflected.y - 0.08, 0.38);
	float sharp = bell(reflected.x + reflected.y * 0.7 - 0.5 - 0.025 * sin(clock * 0.17), 0.12);
	float fresnel = 0.04 + 0.96 * pow(1.0 - n.z, 5.0);
	float edge_fade = smoothstep(0.0, 0.055, v) * (1.0 - smoothstep(0.82, 1.0, v));
	float patch = 0.38 + 0.62 * pow(0.5 + 0.5 * sin(s * 0.026), 3.0);
	float mask = coverage * edge_fade * arrival;
	vec2 bend = n.xy / max(n.z, 0.45) * SCREEN_PIXEL_SIZE * pixel_scale;
	vec2 sample_uv = SCREEN_UV + bend * refraction_pixels;
	vec3 transmitted;
	transmitted.r = textureLod(screen_texture, sample_uv + bend * dispersion_pixels, 0.7).r;
	transmitted.g = textureLod(screen_texture, sample_uv, 0.7).g;
	transmitted.b = textureLod(screen_texture, sample_uv - bend * dispersion_pixels, 0.7).b;
	float ridge_width = max(fwidth(v) * 0.7, 0.006);
	float ridge = bell(v - 0.5, ridge_width);
	float thread = ridge * pow(patch, 3.0) * (0.08 + flow * 0.75);
	float face = (0.01 + broad * 0.04 + sharp * 0.085) * patch * (0.65 + flow * 1.2);
	vec3 light = cold.rgb * face * (1.0 + fresnel) + gold.rgb * thread * 0.26;
	// Wide, low-energy shoulder around the gold fold, bounded inside the membrane.
	light += gold.rgb * bell(v - 0.5, 0.16) * flow * patch * 0.005;
	float alpha = mask * 0.13;
	COLOR = vec4(transmitted * 0.07 * alpha + light * mask * strength, alpha);
}
