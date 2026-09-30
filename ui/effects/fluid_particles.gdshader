shader_type particles;
render_mode disable_velocity;
uniform sampler2D field_texture : filter_linear, repeat_disable;
uniform vec4 world_to_field;
uniform vec4 field_to_world;
uniform vec2 field_origin;
uniform vec2 domain_size;
uniform float coupling = 1.8;
uniform bool box_emission = false;
uniform vec2 box_extents;
uniform float sphere_radius = 5.0;
uniform vec2 direction = vec2(0.0, -1.0);
uniform float spread = 3.14;
uniform vec2 speed_range;
uniform vec2 gravity;
uniform vec2 damping_range;
uniform vec2 scale_range;
uniform vec2 angular_range;
uniform vec4 tint : source_color;
uniform sampler2D color_ramp : filter_linear;
uniform sampler2D scale_curve : filter_linear;
uniform bool has_ramp = false;
uniform bool has_scale_curve = false;

float random(uint seed) {
	seed = ((seed >> uint(16)) ^ seed) * uint(73244475);
	seed = ((seed >> uint(16)) ^ seed) * uint(73244475);
	seed = (seed >> uint(16)) ^ seed;
	return float(seed) / 4294967295.0;
}

void start() {
	uint seed = NUMBER + RANDOM_SEED;
	float angle = random(seed + uint(1)) * TAU;
	vec2 at = box_emission ? (vec2(random(seed + uint(2)), random(seed + uint(3))) * 2.0 - 1.0) * box_extents : vec2(cos(angle), sin(angle)) * sqrt(random(seed + uint(2))) * sphere_radius;
	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xy = (EMISSION_TRANSFORM * vec4(at, 0.0, 1.0)).xy;
	angle = atan(direction.y, direction.x) + (random(seed + uint(4)) * 2.0 - 1.0) * spread;
	VELOCITY = (EMISSION_TRANSFORM * vec4(vec2(cos(angle), sin(angle)) * mix(speed_range.x, speed_range.y, random(seed + uint(5))), 0.0, 0.0)).xyz;
	CUSTOM = vec4(0.0, mix(scale_range.x, scale_range.y, random(seed + uint(6))), mix(angular_range.x, angular_range.y, random(seed + uint(7))), 0.0);
	COLOR = tint;
}

void process() {
	CUSTOM.x += DELTA / LIFETIME;
	if (CUSTOM.x > 1.0) ACTIVE = false;
	vec2 uv = (mat2(world_to_field.xy, world_to_field.zw) * TRANSFORM[3].xy + field_origin) / domain_size;
	VELOCITY.xy += gravity * DELTA;
	float speed = length(VELOCITY.xy);
	float damping = mix(damping_range.x, damping_range.y, random(NUMBER + RANDOM_SEED + uint(8)));
	VELOCITY.xy *= max(0.0, speed - damping * DELTA) / max(speed, 0.0001);
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
		vec2 flow = mat2(field_to_world.xy, field_to_world.zw) * texture(field_texture, uv).xy;
		VELOCITY.xy = mix(VELOCITY.xy, flow, 1.0 - exp(-coupling * DELTA));
	}
	TRANSFORM[3].xy += VELOCITY.xy * DELTA;
	CUSTOM.w += CUSTOM.z * DELTA;
	float scale = CUSTOM.y * (has_scale_curve ? texture(scale_curve, vec2(CUSTOM.x, 0.5)).r : 1.0);
	TRANSFORM[0].xyz = (EMISSION_TRANSFORM * vec4(cos(CUSTOM.w), sin(CUSTOM.w), 0.0, 0.0)).xyz * scale;
	TRANSFORM[1].xyz = (EMISSION_TRANSFORM * vec4(-sin(CUSTOM.w), cos(CUSTOM.w), 0.0, 0.0)).xyz * scale;
	COLOR = tint * (has_ramp ? texture(color_ramp, vec2(CUSTOM.x, 0.5)) : vec4(1.0));
}
