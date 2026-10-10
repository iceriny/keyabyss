shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float progress=0.0;
uniform bool reduced_motion=false;
varying vec3 discharge;

void vertex() { discharge=vec3(COLOR.a*64.0,COLOR.r,COLOR.g); }
void fragment() {
	float d=length(vec2(max(abs(UV.x)-discharge.x,0.0),UV.y));
	float power=discharge.y;
	float width=mix(0.25,0.75,sqrt(power));
	float core=1.0-smoothstep(width,width+max(fwidth(d),0.65),d);
	float corona=exp(-d*d/12.0)*0.3+exp(-d*d/95.0)*0.045;
	float age=progress*0.24;
	float strikes=exp(-age*24.0)+0.8*exp(-pow((age-0.065)/0.02,2.0))+0.4*exp(-pow((age-0.13)/0.018,2.0));
	if(reduced_motion) strikes=pow(1.0-progress,1.5)*0.65;
	float taper=power<0.5 ? pow(1.0-discharge.z,0.7) : 1.0;
	COLOR=vec4((vec3(6.2,5.1,2.8)*core+vec3(2.2,1.35,0.35)*corona)*power*taper*strikes,1.0);
}
