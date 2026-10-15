// Adapted from gilded-crystal-material-v9's optical path. All six maps are
// linear RGBA16F engineering fields, including alpha; none is an RGB backdrop.
uniform sampler2D structure_a : repeat_disable, filter_linear_mipmap;
uniform sampler2D gradient_a : repeat_disable, filter_linear_mipmap;
uniform sampler2D flow_a : repeat_disable, filter_linear_mipmap;
uniform sampler2D structure_b : repeat_disable, filter_linear_mipmap;
uniform sampler2D gradient_b : repeat_disable, filter_linear_mipmap;
uniform sampler2D flow_b : repeat_disable, filter_linear_mipmap;
uniform vec2 canvas_size = vec2(1920.0, 1080.0);
uniform vec4 reading_rect = vec4(624.0, 26.0, 672.0, 970.0);
uniform vec4 art_a = vec4(220.0, 120.0, 1100.0, 618.75);
uniform vec4 art_b = vec4(800.0, -50.0, 1000.0, 562.5);
uniform vec3 cold_tint = vec3(0.30, 0.78, 1.20);
uniform vec3 warm_tint = vec3(1.18, 1.03, 0.79);
uniform float clock = 0.0;
uniform int quality = 2;
uniform float intensity = 0.65;
uniform bool edge_only = false;
uniform vec2 edge_width = vec2(0.26, 0.20);
uniform float edge_opacity = 0.28;
uniform float reading_transmission = 0.012;
uniform float background_transmission = 0.16;
uniform float outer_transmission = 0.28;
uniform float flow_strength = 2.0;
uniform float normal_motion = 1.0;
uniform float refraction = 1.65;
uniform float dispersion = 2.2;
uniform float roughness = 0.78;
uniform float blur_base_px = 3.5;
uniform float blur_flow_px = 5.0;
uniform float blur_clear_px = 1.1;
uniform float blur_flow_speed = 0.115;
uniform float menu_blur_px = 22.0;
uniform float reflection_strength = 0.7;
// The same switches serve material inspection and targeted GPU regressions.
uniform bool show_flow = true;
uniform bool show_highlights = true;
uniform bool show_refraction = true;
uniform bool show_blur_flow = true;
uniform bool show_reflection = true;
uniform bool show_blur = true;
varying vec4 item_modulate;

void vertex() { item_modulate = COLOR; }

float envelope(vec2 uv) {
	vec2 fade = smoothstep(vec2(0.0), vec2(0.07), uv)
		* (1.0 - smoothstep(vec2(0.90), vec2(1.0), uv));
	return fade.x * fade.y;
}

// The menu veil and its crystal folds share one travelling frost field. A
// clear region samples the original capture; no static blur is underneath it.
// This does not alter depth of field or any material in the source scene.
#include "res://ui/materials/crystal_frost.gdshaderinc"
float menu_frost(vec2 uv) {
	return crystal_frost(uv, clock * float(show_blur_flow), blur_flow_speed) * float(show_blur);
}

float menu_sigma(vec2 uv) {
	return mix(0.25, menu_blur_px, menu_frost(uv)) * float(show_blur);
}

// Cubic B-spline reconstruction uses four bilinear taps. Its positive weights
// keep thin ridges continuous under enlargement without ringing or new halos.
// Radiance is linear RGBA16F, so this filter preserves subpixel light coverage.
vec4 crystal_level(sampler2D field, vec2 uv, float lod) {
	vec2 dimensions = vec2(textureSize(field, int(lod)));
	vec2 p = uv * dimensions - 0.5;
	vec2 f = fract(p), f2 = f * f, f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1, g1 = w2 + w3;
	vec2 p0 = (floor(p) - 0.5 + w1 / g0) / dimensions;
	vec2 p1 = (floor(p) + 1.5 + w3 / g1) / dimensions;
	return textureLod(field, p0, lod) * g0.x * g0.y
		+ textureLod(field, vec2(p1.x, p0.y), lod) * g1.x * g0.y
		+ textureLod(field, vec2(p0.x, p1.y), lod) * g0.x * g1.y
		+ textureLod(field, p1, lod) * g1.x * g1.y;
}

vec4 crystal_structure(sampler2D field, vec2 uv) {
	if (quality == 0) { return texture(field, uv); }
	vec2 dimensions = vec2(textureSize(field, 0));
	vec2 dx = dFdx(uv) * dimensions, dy = dFdy(uv) * dimensions;
	float lod = max(0.0, floor(log2(max(max(length(dx), length(dy)), 1.0))));
	return crystal_level(field, uv, lod);
}

vec4 background_sample(vec2 p, float lod) {
#ifdef CRYSTAL_SCENE_SOURCE
	// HDR stage textures have no mip chain; the five spatial taps supply softness.
	return texture(screen_tex, p);
#else
	return textureLod(screen_tex, p, lod);
#endif
}

vec3 softened(vec2 p, float lod, float radius, vec2 pixel) {
#ifdef CRYSTAL_SCENE_SOURCE
	radius *= 2.6;
#endif
	vec2 lo = pixel, hi = vec2(1.0) - pixel;
	vec3 result = background_sample( clamp(p, lo, hi), lod).rgb;
	if (quality > 0) {
		vec2 d = pixel * radius;
		result *= 0.40;
		result += background_sample( clamp(p + vec2(d.x, 0.0), lo, hi), lod).rgb * 0.15;
		result += background_sample( clamp(p - vec2(d.x, 0.0), lo, hi), lod).rgb * 0.15;
		result += background_sample( clamp(p + vec2(0.0, d.y), lo, hi), lod).rgb * 0.15;
		result += background_sample( clamp(p - vec2(0.0, d.y), lo, hi), lod).rgb * 0.15;
	}
	return result;
}

void sheet(sampler2D structure_map, sampler2D gradient_map, sampler2D flow_map,
		vec2 uv, vec2 screen_uv, vec2 pixel, vec2 reading_uv, float reading,
		float body, float phase, out vec3 optical, out vec3 light, out float coverage) {
	vec4 s = crystal_structure(structure_map, uv);
	if (!edge_only) {
		// Frost scatters the folds' own fine reflections as well as the scene
		// behind them, so its movement remains legible over a quiet backdrop.
		vec2 texel_span = max(abs(dFdx(uv)), abs(dFdy(uv))) * vec2(textureSize(structure_map, 0));
		float frost_lod = log2(max(1.0, max(texel_span.x, texel_span.y) * menu_sigma(screen_uv)));
		vec4 scattered = textureLod(structure_map, uv, frost_lod);
		if (quality > 0) {
			float level = floor(frost_lod);
			scattered = mix(crystal_level(structure_map, uv, level),
				crystal_level(structure_map, uv, level + 1.0), fract(frost_lod));
		}
		s = mix(s, scattered, menu_frost(screen_uv) * 0.78);
	}
	vec4 g = textureLod(gradient_map, uv, 1.0);
	vec4 flow = texture(flow_map, uv);
	float edge = envelope(uv);
	float t = clock + phase;
	float presence = s.a;
	float broad = s.r;
	float ridge = s.g;
	float travel = fract(t * 0.13 + 0.30);
	float distance_phase = fract(flow.r - travel + 0.5) - 0.5;
	float phase_footprint = fwidth(flow.r);
	float front = max(distance_phase, 0.0) / max(0.038, phase_footprint);
	float tail = min(distance_phase, 0.0) / max(0.12, phase_footprint);
	float pulse = exp(-front * front - tail * tail);
	float soft = 0.5 + 0.5 * sin(6.283185 * flow.g - t * 0.80 + 0.35 * sin(t * 0.29 + uv.x * 4.0));
	float active = float(show_flow) * flow_strength;
	float flowmask = smoothstep(0.015, 0.45, flow.b);

	// Two phase-offset samples advect normals continuously, with no wrap pop.
	vec2 tangent = normalize(vec2(dFdx(flow.r), dFdy(flow.r)) + vec2(0.000001));
	vec2 uv_pixel = dFdx(uv) * tangent.x + dFdy(uv) * tangent.y;
	float a = fract(t * 0.07), b = fract(a + 0.5);
	float wa = 0.5 - 0.5 * cos(6.283185 * a);
	vec2 ga = textureLod(gradient_map, uv - uv_pixel * 4.0 * (a - 0.5), 1.0).rg;
	vec2 gb = textureLod(gradient_map, uv - uv_pixel * 4.0 * (b - 0.5), 1.0).rg;
	vec2 animated_rg = mix(g.rg, ga * wa + gb * (1.0 - wa), float(show_flow) * normal_motion * flow.a);
	vec2 gradient = (animated_rg - 0.5) * 1.4;
	vec2 ripple = vec2(sin(flow.g * 6.283 - t * 0.85), cos(flow.r * 6.283 - t * 0.62));
	gradient += ripple * 0.035 * flow.a * normal_motion * float(show_flow);
	gradient *= edge;
	// A broad optical membrane continues between the folds and fades into space.
	// No container SDF, closed contour, bevel, or opaque rectangular panel.
	float body_time = clock * float(show_flow);
	vec2 body_gradient = vec2(0.065 * sin(reading_uv.y * 4.0 - body_time * 0.48),
		0.045 * cos(reading_uv.x * 3.0 + body_time * 0.37));
	gradient += body * (vec2(0.035, -0.02) + body_gradient);

	vec3 normal = normalize(vec3(-gradient, 1.0));
	vec3 reflection = reflect(vec3(0.0, 0.0, -1.0), normal);
	float fresnel = 0.04 + 0.96 * pow(1.0 - normal.z, 5.0);
	float thickness = max(g.b * 0.6 * presence * edge, 0.24 * body);
	float optical_presence = textureLod(structure_map, uv, 2.2).a;
	float optical_sheet = textureLod(gradient_map, uv, 2.2).a;
	float surface = max(smoothstep(0.035, 0.45, max(optical_presence, optical_sheet)) * edge, body);

	// Demo roughness transport: advect the authored flow mask along its tangent.
	float rough_phase = flow.g * 1.7 + 0.14 * sin(flow.r * 7.0) - t * blur_flow_speed;
	float rough_band = smoothstep(0.14, 0.86, 0.5 + 0.5 * cos(6.283185 * rough_phase));
	float ra = fract(t * blur_flow_speed * (0.07 / 0.115)), rb = fract(ra + 0.5);
	float rw = 0.5 - 0.5 * cos(6.283185 * ra);
	float ma = textureLod(flow_map, uv - uv_pixel * 96.0 * (ra - 0.5), 2.5).b;
	float mb = textureLod(flow_map, uv - uv_pixel * 96.0 * (rb - 0.5), 2.5).b;
	float advected_mask = ma * rw + mb * (1.0 - rw);
	float travelling_roughness = smoothstep(0.08, 0.70, advected_mask * 0.75 + rough_band * 0.25);
	float rough_motion = mix(0.5, travelling_roughness, float(show_blur_flow));
	float window_phase = fract(t * blur_flow_speed + 0.08);
	vec2 window_center = vec2(0.08 + 0.80 * window_phase, 0.68 - 0.15 * window_phase);
	vec2 window_d = (uv - window_center) / vec2(0.11, 0.24);
	float clear_window = exp(-pow(abs(window_d.x), 4.0) - pow(abs(window_d.y), 4.0));
	clear_window *= smoothstep(0.0, 0.07, window_phase) * (1.0 - smoothstep(0.86, 1.0, window_phase)) * float(show_blur_flow);

	vec2 geometric_offset = gradient * 22.0 * refraction * (0.35 + 0.65 * sqrt(clamp(g.b, 0.0, 1.0))) * (0.82 + 0.45 * rough_motion);
	geometric_offset *= min(1.0, 14.0 / max(length(geometric_offset), 0.00001));
	vec2 offset = geometric_offset * surface * float(show_refraction);
	vec2 split = geometric_offset * 0.095 * dispersion;
	split *= min(1.0, 1.55 / max(length(split), 0.00001));
	split *= surface * float(quality == 2 && show_refraction);
	vec2 center = screen_uv + offset * pixel;
	float rough_radius = mix(blur_base_px + blur_flow_px * rough_motion, min(blur_clear_px, blur_base_px + blur_flow_px * rough_motion), clear_window);
	float sigma = rough_radius * pow(roughness / 0.78, 2.0) * (0.70 + 0.30 * sqrt(g.b)) * surface;
	sigma *= mix(1.0, 0.78, smoothstep(0.025, 0.20, broad + ridge));
	sigma = (edge_only ? sigma : menu_sigma(screen_uv)) * float(show_blur);
	float lod = edge_only ? clamp(log2(max(sigma, 1.0)) - 1.0, 0.0, 2.8)
		: clamp(log2(max(sigma, 1.0)) - 0.35, 0.0, 4.5);
	vec3 through = softened(center, lod, sigma * 0.35, pixel);
	if (quality == 2) {
		through.r = softened(center + split * pixel, lod, sigma * 0.35, pixel).r;
		through.b = softened(center - split * pixel, lod, sigma * 0.35, pixel).b;
	}
	through *= exp(-vec3(0.17, 0.09, 0.055) * thickness);
	// Transmission is sampled BEFORE the reading veil. The old full-screen
	// blur floor and dark multiplier must not erase these optical differences.
	optical = through * (edge_only ? 0.88 : mix(outer_transmission, reading_transmission, reading)) * (1.0 - fresnel * presence * 0.35);

	vec3 tint = mix(cold_tint, warm_tint, s.b);
	tint = mix(tint, vec3(1.08, 1.045, 0.97), smoothstep(0.10, 0.65, broad + ridge) * 0.88);
	float plane_response = max(0.15, 0.78 + active * flowmask * (soft * 0.36 - 0.18));
	float ridge_response = 0.36 + active * flowmask * pulse * 0.42;
	float static_hotspot = mix(1.0, 0.55, smoothstep(0.055, 0.3, broad + ridge));
	vec3 reflected = broad * plane_response * tint * intensity * static_hotspot;
	vec3 highlights = ridge * ridge_response * tint * intensity * static_hotspot;
	reflected += active * flowmask * pulse * broad * tint * 0.28 * intensity;
	// Finite gain near black: sqrt(ridge) previously amplified barely visible
	// texels into white stair steps and crawling noise along every thin crease.
	float glint = ridge / (0.16 + sqrt(max(ridge, 0.0)));
	highlights += active * flowmask * pulse * glint * vec3(1.12, 1.045, 0.90) * intensity;
	vec2 lamp = vec2(0.25 * sin(t * 0.19), 0.20 * cos(t * 0.16));
	float angular = exp(-dot((reflection.xy - lamp) * 2.0, (reflection.xy - lamp) * 2.0));
	reflected += fresnel * vec3(0.08, 0.18, 0.28) * angular * presence * 0.5;
	vec3 environment = background_sample( clamp(screen_uv + reflection.xy * 0.22, pixel, vec2(1.0) - pixel), roughness * 3.0).rgb;
	reflected += environment * fresnel * reflection_strength * surface * (1.0 + angular) * 0.45;
	light = (reflected * float(show_reflection) + highlights * float(show_highlights)) * edge * (1.0 - reading * 0.94);
	coverage = surface;
}

void fragment() {
	vec2 point = UV * canvas_size;
	vec2 border_distance = min(UV, vec2(1.0) - UV);
	vec2 edge_fade = 1.0 - smoothstep(vec2(0.0), edge_width, border_distance);
	float periphery = max(edge_fade.x, edge_fade.y);
	if (edge_only && periphery < 0.001) { discard; }
	vec2 reading_uv = (point - reading_rect.xy) / reading_rect.zw;
	vec2 reading_distance = (reading_uv - 0.5) / vec2(0.61, 0.64);
	float reading = float(!edge_only) * exp(-pow(abs(reading_distance.x), 4.0) - pow(abs(reading_distance.y), 6.0));
	vec2 body_distance = (reading_uv - 0.5) / vec2(0.82, 0.82);
	float body = float(!edge_only) * exp(-dot(body_distance, body_distance) * 1.5);
	vec3 optical_a, optical_b, light_a, light_b;
	float coverage_a, coverage_b;
	sheet(structure_a, gradient_a, flow_a, (point - art_a.xy) / art_a.zw,
		SCREEN_UV, SCREEN_PIXEL_SIZE, reading_uv, reading, body, 0.0, optical_a, light_a, coverage_a);
	sheet(structure_b, gradient_b, flow_b, (point - art_b.xy) / art_b.zw,
		SCREEN_UV, SCREEN_PIXEL_SIZE, reading_uv, reading, 0.0, 3.7, optical_b, light_b, coverage_b);
	float sigma = menu_sigma(SCREEN_UV);
	float lod = clamp(log2(max(sigma, 1.0)) - 0.35, 0.0, 4.5);
	vec3 background = softened(SCREEN_UV, lod, sigma * 0.35, SCREEN_PIXEL_SIZE)
		* mix(background_transmission, 0.009, reading);
	vec3 result = mix(background, optical_a, coverage_a);
	result = mix(result, optical_b, coverage_b * (1.0 - body * 0.45));
	result += light_a + light_b + vec3(0.0013, 0.0022, 0.0027);
	if (edge_only) {
		float coverage = max(coverage_a, coverage_b);
		vec3 transmitted = mix(optical_a, optical_b, coverage_b / max(coverage_a + coverage_b, 0.001));
		vec3 lit = transmitted + (light_a + light_b) / max(coverage, 0.08);
		COLOR = vec4(lit, coverage * periphery * edge_opacity) * item_modulate;
	} else {
		COLOR = vec4(result, 1.0) * item_modulate;
	}
}
