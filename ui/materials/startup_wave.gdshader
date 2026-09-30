shader_type canvas_item;
render_mode unshaded;
// One HDR viewport sample; the lens and luminous rim share a wavefront.
uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform vec2 wave_center = vec2(960.0, 518.4);
uniform float wave_radius = 0.0;
uniform float wave_energy : hint_range(0.0, 1.0) = 0.0;
uniform float strength_pixels : hint_range(0.0, 80.0) = 18.0;
uniform float band_width : hint_range(4.0, 120.0) = 28.0;
uniform float flare : hint_range(0.0, 4.0) = 0.0;
uniform vec4 light_color : source_color = vec4(0.68, 0.83, 1.0, 1.0);
varying vec4 item_modulate;
void vertex() {
	item_modulate = COLOR;
}
void fragment() {
	vec2 radial = UV * viewport_size - wave_center;
	float radius = length(radial);
	vec2 normal = radial / max(radius, 1.0);
	float width = max(band_width, fwidth(radius) * 2.0);
	float q = (radius - wave_radius) / width;
	float envelope = exp(-q * q * 0.5);
	// Bounded gradient refraction avoids folding at the crest.
	float offset = -q * envelope * min(strength_pixels, width * 0.65) * wave_energy;
	vec2 sample_uv = clamp(UV + normal * offset / viewport_size, TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5);
	vec4 stage = texture(TEXTURE, sample_uv);
	float crest = exp(-q * q * 24.0);
	float halo = exp(-q * q * 0.18);
	float core = exp(-dot(radial, radial) / 26000.0);
	vec3 emission = light_color.rgb * (crest * 0.14 + halo * 0.012) * wave_energy;
	emission += light_color.rgb * core * flare * 0.045;
	COLOR = vec4(stage.rgb + emission, stage.a) * item_modulate;
}
