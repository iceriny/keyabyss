shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(1.0);
uniform bool spark = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec4 life = COLOR;
	// A tapered, lit crystal face, with a soft halo rather than a drawn outline.
	float shape = abs(p.x) * (spark ? 3.0 : 2.4) + abs(p.y) * 1.25;
	float aa = max(fwidth(shape), .03);
	float face = 1.0 - smoothstep(.66 - aa, .66 + aa, shape);
	float facet = mix(.35, 1.5, smoothstep(-.04, .04, p.x + p.y * .18));
	float core = exp(-dot(p * vec2(6.0, 2.8), p * vec2(6.0, 2.8)));
	float halo = exp(-dot(p * vec2(2.5, 1.6), p * vec2(2.5, 1.6)) * 3.0);
	vec3 light = tint.rgb * (face * facet + halo * .22);
	light += mix(tint.rgb, vec3(1.0), .75) * core * (spark ? 4.0 : 2.2);
	COLOR = vec4(light * life.rgb, life.a);
}
