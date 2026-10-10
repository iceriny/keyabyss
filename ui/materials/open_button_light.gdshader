shader_type canvas_item;
render_mode unshaded;
uniform vec2 canvas_size = vec2(180.0, 72.0);
uniform vec4 accent : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform vec4 gold_tint : source_color = vec4(0.88, 0.75, 0.51, 1.0);
uniform float activity = 0.0;
uniform float selection = 0.0;
uniform float press = 0.0;
uniform float text_center_x = 72.0;
uniform float text_half_width = 36.0;
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }
void fragment() {
	vec2 p = UV * canvas_size;
	float distance_from_center = abs(p.x - text_center_x);
	float text_x = distance_from_center / (text_half_width + 20.0);
	float text_y = (p.y - canvas_size.y * 0.5) / 17.0;
	float text_halo = exp(-text_x*text_x*2.0 - text_y*text_y);
	// Curves and travelling light live in the arc-length filament mesh.
	float glow = activity * text_halo * (0.012 + selection * 0.004);
	float light = glow * (1.0 + press * 0.3);
	vec2 edge = min(p, canvas_size - p);
	light *= smoothstep(0.0, 28.0, min(edge.x, edge.y));
	vec3 color = mix(gold_tint.rgb, accent.rgb, 0.12);
	COLOR = vec4(color, light) * item_modulate;
}
