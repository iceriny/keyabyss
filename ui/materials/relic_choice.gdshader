shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float hover = 0.0;

void fragment() {
	vec2 p = UV*2.0-1.0;
	float edge = (1.0-smoothstep(0.65,1.0,abs(p.x)))*(1.0-smoothstep(0.7,1.0,abs(p.y)));
	float wash = exp(-p.x*p.x*3.0-p.y*p.y*1.3)*edge;
	float curve = 0.60+0.16*sin(p.y*2.7+0.4);
	float strand = exp(-pow((abs(p.x)-curve)*90.0,2.0));
	float branch = exp(-pow((abs(p.x)-curve+sin(p.y*5.0)*0.065)*80.0,2.0));
	float ends = (1.0-smoothstep(0.65,0.95,abs(p.y)))*(1.0-smoothstep(-0.45,0.08,p.y))*edge;
	float sheen = exp(-pow((p.x+p.y*0.23-sin(clock*0.24)*0.45)*2.0,2.0));
	float silk = wash*(0.04+hover*0.035+sheen*0.017);
	float gold = (strand*0.18+branch*0.035)*ends;
	vec3 color = mix(vec3(0.23,0.36,0.35),vec3(0.96,0.76,0.4),gold*3.0);
	COLOR = vec4(color,silk+gold*(0.65+hover*0.35));
}
