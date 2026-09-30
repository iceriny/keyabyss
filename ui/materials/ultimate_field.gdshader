shader_type canvas_item;
render_mode blend_add;

uniform int school = 0;
uniform vec4 tint : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float age = 0.0;
uniform float lifetime = 6.0;
uniform float motion = 1.0;
uniform float detail = 1.0;

float soft_line(float d, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(d));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.5;
	float r = length(p);
	float a = atan(p.y, p.x);
	float aa = max(length(fwidth(p)), 0.0015);
	float t = age * motion;
	float envelope = smoothstep(0.0, 0.24, age) * smoothstep(0.0, 0.8, lifetime - age);
	float edge = 1.0 - smoothstep(1.05, 1.23, r);
	float arrival = exp(-age * 1.5);
	float wave_radius = mix(1.0, 0.16 + 0.84 * (1.0 - exp(-age * 5.0)), motion);
	float wave = exp(-pow((r - wave_radius) * 25.0, 2.0)) * arrival;
	float floor_light = exp(-r * r * 3.0) * 0.022;
	float glow = 0.0;
	float stroke = 0.0;
	float flakes = 0.0;
	if (school == 0) {
		// Frost follows six fractured axes; fine facets stay within the paid field.
		float sector = mod(a + 3.141593 / 6.0, 3.141593 / 3.0) - 3.141593 / 6.0;
		vec2 q = vec2(cos(sector), sin(sector)) * r;
		float stem = soft_line(q.y + sin(q.x * 31.0) * 0.003, 0.0006, aa);
		float branch = soft_line(abs(q.y) - (q.x - 0.47) * 0.57, 0.0005, aa);
		stroke = stem * smoothstep(0.24, 0.65, r) * (1.0 - smoothstep(0.82, 1.0, r)) * 0.13;
		stroke += branch * smoothstep(0.46, 0.52, q.x) * (1.0 - smoothstep(0.65, 0.76, q.x)) * 0.14;
		glow = exp(-pow((r - 0.93) * 15.0, 2.0)) * (0.035 + arrival * 0.10);
		float cell = floor((a + 3.141593) * 9.0);
		float drift = fract(cell * 0.618 + t * 0.10);
		float ar = abs(fract((a + 3.141593) * 9.0) - 0.5);
		flakes = exp(-ar * ar * 700.0 - pow((r - (0.25 + drift * 0.7)) * 180.0, 2.0)) * sin(drift * 3.141593) * 0.28;
	} else if (school == 1) {
		// Low ember bed and a broken, rising perimeter, never an opaque fire disc.
		float wind = sin(a * 7.0 + t * 0.9) * sin(a * 13.0 - t * 0.65);
		float rim = r - (0.92 + wind * 0.025);
		float tongues = pow(0.5 + 0.5 * sin(a * 23.0 - t * 0.8), 5.0);
		glow = exp(-rim * rim * 350.0) * (0.045 + tongues * 0.09);
		stroke = soft_line(rim, 0.0005, aa) * (0.05 + tongues * 0.14);
		floor_light *= 1.6 + sin(a * 3.0 - t * 0.24) * sin(r * 10.0 - t * 0.7) * 0.6;
		float cell = floor((a + 3.141593) * 8.0);
		float drift = fract(cell * 0.7548 + t * 0.16);
		float ar = abs(fract((a + 3.141593) * 8.0) - 0.5);
		flakes = exp(-ar * ar * 450.0 - pow((r - (0.45 + drift * 0.5)) * 150.0, 2.0)) * sin(drift * 3.141593) * 0.42;
	} else if (school == 2) {
		// Charge arcs are discontinuous. The actual falling strikes come from hits.
		float orbit = r - 0.83 - sin(a * 11.0 + t * 0.8) * 0.003;
		float segments = pow(0.5 + 0.5 * sin(a * 3.0 - t * 0.65), 8.0);
		stroke = soft_line(orbit, 0.0008, aa) * segments * 0.35;
		glow = exp(-orbit * orbit * 900.0) * segments * 0.12;
		float cloud = 0.5 + 0.5 * sin(a * 4.0 + sin(r * 9.0 - t * 0.45));
		floor_light *= cloud * 1.7;
		stroke += soft_line(r - 0.66, 0.0003, aa) * pow(0.5 + 0.5 * sin(a * 5.0 + t * 0.4), 12.0) * 0.10;
	} else {
		// Orbiting folded leaves: wings and their crease, rather than another ring.
		float angle = a - t * 0.10;
		float cell = floor((angle + 3.141593) * 2.0);
		float tangential = (fract((angle + 3.141593) * 2.0) - 0.5) * r;
		float orbit = 0.73 + sin(cell * 2.4 + t * 0.7) * 0.08;
		float radial = r - orbit;
		float leaf = abs(tangential) / 0.030 + abs(radial - tangential * 0.22) / 0.010;
		float fold = 1.0 - smoothstep(0.75, 1.0 + aa * 24.0, leaf);
		stroke = fold * mix(0.16, 0.48, step(0.0, radial - tangential * 0.22));
		glow = exp(-pow(tangential * 30.0, 2.0) - pow(radial * 50.0, 2.0)) * 0.075;
		floor_light *= 0.5;
		wave *= 0.6;
	}
	vec3 light = tint.rgb * (floor_light + glow + wave * 0.19);
	light += mix(tint.rgb, vec3(1.1, 1.03, 0.9), 0.6) * (stroke + flakes * detail);
	COLOR = vec4(light * envelope * edge, 1.0);
}
