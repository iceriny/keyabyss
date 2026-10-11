shader_type canvas_item;
render_mode unshaded;
// One BackBufferCopy before the reading layer; all foreground text is drawn later.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 ink : source_color = vec4(0.018, 0.032, 0.042, 1.0);
uniform float transmission : hint_range(0.0, 1.0) = 0.06;
uniform float shade : hint_range(0.0, 1.0) = 0.025;
uniform float blur_lod : hint_range(0.0, 5.0) = 2.4;
uniform vec2 field_center = vec2(0.5, 0.5);
uniform vec2 field_scale = vec2(2.0, 1.6);
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }

void fragment() {
 vec2 field_uv = (UV - field_center) * field_scale;
 float field = exp(-dot(field_uv, field_uv) * 2.0);
 // Folded geometry and local refraction live in CrystalSheets, outside the text.
 vec2 sample_uv = SCREEN_UV;
 vec2 spread = SCREEN_PIXEL_SIZE * 2.0;
 vec3 behind = textureLod(screen_texture, sample_uv, blur_lod).rgb;
 behind += textureLod(screen_texture, sample_uv + spread, blur_lod).rgb;
 behind += textureLod(screen_texture, sample_uv - spread, blur_lod).rgb;
 behind *= 0.333333;
 // HDR screen samples are linear. Keep the neutral ink in source color space;
 // literal sRGB-looking values here turn a dark veil into an opaque blue wash.
 vec3 glass = behind * mix(shade, transmission, field) + ink.rgb * (0.6 + field * 0.25);
 COLOR = vec4(glass, 1.0)*item_modulate;
}
