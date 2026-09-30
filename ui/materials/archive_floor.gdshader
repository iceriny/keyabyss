shader_type canvas_item;
#include "res://ui/materials/soft_shapes.gdshaderinc"
uniform vec4 school_color : source_color;
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }
void fragment() {
	vec2 p=(UV-.5)*2.;
	float r=length(p);
	float fade=smoothstep(0.,.35,UV.y)*(1.-smoothstep(.75,1.,UV.y));
	float line=soft_gaussian_line(r-.88,1./(400.*sqrt(2.2)))*pow(.35,2.2);
	// Differentiate continuous radius rather than a wrapped/absolute field.
	float rings=0.;
	for(int i=0;i<5;i++) {
		rings+=soft_gaussian_line(r-(float(i)*.2+.133),1./(300.*sqrt(2.2)));
	}
	rings*=pow(.09*(1.-smoothstep(.85,1.,r)),2.2);
	float glow=exp(-pow((r-.88)*10.,2.)*2.2)*pow(.06,2.2);
	COLOR=vec4(school_color.rgb,(line+rings+glow)*pow(fade,2.2))*item_modulate;
}
