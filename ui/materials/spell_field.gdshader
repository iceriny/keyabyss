shader_type canvas_item;
render_mode unshaded;
#include "res://ui/materials/element_medium.gdshaderinc"
#include "res://ui/materials/fire_fallback.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 extent;
uniform vec2 start;
uniform vec2 end;
uniform float radius;
uniform bool cold = true;
uniform bool mist = false;
uniform bool gravity = false;
uniform bool fire_fallback = false;
uniform float age = 0.0;
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float strength = 1.0;
uniform float fade = 1.0;
uniform float variation = 0.0;

float hash(vec2 p) { return element_hash(p); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p)*0.58 + noise(p*2.1+8.3)*0.28 + noise(p*4.3)*0.14; }

void fragment() {
	vec2 p = UV * extent;
	vec2 axis = end - start;
	float t = clamp(dot(p-start, axis)/max(dot(axis,axis), 0.001), 0.0, 1.0);
	vec2 local = p - mix(start,end,t);
	float dist = length(local);
	float mask = 1.0-smoothstep(radius-18.0, radius+9.0, dist);
	float arrival = smoothstep(0.0, 0.18, age);
	float life = fade * arrival;
	vec2 q = p * 0.026;
	vec2 radial = local / max(dist, 1.0);
	float turbulence = element_fbm(q-radial*clock*0.12);
	float detail = 0.0;
	vec3 tint;
	float haze;
	if (cold) {
		// The live lattice is a separate lit surface. This quiet footprint keeps
		// the full paid radius readable while its first branches are forming.
		haze = (0.012+0.022*turbulence)*strength;
		tint = vec3(.17,.29,.34);
		if (mist) {
			float soft_edge = 1.0 - smoothstep(radius * 0.45, radius + 8.0, dist);
			haze = (0.08 + 0.12 * turbulence) * soft_edge;
			tint = vec3(.4,.65,.71);
		}
	} else {
		// Refraction and a quiet footprint remain when fluid is disabled.
		float core = pow(max(0.0,1.0-dist/radius),1.7);
		detail = 0.0;
		haze = 0.065*core*strength;
		tint = vec3(0.45,0.105,0.018);
		if (gravity) {
			float spiral = sin(atan(local.y,local.x)*3.0 + dist*0.07 + clock*0.6);
			detail = pow(max(spiral,0.0),8.0)*core*0.15;
			tint = vec3(0.46,0.6,1.05);
		} else if (fire_fallback) {
			vec4 fire = field_fire(local / radius, clock);
			tint = fire.rgb;
			haze = fire.a * strength;
		}
	}
	float alpha = mask*life*(haze+detail);
	vec2 ripple = vec2(fbm(q+clock*0.1)-0.5, turbulence-0.5);
	vec2 offset = ripple*SCREEN_PIXEL_SIZE*(cold ? 0.9 : 2.5)*motion*mask*life;
	vec3 back = texture(screen_texture, SCREEN_UV+offset).rgb;
	COLOR = vec4(mix(back,tint,0.82), alpha);
}
