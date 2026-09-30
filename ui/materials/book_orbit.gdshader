shader_type canvas_item;
render_mode unshaded;
#include "res://ui/materials/soft_shapes.gdshaderinc"
uniform vec4 school_color : source_color;
uniform float clock = 0.0;
uniform int density = 12;
uniform vec2 canvas_size = vec2(500.);
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }
void fragment() {
	vec2 p=(UV-.5)*2.;
	float a = -.488692;
	vec2 q=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*p;
	float ring=length(q/vec2(.83,.28));
	float edge=ring-1.;
	float light=soft_gaussian_line(edge,1./sqrt(3500.*2.2))*pow(.40,2.2) + soft_gaussian_line(edge,1./sqrt(50.*2.2))*pow(.065,2.2);
	for(int i=0;i<12;i++) {
		if(i>=density) {break;}
		float angle=float(i)*6.283185/float(density)+clock*6.283185/22.;
		vec2 point=vec2(cos(angle),sin(angle))*.64;
		float d=length((p-point)*canvas_size*.5);
		light+=soft_gaussian_line(d,sqrt(2.5/2.2))*pow(.7,2.2)+soft_gaussian_line(d,sqrt(32./2.2))*pow(.27,2.2)+soft_gaussian_line(d,sqrt(135./2.2))*pow(.07,2.2);
	}
	float bounds = (1.0-smoothstep(.82,1.0,abs(p.x))) * (1.0-smoothstep(.82,1.0,abs(p.y)));
	COLOR=vec4(school_color.rgb*(1.0+light),clamp(light,0.,1.)*bounds)*item_modulate;
}
