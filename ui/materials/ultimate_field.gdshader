shader_type canvas_item;
render_mode blend_add;

uniform int school = 0;
uniform vec4 tint : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float age = 0.0;
uniform float lifetime = 6.0;
uniform float motion = 1.0;
uniform float detail = 1.0;
uniform bool fire_fallback = false;

#include "res://ui/materials/element_medium.gdshaderinc"
#include "res://ui/materials/fire_fallback.gdshaderinc"

void fragment() {
	vec2 p=(UV-0.5)*2.5;
	float r=length(p);
	vec2 radial=p/max(r,0.01);
	float t=age*motion;
	float envelope=smoothstep(0.0,0.3,age)*smoothstep(0.0,0.8,lifetime-age);
	float cloud=element_fbm(p*4.8-radial*t*0.13);
	float edge=1.0-smoothstep(0.70,1.12,r+(cloud-0.5)*0.16);
	float mist=cloud*edge;
	vec3 light=vec3(0.0);
	if(school==0) {
		light=vec3(0.09,0.23,0.31)*mist*0.06;
	} else if(school==1) {
		light=vec3(0.45,0.07,0.012)*exp(-r*r*7.0)*0.08;
		if (fire_fallback) {
			vec4 fire = field_fire(p, t);
			light = fire.rgb * fire.a;
		}
	} else if(school==2) {
		vec2 warp=p*4.0+vec2(cloud,element_fbm(p*3.0+8.0))*1.5;
		float charge=element_fbm(warp);
		float filament=exp(-pow((charge-0.53)*135.0,2.0));
		float islands=smoothstep(0.52,0.76,element_fbm(p*3.0+t*0.07));
		light=vec3(0.40,0.25,0.07)*mist*0.20+vec3(1.05,0.82,0.36)*filament*islands*0.48;
	} else {
		float angle=atan(p.y,p.x);
		float curl=element_fbm(p*3.0+vec2(cos(angle+t*0.13),sin(angle+t*0.13)));
		light=vec3(0.27,0.13,0.40)*mist*0.24+vec3(0.57,0.37,0.85)*pow(curl,4.0)*0.45;
	}
	float flash=exp(-age*7.0)*exp(-r*r*5.0)*(motion*0.18);
	COLOR=vec4((light*edge+tint.rgb*flash)*envelope,1.0);
}
