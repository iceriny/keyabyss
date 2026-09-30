shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(1920.0,1080.0);
uniform float clock = 0.0;
uniform vec4 tint : source_color = vec4(0.83,0.56,0.51,1.0);
uniform bool victory = false;
uniform bool reduced_motion = false;

void fragment() {
	vec2 p = (UV-vec2(0.5,0.3))*canvas_size/min(canvas_size.x,canvas_size.y);
	float r = length(p);
	float time = clamp(clock/2.5,0.0,1.0);
	float radius = victory ? mix(0.05,1.0,1.0-pow(1.0-time,3.0)) : mix(0.65,0.02,time*time);
	float wave = exp(-pow((r-radius)/0.035,2.0))*(1.0-time)*0.028;
	float haze = exp(-r*r*5.0)*0.007;
	float dust = 0.0;
	for(int i=0;i<16;i++) {
		float n = float(i);
		vec2 seed = vec2(fract(n*0.618)*1.6-0.8,fract(n*0.317)*0.9);
		seed.y += (victory ? -1.0 : 1.0)*time*0.28;
		dust += exp(-length((p-seed)*vec2(1.0,0.3))*650.0)*0.055;
	}
	float energy = haze + (reduced_motion ? 0.0 : wave+dust*sin(time*3.14159265));
	COLOR = vec4(tint.rgb,energy);
}
