shader_type canvas_item;
render_mode unshaded;

// Scenery, submerged threads and crystal surface are composed in this pass.
// Text is a separate CanvasItem drawn afterwards.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 highlight : source_color = vec4(0.94, 0.87, 0.68, 1.0);
uniform vec4 crystal : source_color = vec4(0.55, 0.72, 0.77, 1.0);
uniform vec2 light_center = vec2(0.38, 0.3);
uniform float backdrop_gain = 0.06;
uniform float surface_light : hint_range(0.0, 1.0) = 0.6;
uniform bool control_surface = false;
uniform vec2 canvas_size = vec2(160.0, 64.0);
uniform vec4 spine_heights = vec4(48.0, 42.0, 51.0, 48.0);
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float activity = 0.0;
uniform float pulse = 0.0;
varying vec4 item_modulate;

void vertex() { item_modulate = COLOR; }

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float ends = pow(max(0.0, 1.0 - q.x*q.x), 2.0);
	float edge = smoothstep(0.0, 0.14, UV.y) * smoothstep(0.0, 0.14, 1.0-UV.y) * ends;
	// A curved, tapered facet. Its slope gives a coherent refraction direction.
	float bend = 0.19*sin(q.x*2.6) + 0.09*q.x*q.x;
	float ridge = q.y - bend - (control_surface ? 0.35 : 0.0);
	vec2 normal = vec2(-0.494*cos(q.x*2.6)-0.18*q.x, 1.0);
	if (control_surface) {
		float t = clamp((UV.x*canvas_size.x-12.0)/(canvas_size.x-24.0),0.0,1.0);
		float u = 1.0-t;
		float spine = dot(spine_heights, vec4(u*u*u, 3.0*u*u*t, 3.0*u*t*t, t*t*t));
		float slope = 3.0*(u*u*(spine_heights.y-spine_heights.x) + 2.0*u*t*(spine_heights.z-spine_heights.y) + t*t*(spine_heights.w-spine_heights.z))/(canvas_size.x-24.0);
		ridge = (UV.y*canvas_size.y-spine)*2.0/canvas_size.y;
		normal = normalize(vec2(-slope,1.0));
	}
	float thickness = exp(-ridge*ridge*3.2) * ends;
	vec2 ray = normal * ridge * thickness;
	vec2 offset = ray * SCREEN_PIXEL_SIZE * (5.0 + activity*5.0);
	vec3 scenery = textureLod(screen_texture, SCREEN_UV + offset, 1.2).rgb;
	// Tiny dispersion is confined to the facet, not applied to foreground type.
	scenery.r = textureLod(screen_texture, SCREEN_UV + offset*1.08, 1.2).r;
	scenery.b = textureLod(screen_texture, SCREEN_UV + offset*0.92, 1.2).b;
	float proximity = exp(-dot((UV-light_center)*vec2(1.4,1.0), (UV-light_center)*vec2(1.4,1.0))*12.0);
	float travel = fract(clock*mix(0.035,0.048,phase)+phase) * 1.8 - 0.4;
	float beam = exp(-pow((UV.x + UV.y*0.18 - travel)/0.20, 2.0));
	float moving_light = beam * smoothstep(0.01, 0.4, clock) * (control_surface ? 0.55+activity*0.45 : 0.45);
	float illumination = 0.16 + moving_light*0.55 + proximity*activity*0.35 + pulse*0.18;
	float catch_light = exp(-pow((UV.x-0.34)/0.17,2.0)) + 0.35*exp(-pow((UV.x-0.76)/0.11,2.0));
	float face = exp(-pow((ridge+0.20)/0.025,2.0)) * edge * catch_light;
	float caustic = exp(-pow((ridge-0.12)/0.18,2.0)) * edge * (catch_light*0.35+moving_light);
	float gold_alpha = 0.0;
	vec3 gold = vec3(0.0);
	// Authored illustrations retain their image. Controls use arc-length meshes,
	// so the optical surface never repeats an SVG beneath every caption.
	if (!control_surface) {
		vec2 submerged_uv = UV + ray*TEXTURE_PIXEL_SIZE*3.0;
		vec4 thread = texture(TEXTURE, submerged_uv);
		float buried = smoothstep(-0.1, 0.45, ridge)*0.65;
		float soft_thread = (texture(TEXTURE, submerged_uv + TEXTURE_PIXEL_SIZE*1.3).a + texture(TEXTURE, submerged_uv - TEXTURE_PIXEL_SIZE*1.3).a)*0.5;
		gold_alpha = mix(thread.a, soft_thread, buried*0.65) * edge;
		gold_alpha *= (0.22 + illumination*0.7) * (1.0-buried*0.6);
		gold = mix(thread.rgb*0.65, highlight.rgb*1.8, clamp(illumination,0.0,1.0));
	}
	float veil_alpha = thickness * edge * (0.2 + activity*0.18);
	vec3 transmitted = scenery*backdrop_gain + crystal.rgb*0.012;
	vec3 light = (crystal.rgb*face*illumination*0.18 + highlight.rgb*caustic*illumination*0.09) * surface_light;
	float alpha = veil_alpha + gold_alpha*(1.0-veil_alpha);
	vec3 premultiplied = transmitted*veil_alpha + gold*gold_alpha + light;
	COLOR = vec4(premultiplied / max(alpha,0.00001), alpha) * item_modulate;
}
