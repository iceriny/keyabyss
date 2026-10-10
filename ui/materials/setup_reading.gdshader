shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 reading_rect = vec4(.35, .17, .3, .66);
uniform vec2 light_center = vec2(.2, .3);
uniform float clock = 0.0;
uniform vec4 ink : source_color = vec4(.02, .038, .045, 1.0);

void fragment() {
	vec2 reading = (UV - reading_rect.xy - reading_rect.zw * .5) / (reading_rect.zw * .65);
	float falloff = dot(reading, reading);
	float veil = exp(-falloff * falloff * .55);
	// Soften the full-resolution encounter before the sharp foreground controls.
	vec3 transmitted = textureLod(screen_texture, SCREEN_UV, mix(1.5, 2.2, veil)).rgb;
	float gleam = exp(-dot(UV - light_center, UV - light_center) * 32.0);
	COLOR *= vec4(transmitted * mix(.68, .30, veil) + ink.rgb * (1.0 + gleam * .1 * min(clock, 1.0)), 1.0);
}
