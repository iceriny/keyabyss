shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/element_medium.gdshaderinc"

uniform float progress = 0.0;
uniform vec4 tint : source_color = vec4(0.5,1.0,0.8,1.0);
uniform bool hot = false;
uniform bool reduced_motion = false;
uniform float variation = 0.0;

void fragment() {
	vec2 p=UV*2.0-1.0;
	float t=progress;
	// Brief contact light only. Volume and its tail live in the shared fluid.
	float flash=exp(-dot(p,p)*70.0)*pow(1.0-t,5.0);
	vec3 color=mix(tint.rgb,vec3(1.0),0.22)*flash*0.38;
	COLOR=vec4(color,1.0);
}
