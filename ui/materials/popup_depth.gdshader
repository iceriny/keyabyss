shader_type canvas_item;
render_mode unshaded;

#include "res://ui/materials/soft_shapes.gdshaderinc"

uniform vec2 canvas_size = vec2(280.0,420.0);
uniform float arrival = 1.0;
uniform float clock = 0.0;

void fragment() {
	vec2 p = UV * canvas_size;
	vec2 edge_distance = min(p, canvas_size - p);
	float edge = smoothstep(0.0, 28.0, edge_distance.x) * smoothstep(0.0, 22.0, edge_distance.y);
	float lens = exp(-pow((UV.x - 0.3) / 0.65, 2.0) - pow((UV.y - 0.2) / 0.8, 2.0));
	vec3 base = mix(vec3(0.006, 0.013, 0.018), vec3(0.012, 0.024, 0.029), lens);
	// Unequal, curved shoulders suggest a thin crystal volume without framing it.
	float left = soft_gaussian(p.x - 12.0 - 6.0 * sin(UV.y * 3.1), 5.0);
	float right = soft_gaussian(p.x - canvas_size.x + 13.0 + 4.0 * sin(UV.y * 4.0), 7.0);
	float shoulder = left * soft_gaussian(UV.y - 0.32, 0.32) + right * soft_gaussian(UV.y - 0.7, 0.24) * 0.55;
	float reflection = 0.45 + 0.55 * pow(0.5+0.5*sin(UV.y*4.2-clock*0.5), 2.0);
	base += vec3(0.04, 0.065, 0.075) * shoulder * reflection;
	// A quiet growing vein stays in the bottom margin, clear of the reading area.
	float spine_y = canvas_size.y - 12.0 - 3.0 * sin(UV.x * 5.0);
	float spine = p.y - spine_y;
	float taper = pow(max(sin(UV.x * 3.14159265), 0.0), 2.5);
	float twig_t = clamp((UV.x - 0.52) / 0.24, 0.0, 1.0);
	float twig = p.y - spine_y + 7.0 * sin(twig_t * 1.5707963);
	float twig_fade = smoothstep(0.52, 0.57, UV.x) * (1.0 - smoothstep(0.68, 0.76, UV.x));
	float gold = soft_gaussian_line(spine, 0.55) * taper;
	gold += soft_gaussian_line(twig, 0.4) * twig_fade * 0.45;
	float glint = soft_gaussian(UV.x-0.5-0.64*sin(clock*0.3),0.15);
	base += vec3(0.30, 0.22, 0.10) * gold * (0.70+glint*0.60);
	base += vec3(0.05, 0.034, 0.014) * soft_gaussian(spine, 3.0+reflection*3.0) * taper;
	COLOR = vec4(base, edge * 0.97 * arrival);
}
