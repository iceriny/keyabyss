shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/element_medium.gdshaderinc"
uniform sampler2D ice_grain : filter_linear_mipmap,repeat_disable;
uniform float progress = 0.0;
uniform vec2 axis = vec2(1,0);
uniform float seed = 0.0;
uniform bool reduced_motion = false;

void fragment() {
	vec2 p = UV*2.0-1.0;
	if (length(axis) > 0.1) p = vec2(dot(p,axis),dot(p,vec2(-axis.y,axis.x)));
	float fade = pow(1.0-progress,1.4);
	float mist=element_fbm(p*4.0+seed)*exp(-dot(p,p)*4.0)*fade;
	float grain=texture(ice_grain,UV*.72+.14).r;
	float facets=smoothstep(.51,.74,grain)*exp(-dot(p,p)*8.0);
	float flash = reduced_motion ? 0.0 : exp(-dot(p,p)*160.0)*(1.0-smoothstep(0.0,0.18,progress));
	vec3 color=vec3(0.16,0.40,0.55)*mist*0.12+vec3(.45,.74,.88)*facets*fade*.5+vec3(0.8,1.2,1.4)*flash*0.3;
	COLOR=vec4(color,1.0);
}
