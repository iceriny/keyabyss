shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/element_medium.gdshaderinc"
uniform vec2 extent=vec2(300.0,150.0);
uniform float progress=0.0;
uniform float seed=0.0;
uniform bool electric=true;
uniform bool reduced_motion=false;

float path_y(float x,float phase) {
	float jag=element_noise(vec2(x*0.038,phase))*2.0-1.0;
	jag+=0.48*(element_noise(vec2(x*0.115,phase+9.0))*2.0-1.0);
	return jag*19.0*sin(clamp(x/(extent.x-64.0),0.0,1.0)*3.14159);
}
float spine(float x,float phase) {
	float spacing=(extent.x-64.0)/ceil((extent.x-64.0)/22.0);
	float cell=floor(x/spacing);
	return mix(path_y(cell*spacing,phase),path_y((cell+1.0)*spacing,phase),fract(x/spacing));
}
float segment_distance(vec2 p,vec2 a,vec2 b) {
	vec2 v=b-a;
	return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),0.001),0.0,1.0));
}
void fragment() {
	vec2 p=(UV-0.5)*extent;
	float x=p.x+extent.x*0.5-32.0;
	float along=clamp(x/(extent.x-64.0),0.0,1.0);
	float fade=pow(1.0-progress,1.5);
	float gate=smoothstep(-7.0,1.0,x)*(1.0-smoothstep(extent.x-64.0,extent.x-56.0,x));
	float core=0.0,corona=0.0;
	if(electric) {
		float phase=seed+floor(progress*(reduced_motion ? 0.0 : 9.0));
		float spacing=(extent.x-64.0)/ceil((extent.x-64.0)/22.0);
		float cell=floor(x/spacing);
		float distance=10000.0;
		for(int j=-1;j<=1;j++) {
			float a=clamp((cell+float(j))*spacing,0.0,extent.x-64.0);
			float b=clamp(a+spacing,0.0,extent.x-64.0);
			distance=min(distance,segment_distance(vec2(x,p.y),vec2(a,path_y(a,phase)),vec2(b,path_y(b,phase))));
		}
		float aa=max(fwidth(distance),0.65);
		core=1.0-smoothstep(0.35,0.35+aa,distance);
		corona=exp(-distance*distance/32.0)*0.22+exp(-distance*distance/290.0)*0.055;
		for(int i=0;i<5;i++) {
			float id=float(i);
			float start=(0.15+id*0.14)*(extent.x-64.0);
			float span=24.0+element_hash(vec2(id,seed))*46.0;
			float reach=clamp((x-start)/span,0.0,1.0);
			float side=mod(id,2.0)*2.0-1.0;
			vec2 root=vec2(start,spine(start,phase));
			vec2 tip=root+vec2(span,side*(18.0+id*3.0));
			vec2 bend=mix(root,tip,0.52)+vec2(0.0,side*7.0);
			float d=min(segment_distance(vec2(x,p.y),root,bend),segment_distance(vec2(x,p.y),bend,tip));
			float mask=1.0-smoothstep(0.65,1.0,reach);
			core+=(1.0-smoothstep(0.1,0.1+max(fwidth(d),0.65),d))*mask*0.42;
			corona+=exp(-d*d/14.0)*mask*0.12;
		}
		float vapor=element_fbm(p*0.07+seed)*exp(-p.y*p.y/800.0)*sin(along*3.14159)*0.045;
		COLOR=vec4((vec3(0.62,0.74,1.0)*corona+vec3(1.25,1.35,1.55)*core+vec3(0.23,0.32,0.65)*vapor)*fade*gate,1.0);
	} else {
		float taper=pow(max(0.0,sin(along*3.14159)),0.7);
		float curve=sin(along*6.28318)*7.0;
		float d=(p.y-curve)/max(0.3,taper);
		float smoke=element_fbm(p*0.09-vec2(progress*2.0,0));
		vec3 blade=vec3(0.95,0.72,1.2)*exp(-d*d/1.5)+vec3(0.4,0.19,0.65)*exp(-d*d/180.0)*smoke*0.45;
		COLOR=vec4(blade*fade*taper*gate,1.0);
	}
}
