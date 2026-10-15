shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ornament : source_color, filter_linear_mipmap, repeat_disable;
// RG: slopes, B: thickness, A: roughness. Linear data, never source_color.
uniform sampler2D optics : filter_linear_mipmap, repeat_disable;
uniform sampler2D glyph_mask : filter_linear, repeat_disable;
// PageShell's original capture, shared by all three choices.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float clock = 0.0;
uniform float backdrop_clock = 0.0;
uniform int quality = 2;
uniform float hover = 0.0;
uniform bool selected = false;
uniform bool details = false;
uniform bool show_refraction = true;
uniform bool show_reflection = true;
uniform vec2 canvas_size = vec2(340.0, 364.0);
uniform vec2 glyph_center = vec2(0.5, 0.34);
uniform float signature = 0.0;
uniform vec4 rarity_color : source_color = vec4(0.65, 0.75, 0.75, 1.0);
varying vec4 item_modulate;

#include "res://ui/materials/crystal_frost.gdshaderinc"

void vertex() { item_modulate = COLOR; }

float engraving(vec2 uv) {
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	return texture(glyph_mask, uv).a * inside;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float selection = float(selected) * exp(-pow((p.y - 0.91) / 0.012, 2.0))
		* (1.0 - smoothstep(0.1, 0.58, abs(p.x))) * 0.24;
	vec3 light = rarity_color.rgb * selection;
	float alpha = selection;
	vec2 local = (UV - glyph_center) * canvas_size;
	if (!details && abs(local.x) < 112.0 && local.y > -78.0 && local.y < 92.0) {
		vec2 q = local / vec2(204.0, 156.0) + vec2(0.5, 0.44);
		float mirror = signature > 0.5 ? -1.0 : 1.0;
		q.x = (q.x - 0.5) * mirror + 0.5;
		vec4 art = texture(ornament, q);
		vec4 field = texture(optics, q);
		float inside = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0);
		art.a *= inside;
		vec2 body_uv = local / vec2(68.0, 57.0);
		float membrane = exp(-dot(body_uv, body_uv) * 2.0);
		float thickness = max(field.b * art.a, membrane * 0.48);
		vec2 slope = (field.rg * 2.0 - 1.0) * vec2(mirror, 1.0);
		slope = mix(body_uv * 0.45 + vec2(0.15, -0.18), slope, art.a);
		slope += vec2(sin(q.y * 5.0 - clock * 0.35), cos(q.x * 4.0 + clock * 0.28)) * thickness * 0.055;
		vec3 normal = normalize(vec3(-slope, 1.0));
		vec3 lamp = normalize(vec3(0.62 * sin(clock * 0.43 + signature * 6.28),
			-0.45 + 0.28 * cos(clock * 0.31 + signature * 3.0), 0.72));
		vec3 half_vector = normalize(lamp + vec3(0.0, 0.0, 1.0));
		float rough = clamp(field.a + 0.08 * sin(q.y * 5.0 - clock * 0.4), 0.2, 0.8);
		float specular = pow(max(dot(normal, half_vector), 0.0), mix(100.0, 22.0, rough));
		float coat = pow(max(dot(normal, half_vector), 0.0), 150.0);
		float fresnel = 0.04 + 0.96 * pow(1.0 - normal.z, 5.0);
		vec2 ray = normal.xy * (3.0 + thickness * 6.0) * float(show_refraction);
		float sigma = max(mix(0.25, 22.0, crystal_frost(SCREEN_UV, backdrop_clock, 0.115)), rough * art.a * 1.5);
		float lod = clamp(log2(max(sigma, 1.0)) - 0.35, 0.0, 4.5);
		vec2 center = SCREEN_UV + ray * SCREEN_PIXEL_SIZE;
		vec3 through = textureLod(screen_texture, center, lod).rgb;
		if (quality > 0) {
			vec2 d = SCREEN_PIXEL_SIZE * sigma * 0.35;
			through = through * 0.4
				+ textureLod(screen_texture, center + vec2(d.x, 0.0), lod).rgb * 0.15
				+ textureLod(screen_texture, center - vec2(d.x, 0.0), lod).rgb * 0.15
				+ textureLod(screen_texture, center + vec2(0.0, d.y), lod).rgb * 0.15
				+ textureLod(screen_texture, center - vec2(0.0, d.y), lod).rgb * 0.15;
		}
		if (quality == 2) {
			vec2 split = normal.xy * SCREEN_PIXEL_SIZE * 0.75 * float(show_refraction);
			through.r = mix(through.r, textureLod(screen_texture, center + split, lod).r, 0.35);
			through.b = mix(through.b, textureLod(screen_texture, center - split, lod).b, 0.35);
		}
		through *= 0.012 * exp(-vec3(0.35, 0.16, 0.08) * thickness);
		float gold = smoothstep(0.015, 0.18, art.r - art.b);
		float radiance = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 tint = mix(vec3(0.42, 0.59, 0.67), vec3(0.76, 0.53, 0.25), gold);
		vec3 reflection = reflect(vec3(0.0, 0.0, -1.0), normal);
		vec3 environment = textureLod(screen_texture, clamp(SCREEN_UV + reflection.xy * 0.12, vec2(0.01), vec2(0.99)), 3.5).rgb;
		float ribbon = exp(-pow((reflection.x + reflection.y * 0.45 - sin(clock * 0.3 + signature * 6.28) * 0.6) / 0.24, 2.0));
		vec3 glass = through + tint * radiance * 0.45;
		glass += (vec3(0.65, 0.80, 0.86) * specular * 0.26
			+ vec3(0.98, 0.88, 0.65) * coat * (0.18 + hover * 0.14)
			+ vec3(0.47, 0.57, 0.61) * ribbon * 0.13 * thickness
			+ environment * fresnel * 0.28) * float(show_reflection);
		glass += vec3(0.22, 0.15, 0.06) * gold * (0.3 + specular * 0.7);
		float coverage = max(art.a * (0.62 + 0.25 * thickness), membrane * 0.42);
		light += glass * coverage;
		alpha += coverage;

		// The live vector is an optical mask, engraved inside the same material.
		// Its bevel, buried shadow and warm reflection share the crystal's lamp.
		vec2 glyph_uv = local / 98.0 + 0.5 + ray * 0.0015;
		vec2 texel = 2.0 / vec2(textureSize(glyph_mask, 0));
		float ink = engraving(glyph_uv);
		vec2 ink_slope = vec2(engraving(glyph_uv + vec2(texel.x, 0.0)) - engraving(glyph_uv - vec2(texel.x, 0.0)),
			engraving(glyph_uv + vec2(0.0, texel.y)) - engraving(glyph_uv - vec2(0.0, texel.y)));
		vec3 ink_normal = normalize(vec3(-ink_slope * 1.6, 0.75));
		float metal = pow(max(dot(ink_normal, half_vector), 0.0), 26.0);
		float buried = engraving(glyph_uv - lamp.xy * texel * 2.4);
		light *= 1.0 - buried * 0.32;
		float bevel = dot(-ink_slope, lamp.xy);
		vec3 inlay = vec3(0.27, 0.185, 0.085) * (1.0 + min(bevel, 0.0) * 0.75);
		inlay += (vec3(0.65, 0.53, 0.30) * metal + vec3(0.72, 0.65, 0.44) * max(bevel, 0.0)) * float(show_reflection);
		inlay += vec3(0.17, 0.11, 0.045) * hover;
		float ink_alpha = ink * 0.96;
		light = light * (1.0 - ink_alpha) + inlay * ink_alpha;
		alpha += ink_alpha * (1.0 - alpha);
	}
	COLOR = vec4(light / max(alpha, 0.001), alpha) * item_modulate;
}
