shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(280.0,420.0);
uniform float arrival = 1.0;

void fragment() {
	vec2 px = min(UV,1.0-UV)*canvas_size;
	float edge = smoothstep(0.0,13.0,px.x)*smoothstep(0.0,10.0,px.y);
	float lens = exp(-pow((UV.x-0.35)/0.55,2.0)-pow((UV.y-0.2)/0.9,2.0));
	vec3 base = mix(vec3(0.005,0.012,0.016),vec3(0.017,0.031,0.037),lens);
	vec3 gold = vec3(0.08,0.061,0.028)*exp(-pow((UV.y-0.92)/0.16,2.0))*pow(sin(UV.x*3.14159265),2.0);
	COLOR = vec4(base+gold,edge*mix(0.91,1.0,arrival));
}
