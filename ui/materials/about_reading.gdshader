shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 reading_rect = vec4(.3, .025, .4, .9);
uniform vec2 light_center = vec2(.5, .2);
uniform float clock = 0.0;
uniform vec4 ink : source_color = vec4(.025, .048, .055, 1.0);

void fragment() {
	vec2 page = (UV - reading_rect.xy) / reading_rect.zw;
	// The reading space dissolves well outside the text column. It has no
	// enclosing edge; the archive remains visible around and through it.
	vec2 edge = abs(page - .5);
	float veil = (1.0 - smoothstep(.46, .72, edge.x)) * (1.0 - smoothstep(.47, .64, edge.y));
	vec2 spread = SCREEN_PIXEL_SIZE * 6.0;
	vec3 behind = textureLod(screen_texture, SCREEN_UV, 3.5).rgb * .5;
	behind += textureLod(screen_texture, SCREEN_UV + spread, 3.5).rgb * .25;
	behind += textureLod(screen_texture, SCREEN_UV - spread, 3.5).rgb * .25;
	float light = exp(-dot(UV - light_center, UV - light_center) * 14.0) * min(clock, 1.0);
	COLOR *= vec4(behind * .055 + ink.rgb * (1.0 + light * .12), veil * .97);
}
