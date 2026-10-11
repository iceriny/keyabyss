shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float hover = 0.0;
uniform vec4 rarity_color : source_color = vec4(0.65, 0.75, 0.75, 1.0);
uniform bool awakening = false;
uniform int school = 0;

float stroke(float distance_value, float width) {
	return exp(-pow(distance_value / width, 2.0));
}

void fragment() {
	vec2 p = UV*2.0-1.0;
	float edge = (1.0-smoothstep(0.65,1.0,abs(p.x)))*(1.0-smoothstep(0.7,1.0,abs(p.y)));
	float wash = exp(-p.x*p.x*3.0-p.y*p.y*1.3)*edge;
	float curve = 0.60+0.16*sin(p.y*2.7+0.4);
	float strand = exp(-pow((abs(p.x)-curve)*90.0,2.0));
	float branch = exp(-pow((abs(p.x)-curve+sin(p.y*5.0)*0.065)*80.0,2.0));
	float ends = (1.0-smoothstep(0.65,0.95,abs(p.y)))*(1.0-smoothstep(-0.45,0.08,p.y))*edge;
	float sheen = exp(-pow((p.x+p.y*0.23-sin(clock*0.24)*0.45)*2.0,2.0));
	float silk = wash*(0.09+hover*0.035+sheen*0.017);
	float gold = (strand*0.18+branch*0.035)*ends;
	vec3 color = mix(rarity_color.rgb*0.5,rarity_color.rgb,gold*3.0);
	float magic = 0.0;
	vec3 magic_color = rarity_color.rgb;
	if (awakening) {
		// Light stays around the glyph, leaving the reading column clear.
		vec2 q = vec2(p.x, (p.y + 0.52)*1.8);
		float radius = length(q);
		float angle = atan(q.y, q.x);
		float ring = stroke(radius - 0.46, 0.025);
		if (school == 0) {
			magic_color = vec3(0.50,0.86,1.0);
			magic = ring*0.14 + stroke(sin(angle*6.0),0.12)*smoothstep(0.2,0.3,radius)*(1.0-smoothstep(0.45,0.58,radius))*0.20;
		} else if (school == 1) {
			magic_color = vec3(1.0,0.48,0.20);
			float flame = radius - 0.44 - sin(angle*5.0-clock*1.5)*0.035 - sin(angle*9.0+clock)*0.025;
			magic = stroke(flame,0.045)*0.25 + stroke(flame+0.05,0.09)*0.10;
		} else if (school == 2) {
			magic_color = vec3(1.0,0.82,0.486);
			float lightning = radius - 0.45 + sin(angle*17.0 + sin(clock*1.3))*0.025 + sin(angle*31.0)*0.013;
			magic = stroke(lightning,0.011)*(0.26+0.07*sin(clock*2.0)) + stroke(lightning,0.05)*0.09;
		} else {
			magic_color = vec3(0.761,0.627,1.0);
			float sector = mod(angle + clock*0.16 + 3.141593, 1.570796) - 0.785398;
			vec2 fold = vec2(sector*0.46, radius-0.46);
			float paper = abs(fold.x)+abs(fold.y)*1.4;
			magic = stroke(paper-0.07,0.008)*0.26;
			magic += stroke(fold.x-fold.y*0.35,0.007)*(1.0-smoothstep(0.04,0.07,paper))*0.18;
			magic += stroke(radius-0.46,0.045)*0.04;
		}
		magic *= 1.0-smoothstep(0.5,0.8,radius);
	}
	float alpha = silk+gold*(0.65+hover*0.35);
	COLOR = vec4(mix(color,magic_color,magic/max(0.001,alpha+magic)), alpha+magic);
}
