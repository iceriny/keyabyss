shader_type canvas_item;
render_mode unshaded;
// One BackBufferCopy before the reading layer; all foreground text is drawn later.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 ink : source_color = vec4(0.018, 0.032, 0.042, 1.0);
uniform float transmission : hint_range(0.0, 1.0) = 0.06;
uniform float shade : hint_range(0.0, 1.0) = 0.025;
uniform float blur_lod : hint_range(0.0, 5.0) = 2.4;
uniform float refraction_pixels : hint_range(0.0, 4.0) = 1.4;
uniform vec2 field_center = vec2(0.5, 0.5);
uniform vec2 field_scale = vec2(2.0, 1.6);
uniform vec4 reading_rect = vec4(0.325, 0.025, 0.35, 0.9);
uniform vec2 light_center = vec2(0.5, 0.2);
uniform float clock = 0.0;
uniform vec4 crystal_light : source_color = vec4(0.64, 0.8, 0.84, 1.0);
uniform vec4 transmitted_light : source_color = vec4(0.88, 0.8, 0.63, 1.0);
uniform float facet_strength : hint_range(0.0, 1.0) = 0.65;
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }

float travelling_glow(float y, float speed, float phase) {
 float center = fract(clock*speed+phase)*1.7-0.35;
 return exp(-pow((y-center)/0.19,2.0))*smoothstep(0.01,0.4,clock);
}
void fragment() {
 vec2 field_uv = (UV - field_center) * field_scale;
 float field = exp(-dot(field_uv, field_uv) * 2.0);
 vec2 sheet = (UV - reading_rect.xy) / reading_rect.zw;
 // Unequal curved facets have individual shoulders and light catches. They
 // belong to one sheet, but never form two parallel luminous rails.
 float left_fold = sheet.x + 0.028 + 0.09*sin(sheet.y*4.3-0.5);
 float right_fold = sheet.x - 1.025 - 0.065*sin(sheet.y*5.2+0.6);
 float left_patch = exp(-pow((sheet.y-0.26)/0.115,2.0)) + 0.25*exp(-pow((sheet.y-0.71)/0.085,2.0));
 float right_patch = 0.75*exp(-pow((sheet.y-0.57)/0.15,2.0)) + 0.18*exp(-pow((sheet.y-0.15)/0.07,2.0));
 float left_flow = travelling_glow(sheet.y,0.045,0.32);
 float right_flow = travelling_glow(sheet.y,0.038,0.64);
 left_patch = left_patch*0.6+left_flow;
 right_patch = right_patch*0.6+right_flow;
 float left_body = exp(-pow(left_fold/0.065,2.0))*left_patch;
 float right_body = exp(-pow(right_fold/0.052,2.0))*right_patch;
 float fold = left_body - right_body;
 vec2 lens = vec2(fold*4.0, -left_body*cos(sheet.y*4.3)*1.6 + right_body*cos(sheet.y*5.2)*1.1);
 vec2 sample_uv = SCREEN_UV + lens * SCREEN_PIXEL_SIZE * refraction_pixels;
 vec2 spread = SCREEN_PIXEL_SIZE * 2.0;
 vec3 behind = textureLod(screen_texture, sample_uv, blur_lod).rgb;
 behind += textureLod(screen_texture, sample_uv + spread, blur_lod).rgb;
 behind += textureLod(screen_texture, sample_uv - spread, blur_lod).rgb;
 behind *= 0.333333;
 // HDR screen samples are linear. Keep the neutral ink in source color space;
 // literal sRGB-looking values here turn a dark veil into an opaque blue wash.
 vec3 glass = behind * mix(shade, transmission, field) + ink.rgb * (0.6 + field * 0.25);
 float vertical_fade = smoothstep(0.0,0.15,sheet.y)*smoothstep(0.0,0.25,1.0-sheet.y);
 float facets = exp(-pow(left_fold/0.007,2.0))*left_patch + exp(-pow(right_fold/0.008,2.0))*right_patch;
 float transmitted_band = exp(-pow((left_fold-0.014)/0.034,2.0))*left_patch + exp(-pow((right_fold+0.018)/0.038,2.0))*right_patch;
 float halo = exp(-pow(left_fold/0.075,2.0))*left_patch + exp(-pow(right_fold/0.070,2.0))*right_patch;
 float pointer_light = exp(-dot((UV-light_center)*vec2(2.0,1.0),(UV-light_center)*vec2(2.0,1.0))*9.0);
 vec3 refracted = textureLod(screen_texture, sample_uv + lens*SCREEN_PIXEL_SIZE*2.0, 0.7).rgb;
 glass += refracted * abs(fold) * vertical_fade * 0.05 * facet_strength;
 glass += (crystal_light.rgb*(facets*0.025+halo*0.012) + transmitted_light.rgb*transmitted_band*0.035) * vertical_fade * (0.8+pointer_light*0.3) * facet_strength;
 COLOR = vec4(glass, 1.0)*item_modulate;
}
