shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(1920.0,1080.0);
uniform vec4 tint : source_color = vec4(0.54,0.8,0.87,1.0);
uniform float progress = 0.0;
uniform bool reduced_motion = false;
uniform bool startup = false;
uniform float ceremony = 1.0;

void fragment() {
	vec2 p = (UV-0.5)*canvas_size/min(canvas_size.x,canvas_size.y);
	float r = length(p);
	float angle = atan(p.y,p.x);
	float close = smoothstep(0.0,0.38,progress);
	float release = smoothstep(0.48,1.0,progress);
	float veil = close*(1.0-release);
	float radius = mix(0.7,0.14,close)+release*0.95;
	float aa = max(fwidth(r),0.0008);
	float band = exp(-pow((r-radius)/0.035,2.0))*0.13;
	float seam = exp(-pow((r-radius)/aa,2.0));
	float turns = 0.55+0.45*sin(angle*3.0-progress*3.0);
	float rhythm = smoothstep(0.08,0.28,progress)*(1.0-smoothstep(0.67,1.0,progress));
	float halo = exp(-r*r*9.0)*0.1;
	float threads = 0.0;
	for(int i=0;i<5;i++) {
		float f = float(i);
		float orbit = radius*(1.0+f*0.027)+sin(angle*2.0+f)*0.002;
		threads += exp(-pow((r-orbit)/aa,2.0))*pow(0.5+0.5*sin(angle*2.0+f*1.7-progress),8.0)*0.12;
	}
	vec3 light = mix(vec3(0.75,0.61,0.33),tint.rgb,0.3);
	float glow = reduced_motion ? 0.0 : rhythm*(band+seam*turns*0.23+threads+halo);
	if (startup) {
		// The native rune ring carries activity; keep its background softly lit.
		glow = rhythm * exp(-r*r*13.0) * 0.022;
	}
	glow *= ceremony;
	float alpha = max(veil,clamp(glow*1.8,0.0,0.9));
	vec3 ink = vec3(0.003,0.009,0.013)*veil;
	COLOR = vec4((ink+light*glow)/max(alpha,0.0001),alpha);
}
