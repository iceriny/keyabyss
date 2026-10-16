shader_type canvas_item;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 school_color : source_color = vec4(.6,.8,1.,1.);
uniform float blur_pixels = 0.0;
uniform float brightness = 1.0;
uniform float hover = 0.0;
uniform float artwork_size = 390.0;
uniform float awakening : hint_range(0.0, 1.0) = 1.0;
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }

vec4 book(vec2 uv, float lod) {
	vec4 sample_color = textureLod(artwork, clamp(uv, vec2(0.), vec2(1.)), lod);
	// Blurred mip texels have a footprint outside the source image. A binary UV
	// cutoff turns that footprint into a rectangular shadow/glow boundary.
	vec2 feather = vec2(exp2(lod) * 1.25 + 0.5) / vec2(textureSize(artwork, 0));
	vec2 edge = min(uv, 1.0 - uv);
	sample_color.a *= smoothstep(-feather.x, feather.x, edge.x) * smoothstep(-feather.y, feather.y, edge.y);
	return sample_color;
}
vec4 premultiplied_book(vec2 uv, float lod) {
	vec4 c = book(uv, lod);
	return vec4(c.rgb * c.a, c.a);
}
vec4 depth_blur(vec2 uv, float radius, float source_scale) {
	// Mips handle minification; a small Gaussian kernel removes mip-shaped blocks.
	float lod = max(0.0, log2(source_scale * max(1.0, radius * 0.45)));
	if (radius < 0.05) { return book(uv, lod); }
	vec2 step_uv = vec2(radius * 0.65 / max(artwork_size, 1.0));
	vec4 c = premultiplied_book(uv, lod) * 0.25;
	c += premultiplied_book(uv + vec2(step_uv.x, 0.0), lod) * 0.125;
	c += premultiplied_book(uv - vec2(step_uv.x, 0.0), lod) * 0.125;
	c += premultiplied_book(uv + vec2(0.0, step_uv.y), lod) * 0.125;
	c += premultiplied_book(uv - vec2(0.0, step_uv.y), lod) * 0.125;
	c += premultiplied_book(uv + step_uv, lod) * 0.0625;
	c += premultiplied_book(uv - step_uv, lod) * 0.0625;
	c += premultiplied_book(uv + vec2(step_uv.x, -step_uv.y), lod) * 0.0625;
	c += premultiplied_book(uv + vec2(-step_uv.x, step_uv.y), lod) * 0.0625;
	return vec4(c.rgb / max(c.a, 0.0001), c.a);
}
void fragment() {
	vec2 p = (UV - .5) * 1.4 + .5;
	float source_scale = float(textureSize(artwork, 0).x) / max(artwork_size,1.);
	vec4 art = depth_blur(p, blur_pixels, source_scale);
	float shadow_lod = log2(max(1.,20.*source_scale));
	float shadow = book(p-vec2(0.,25./artwork_size), shadow_lod).a * .66;
	float glow = book(p,log2(max(1.,15.*source_scale))).a * (.28+hover*.35) * awakening;
	float alpha = art.a + (1.-art.a) * max(shadow,glow);
	float luminance = dot(art.rgb,vec3(.2126,.7152,.0722));
	vec3 ink = mix(vec3(luminance), art.rgb, .18 + .82 * awakening);
	vec3 rgb = ink * pow(brightness,2.2) * (1.0 + smoothstep(.35,.85,luminance)*.15 * awakening) * art.a + school_color.rgb * pow(glow,2.2) * (1.-art.a);
	COLOR = vec4(rgb / max(alpha,.0001),alpha) * item_modulate;
}

void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * COLOR.rgb * .22, LIGHT_COLOR.a);
}
