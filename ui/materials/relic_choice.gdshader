shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float hover = 0.0;
uniform bool selected = false;
uniform bool details = false;
// Reuse PageShell's single background capture; no copy per relic.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 canvas_size = vec2(340.0, 326.0);
uniform vec2 glyph_center = vec2(0.5, 0.17);
uniform float signature = 0.0;
uniform vec4 rarity_color : source_color = vec4(0.65, 0.75, 0.75, 1.0);
uniform bool awakening = false;
uniform int school = 0;
varying vec4 item_modulate;

void vertex() { item_modulate = COLOR; }

float stroke(float distance_value, float width) {
	return exp(-pow(distance_value / width, 2.0));
}

float plane(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	return dot(p - a, vec2(edge.y, -edge.x)) / length(edge);
}

float crystal(vec2 p) {
	float d = plane(p, vec2(-0.72, -0.46), vec2(0.38, -0.78));
	d = max(d, plane(p, vec2(0.38, -0.78), vec2(0.85, -0.23)));
	d = max(d, plane(p, vec2(0.85, -0.23), vec2(0.64, 0.57)));
	d = max(d, plane(p, vec2(0.64, 0.57), vec2(-0.24, 0.82)));
	d = max(d, plane(p, vec2(-0.24, 0.82), vec2(-0.83, 0.18)));
	return max(d, plane(p, vec2(-0.83, 0.18), vec2(-0.72, -0.46)));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wash = exp(-p.x*p.x*5.0-p.y*p.y*2.4);
	float alpha = wash * (0.018 + hover*0.012);
	vec3 light = rarity_color.rgb * 0.24 * alpha;
	// The small, unequal facets belong to the object, never to a card frame.
	vec2 q = (UV - glyph_center) * canvas_size / 64.0;
	float tilt = (signature - 0.5)*0.28;
	q = mat2(vec2(cos(tilt), -sin(tilt)), vec2(sin(tilt), cos(tilt))) * q;
	if (!details) {
		float d = crystal(q);
		float aa = max(fwidth(d), 0.008);
		float mask = 1.0-smoothstep(-aa, aa, d);
		float upper = smoothstep(-aa, aa, -q.y-q.x*0.36-0.16);
		float lower = smoothstep(-aa, aa, q.y-q.x*0.72-0.30);
		float rim = stroke(d+0.012, 0.008+aa) * (0.04+0.96*stroke(q.x+q.y*0.58+0.53, 0.42));
		float facet = upper*0.34 + lower*0.16;
		float glint = stroke(q.x*0.64+q.y*0.77-sin(clock*0.25+signature*4.0)*0.65, 0.15);
		vec2 refraction = vec2(upper-lower, lower*0.6-upper*0.25) * SCREEN_PIXEL_SIZE * 2.4;
		vec3 behind = textureLod(screen_texture, SCREEN_UV+refraction, 1.7).rgb;
		vec3 glass = behind*0.35 + mix(vec3(0.035,0.06,0.07), rarity_color.rgb*0.19, 0.55);
		glass += rarity_color.rgb*(facet*0.4+rim*0.48+glint*0.035)*(0.85+hover*0.2);
		float body = mask*(0.22+facet*0.32+rim*0.28);
		light += glass*body;
		alpha += body;
		// One embedded vein, confined to the lower facet and tapered at both ends.
		float vein = stroke(q.y-0.46+sin(q.x*2.8+0.6)*0.11, 0.009+aa*0.45);
		vein *= smoothstep(-0.75,-0.50,q.x)*(1.0-smoothstep(0.03,0.34,q.x))*mask;
		light += vec3(0.43,0.30,0.13)*vein*0.34;
		alpha += vein*0.16;
	}
	float magic = 0.0;
	vec3 magic_color = rarity_color.rgb;
	if (awakening && !details) {
		// Light stays around the glyph, leaving the reading column clear.
		float radius = length(q);
		float angle = atan(q.y, q.x);
		float ring = stroke(radius - 0.94, 0.022);
		if (school == 0) {
			magic_color = vec3(0.50,0.86,1.0);
			magic = ring*0.05 + stroke(sin(angle*6.0),0.075)*smoothstep(0.79,0.86,radius)*(1.0-smoothstep(0.98,1.12,radius))*0.30;
		} else if (school == 1) {
			magic_color = vec3(1.0,0.48,0.20);
			float flame = radius - 0.91 - sin(angle*5.0-clock*1.5)*0.065 - sin(angle*9.0+clock)*0.035;
			magic = stroke(flame,0.037)*0.28 + stroke(flame+0.05,0.085)*0.08;
		} else if (school == 2) {
			magic_color = vec3(1.0,0.82,0.486);
			float lightning = radius - 0.92 + sin(angle*17.0 + sin(clock*1.3))*0.045 + sin(angle*31.0)*0.023;
			magic = stroke(lightning,0.012)*(0.30+0.06*sin(clock*2.0)) + stroke(lightning,0.042)*0.06;
		} else {
			magic_color = vec3(0.761,0.627,1.0);
			float sector = mod(angle + clock*0.16 + 3.141593, 1.570796) - 0.785398;
			vec2 fold = vec2(sector*0.94, radius-0.94);
			float paper = abs(fold.x)+abs(fold.y)*1.4;
			magic = stroke(paper-0.12,0.009)*0.30;
			magic += stroke(fold.x-fold.y*0.35,0.008)*(1.0-smoothstep(0.07,0.12,paper))*0.18;
		}
		magic *= 1.0-smoothstep(1.08,1.24,radius);
	}
	// Keep selection near the action, clear of the prose and the crystal rim.
	float selection = selected ? stroke(p.y-0.91, 0.01)*(1.0-smoothstep(0.1,0.58,abs(p.x)))*0.28 : 0.0;
	light += magic_color*magic + rarity_color.rgb*selection;
	alpha += magic+selection;
	COLOR = vec4(light/max(0.001,alpha), alpha) * item_modulate;
}
