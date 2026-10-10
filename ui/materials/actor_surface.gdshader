shader_type canvas_item;
#include "res://ui/materials/element_medium.gdshaderinc"
uniform sampler2D ice_grain : filter_linear_mipmap,repeat_disable;
uniform sampler2D ice_film : filter_linear_mipmap,repeat_disable;
uniform int detail = 2;
uniform vec4 school : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float flash = 0.0;
uniform float frozen = 0.0;
uniform float burning = 0.0;
uniform float dissolve = 0.0;
uniform float visual_time = 0.0;
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float warm = smoothstep(0.02, 0.15, tex.r - tex.b);
	vec3 ink = tex.rgb * mix(school.rgb * 0.8 + 0.28, vec3(1.0), warm);
	float grain = hash(floor(UV * 256.0));
	ink *= 0.94 + grain * 0.10;
	float coverage = tex.a;
	if (frozen > 0.0) {
		// Read a small part of each micrograph so the needles and layered plates
		// remain material features at the enemy's actual 50–80 pixel footprint.
		vec2 crystal_uv = UV * .20 + vec2(.34, .22);
		vec2 film_uv = UV * .19 + vec2(.46, .28);
		float crystal = texture(ice_grain, crystal_uv).r;
		float film = textureLod(ice_film, film_uv, 2.0).r;
		float bed = textureLod(ice_film, film_uv, 5.0).r;
		// Frost settles in broad, uneven deposits. A connected clear pane keeps
		// the face and central markings visible beneath the frozen material.
		float accumulation = element_fbm(UV * vec2(4.0, 3.1) + vec2(3.2, 1.7));
		float clear_pane = 1.0 - smoothstep(.7, 1.4, length((UV - vec2(.49, .43)) / vec2(.17, .28)));
		float deposits = smoothstep(.34, .58, accumulation) * (1.0 - clear_pane * .98);
		// The mip-filtered crystal plate lives mainly between .2 and .5. Read
		// that range, then restrict its contrast to deposits outside the pane.
		float needle = smoothstep(.32, .52, crystal) * deposits;
		float deposit = smoothstep(.13 + bed * .54, .34 + bed * .54, frozen);
		float thickness = (.14 + deposits * .65 + needle * .3) * deposit;
		vec2 footprint = max(fwidth(film_uv), vec2(.006));
		vec2 slope = vec2(
			textureLod(ice_film, film_uv + vec2(footprint.x, 0), 4.0).r - textureLod(ice_film, film_uv - vec2(footprint.x, 0), 4.0).r,
			textureLod(ice_film, film_uv + vec2(0, footprint.y), 4.0).r - textureLod(ice_film, film_uv - vec2(0, footprint.y), 4.0).r);
		// The deposited crust grows from this sprite's alpha, including narrow
		// tails and separated body parts. It never substitutes a surrounding cage.
		vec2 reach = TEXTURE_PIXEL_SIZE * (4.0 + needle * 7.0) * deposit;
		float left = texture(TEXTURE, UV - vec2(reach.x, 0)).a;
		float right = texture(TEXTURE, UV + vec2(reach.x, 0)).a;
		float up = texture(TEXTURE, UV - vec2(0, reach.y)).a;
		float down = texture(TEXTURE, UV + vec2(0, reach.y)).a;
		float surrounding = max(max(left, right), max(up, down));
		if (detail > 0) {
			vec2 diagonal = reach * .7071;
			surrounding = max(surrounding, texture(TEXTURE, UV + diagonal).a);
			surrounding = max(surrounding, texture(TEXTURE, UV - diagonal).a);
			surrounding = max(surrounding, texture(TEXTURE, UV + vec2(diagonal.x, -diagonal.y)).a);
			surrounding = max(surrounding, texture(TEXTURE, UV + vec2(-diagonal.x, diagonal.y)).a);
		}
		vec2 body_slope = vec2(left - right, up - down);
		vec3 normal = normalize(vec3(-slope * 2.0 + body_slope * .75, 1.0));
		NORMAL = normalize(mix(vec3(0, 0, 1), normal, .35 * deposit));
		float diffuse = max(dot(normal, normalize(vec3(-.45, -.65, .8))), 0.0);
		float reflection = pow(max(dot(normal, normalize(vec3(-.28, -.40, 1.0))), 0.0), 26.0);
		float frost_dust = smoothstep(.29, .48, crystal) * deposits;
		vec3 transmitted = ink;
		if (detail > 0) {
			vec4 bent = texture(TEXTURE, UV + normal.xy * TEXTURE_PIXEL_SIZE * 2.0 * deposit);
			transmitted = mix(ink, bent.rgb, bent.a * .10 * deposit);
		}
		transmitted *= exp(-vec3(.25, .09, .03) * thickness);
		vec3 ice = transmitted + vec3(.09, .23, .28) * thickness * (.2 + diffuse * .35);
		float facet = smoothstep(.28, .46, film) * deposits;
		ice += vec3(.55, .82, .91) * (reflection * facet * .42 + frost_dust * .90) * deposit;
		// Clear panes retain the creature below; rough needles scatter much more
		// strongly. The darker subsurface keeps the highlight from reading white.
		ink = mix(ink, ice, min(1.0, frozen * 2.0));
		float crust = surrounding * deposit * (.16 + deposits * .34 + needle * .40) * (1.0 - tex.a);
		vec3 crust_color = vec3(.10, .28, .36) + vec3(.49, .73, .80) * (diffuse * .25 + needle * .45 + reflection * facet * .3);
		ink = mix(ink, crust_color, crust / max(tex.a + crust, .001));
		coverage = max(tex.a, crust);
	}
	ink += vec3(0.75, 0.15, 0.025) * burning * element_fbm((UV-0.5)*(7.0+sin(visual_time)*0.2));
	ink = mix(ink, vec3(1.35, 1.4, 1.25), flash * 0.75);
	float erosion = smoothstep(dissolve - 0.08, dissolve + 0.1, grain * 0.35 + UV.y * 0.65);
	float edge = (1.0 - smoothstep(0.0, 0.1, abs(grain * 0.35 + UV.y * 0.65 - dissolve))) * step(0.01, dissolve);
	COLOR = vec4(ink + vec3(0.7, 0.5, 0.2) * edge, coverage * (dissolve > 0.0 ? erosion : 1.0)) * item_tint;
}
