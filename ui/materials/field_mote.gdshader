shader_type canvas_item;
render_mode blend_add, unshaded;
uniform bool cold = true;
uniform bool gravity = false;
void fragment() {
	vec2 p = UV*2.0-1.0;
	float shape = cold ? abs(p.x)*1.8+abs(p.y)*0.8 : length(p*vec2(1.4,0.7));
	float mask = 1.0-smoothstep(0.35,0.85,shape);
	vec3 color = cold ? mix(vec3(0.26,0.6,0.84),vec3(1.1,1.7,1.8),step(0.0,p.x+p.y*0.25)) : vec3(1.7,0.59,0.15);
	if (gravity) color = vec3(0.8, 0.5, 1.25);
	COLOR = vec4(color*COLOR.rgb,COLOR.a*mask);
}
