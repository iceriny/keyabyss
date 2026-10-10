shader_type canvas_item;
render_mode unshaded;
uniform vec2 canvas_size = vec2(1920.0, 1080.0);
uniform vec2 wave_center = vec2(960.0, 500.0);
uniform float wave_progress = 1.0;
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }
void fragment() {
	vec2 p = UV * canvas_size - wave_center;
	float r = length(p);
	float t = wave_progress;
	float farthest = length(max(wave_center, canvas_size - wave_center));
	float radius = mix(80.0, farthest + 100.0, 1.0 - pow(1.0 - t, 1.6));
	float width = mix(38.0, 76.0, t);
	float q = (r - radius) / width;
	float envelope = smoothstep(0.0, 0.09, t) * (1.0 - smoothstep(0.55, 1.0, t));
	vec2 shift = p / max(r, 1.0) * (-q * exp(-q*q*0.5)) * 24.0 * envelope;
	vec2 uv = clamp(UV + shift / canvas_size, TEXTURE_PIXEL_SIZE, vec2(1.0) - TEXTURE_PIXEL_SIZE);
	COLOR = texture(TEXTURE, uv) * item_modulate;
}
