shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(194.0, 52.0);
uniform float word_line_y = 32.0;
uniform float selection = 0.0;
uniform float cursor_start = 0.0;
uniform float cursor_width = 0.0;
uniform bool glyph_pass = false;
uniform sampler2D scene_behind : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 idle_rule : source_color = vec4(0.62, 0.75, 0.74, 1.0);
uniform vec4 active_rule : source_color = vec4(0.86, 0.78, 0.58, 1.0);
varying vec4 glyph_ink;

void vertex() { glyph_ink = COLOR; }

void fragment() {
	if (glyph_pass) {
		// Font outline quads supply the padding for a soft glyph-shaped shadow.
		// Their black vertex tint distinguishes them from the unchanged text pass.
		if (dot(glyph_ink.rgb, vec3(1.0)) < .001) {
			vec2 pixel = SCREEN_PIXEL_SIZE * 3.0;
			vec3 background = textureLod(scene_behind, SCREEN_UV, 2.0).rgb * .4;
			background += textureLod(scene_behind, SCREEN_UV + vec2(pixel.x, 0), 2.0).rgb * .15;
			background += textureLod(scene_behind, SCREEN_UV - vec2(pixel.x, 0), 2.0).rgb * .15;
			background += textureLod(scene_behind, SCREEN_UV + vec2(0, pixel.y), 2.0).rgb * .15;
			background += textureLod(scene_behind, SCREEN_UV - vec2(0, pixel.y), 2.0).rgb * .15;
			float strength = smoothstep(.09, .38, dot(background, vec3(.2126, .7152, .0722)));
			vec2 texel = TEXTURE_PIXEL_SIZE;
			vec2 uv = UV - vec2(0, .7) * texel;
			float soft = texture(TEXTURE, uv).a * .36;
			soft += texture(TEXTURE, uv + vec2(1.2, 0) * texel).a * .16;
			soft += texture(TEXTURE, uv - vec2(1.2, 0) * texel).a * .16;
			soft += texture(TEXTURE, uv + vec2(0, 1.2) * texel).a * .16;
			soft += texture(TEXTURE, uv - vec2(0, 1.2) * texel).a * .16;
			COLOR = vec4(.006, .012, .016, soft * strength * .88 * glyph_ink.a);
		} else {
			COLOR = texture(TEXTURE, UV) * glyph_ink;
		}
	} else {
	vec2 p = UV*canvas_size-vec2(12.0,9.0);
	vec2 q = (UV-0.5)*2.0;
	float ends = pow(max(0.0,1.0-q.x*q.x),3.0);
	float line = exp(-pow((p.y-word_line_y)/max(0.5,fwidth(p.y)*0.6),2.0))*ends;
	float cursor = smoothstep(cursor_start-0.5,cursor_start+0.5,p.x)*(1.0-smoothstep(cursor_start+cursor_width-0.5,cursor_start+cursor_width+0.5,p.x));
	float rule_alpha = line*mix(0.25,0.55,selection);
	rule_alpha = max(rule_alpha,line*cursor*step(0.1,cursor_width)*0.85);
	COLOR *= vec4(mix(idle_rule.rgb,active_rule.rgb,selection),rule_alpha);
	}
}
