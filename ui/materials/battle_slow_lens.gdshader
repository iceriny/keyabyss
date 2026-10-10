shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_color : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount = 0.0;
uniform float arrival = 0.0;
uniform float bend = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p) * .5;
	// A quartic lens leaves the reading centre steady and bends the periphery.
	vec2 lens_uv = .5 + p * .5 * (1.0 - bend * r2 * r2);
	vec3 color = texture(screen_color, SCREEN_UV + lens_uv - UV).rgb;
	float front = mix(1.65, -.25, smoothstep(0.0, 1.0, arrival));
	float wash = smoothstep(front - .22, front + .22, length(p));
	float depth = amount * wash;
	color *= mix(vec3(1.0), vec3(.72, .91, 1.07), depth * .65);
	color += vec3(.006, .018, .030) * depth * (.3 + .7 * smoothstep(.12, 1.1, r2));
	COLOR = vec4(color, 1.0);
}
