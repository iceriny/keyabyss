shader_type canvas_item;
render_mode unshaded;

uniform float softness = 18.0;
uniform int quality = 2;
uniform vec2 arena_origin = vec2(0.0);
uniform vec2 arena_span = vec2(1.0);
uniform vec2 arena_size = vec2(1920.0, 1080.0);
uniform float edge_width = 108.0;

void fragment() {
	vec2 p = (UV - arena_origin) / arena_span * arena_size;
	float distance = min(min(p.x, arena_size.x - p.x), min(p.y, arena_size.y - p.y));
	float edge = 1.0 - smoothstep(0.0, edge_width * 2.0, distance);
	vec2 offset = arena_span / arena_size * softness * edge * 0.25;
	vec4 center = texture(TEXTURE, UV);
	vec3 soft = center.rgb;
	if (edge > 0.005) {
		if (quality == 0) {
			vec2 tap = offset * 1.755;
			soft = center.rgb * 0.4;
			soft += (texture(TEXTURE, UV + vec2(tap.x,0)).rgb + texture(TEXTURE, UV - vec2(tap.x,0)).rgb
				+ texture(TEXTURE, UV + vec2(0,tap.y)).rgb + texture(TEXTURE, UV - vec2(0,tap.y)).rgb) * 0.15;
		} else {
		soft = vec3(0.0);
		float total = 0.0;
		int reach = quality == 1 ? 1 : 2;
		for (int y = -reach; y <= reach; y++) {
			for (int x = -reach; x <= reach; x++) {
				vec2 tap = vec2(float(x), float(y));
				float weight = exp(-dot(tap, tap) * 0.5);
				soft += texture(TEXTURE, UV + tap * offset * (quality == 1 ? 1.3 : 1.0)).rgb * weight;
				total += weight;
			}
		}
		soft /= total;
		}
	}
	COLOR = vec4(soft * (1.0 - edge * 0.45), center.a);
}
