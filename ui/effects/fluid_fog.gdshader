shader_type canvas_item;
uniform sampler2D field_texture : filter_linear, repeat_disable;
uniform sampler2D density_texture : filter_linear, repeat_disable;
uniform sampler2D matter_texture : filter_linear, repeat_disable;
uniform sampler2D boundary_texture : filter_nearest, repeat_disable;
uniform sampler2D domain_mask : filter_linear, repeat_disable;
uniform bool masked = false;
uniform vec4 fog_color : source_color = vec4(0.36, 0.55, 0.62, 1.0);
uniform vec4 light_color : source_color = vec4(0.85, 0.76, 0.55, 1.0);
uniform float opacity = 0.12;
uniform float scattering = 0.6;
uniform int light_samples = 4;
uniform vec2 domain_size = vec2(1920.0, 1080.0);
uniform float edge_fade = 0.07;
uniform float center_clear = 0.3;
uniform vec4 screen_to_uv_basis;
varying float fog_presence;

void fragment() {
	vec2 mist = texture(density_texture, UV).rg;
	float density = mist.r;
	vec2 aspect = domain_size / min(domain_size.x, domain_size.y);
	vec2 edge = min(UV, 1.0 - UV);
	float fade = edge_fade > 0.0 ? smoothstep(0.0, edge_fade, min(edge.x, edge.y)) : 1.0;
	float reading = mix(1.0 - center_clear, 1.0, smoothstep(0.15, 0.6, length((UV - 0.5) * aspect)));
	float mask = masked ? texture(domain_mask, UV).r : 1.0;
	fog_presence = (1.0 - exp(-density)) * opacity * fade * reading * mask;
	vec3 color = density > 0.0001 ? texture(matter_texture, UV).rgb / density : fog_color.rgb;
	color += color * max(mist.g, 0.0) * 0.1;
	COLOR = vec4(color, fog_presence);
}

void light() {
	// Godot's actual light position, tint, energy and radial texture drive scattering.
	vec2 light_uv = UV + mat2(screen_to_uv_basis.xy, screen_to_uv_basis.zw) * (LIGHT_POSITION.xy - FRAGCOORD.xy);
	if (LIGHT_IS_DIRECTIONAL) {
		vec2 toward_light = mat2(screen_to_uv_basis.xy, screen_to_uv_basis.zw) * LIGHT_DIRECTION.xy;
		light_uv = UV + toward_light / max(length(toward_light), 0.0001) * 1.5;
	}
	float optical_depth = 0.0;
	bool outside_emitter = false;
	for (int i = 0; i < 8; i++) {
		if (i >= light_samples) break;
		vec2 sample_uv = mix(light_uv, UV, (float(i) + 0.5) / float(light_samples));
		if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThanEqual(sample_uv, vec2(1.0)))) {
			optical_depth += texture(density_texture, sample_uv).r;
			float solid = texture(boundary_texture, sample_uv).z;
			// An emissive body lights the air outside itself; subsequent solids occlude.
			outside_emitter = outside_emitter || solid < 0.5;
			if (outside_emitter) optical_depth += solid * 12.0;
		}
	}
	float transmission = exp(-optical_depth * length((UV - light_uv) * domain_size) / 180.0 / float(max(light_samples, 1)));
	// CanvasItem blending applies the fragment's density alpha to this light too.
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * scattering * transmission * mix(vec3(1.0), COLOR.rgb, 0.3), LIGHT_COLOR.a);
}
