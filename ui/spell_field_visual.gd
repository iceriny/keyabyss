class_name SpellFieldVisual
extends Control
## Projects a paid circular or swept field. Geometry remains owned by SpellField.

var field: SpellField
var surface: ShaderMaterial
var particles: GPUParticles2D
var particle_motion: ParticleProcessMaterial
var lights: Array[PointLight2D] = []
var ice: IcePatch
var _born: float
var _pulses: int
var _ending := false
var _fade := 1.0


static func create(state: SpellField, clock: float) -> SpellFieldVisual:
	var visual := load("res://ui/scenes/spell_field_visual.tscn").instantiate() as SpellFieldVisual
	visual.field = state
	visual._born = clock
	visual._pulses = state.remaining_pulses
	return visual


func _ready() -> void:
	surface = material as ShaderMaterial
	surface.set_shader_parameter("variation", fposmod(field.center.dot(Vector2(17.31, 43.7)) + _born * 0.37, 1.0))
	var cold := field.effect.kind in [&"cold_field", &"ice_mist"]
	if cold:
		ice = IcePatch.new()
		add_child(ice)
	surface.set_shader_parameter("cold", cold)
	surface.set_shader_parameter("mist", field.effect.kind == &"ice_mist")
	surface.set_shader_parameter("gravity", field.effect.kind == &"gravity_field")
	particles = $Motes
	particle_motion = particles.process_material as ParticleProcessMaterial
	particles.amount = 40 if cold else 54
	particles.lifetime = 1.0 if cold else 0.8
	var fragment := particles.material as ShaderMaterial
	fragment.set_shader_parameter("cold", cold)
	fragment.set_shader_parameter("gravity", field.effect.kind == &"gravity_field")
	particle_motion.initial_velocity_min = 6 if cold else 18
	particle_motion.initial_velocity_max = 18 if cold else 42
	particle_motion.angular_velocity_min = -18 if cold else -40
	particle_motion.angular_velocity_max = 18 if cold else 40
	particle_motion.scale_max = 0.5 if cold else 0.3
	for index in (1 if field.center == field.endpoint else 2):
		var light := get_node("StartLight" if index == 0 else "EndLight") as PointLight2D
		light.color = Color("a4deef") if cold else Color("ff9b50")
		if field.effect.kind == &"gravity_field": light.color = Color("ae91d9")
		light.height = field.radius * .5
		lights.append(light)


func sync_frame(world_size: Vector2, clock: float, quality: int, reduced: bool) -> void:
	var start := field.center * world_size
	var end := field.endpoint * world_size
	var pad := field.radius + 28.0
	position = start.min(end) - Vector2.ONE * pad
	size = (end - start).abs() + Vector2.ONE * pad * 2.0
	surface.set_shader_parameter("extent", size)
	surface.set_shader_parameter("start", start - position)
	surface.set_shader_parameter("end", end - position)
	surface.set_shader_parameter("radius", field.radius)
	surface.set_shader_parameter("age", clock - _born)
	surface.set_shader_parameter("clock", 0.0 if reduced else clock)
	surface.set_shader_parameter("motion", 0.0 if reduced or quality == 0 else 1.0)
	surface.set_shader_parameter("strength", clampf(float(field.remaining_pulses) / _pulses, 0.18, 1.0))
	_fade = minf(1.0, maxf(0.0, field.expires_at - clock) / 0.35)
	surface.set_shader_parameter("fade", _fade)
	if ice != null:
		ice.sync_patch(start-position, field.radius, clock-_born, _fade, quality, reduced, field.id)
	var motion := particle_motion
	var length := start.distance_to(end)
	particles.position = (start + end) * 0.5 - position
	# Emit from the interior; shader feathering defines the full paid boundary.
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX if length > 1 else ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_box_extents = Vector3(length * 0.5, field.radius * 0.78, 0)
	motion.emission_sphere_radius = field.radius * 0.9
	particles.rotation = (end - start).angle() if length > 1 else 0.0
	particles.visibility_rect = Rect2(-size, size * 2)
	particles.amount_ratio = 1.0 if quality == 2 else 0.5
	particles.emitting = quality > 0 and not reduced and not _ending
	for index in lights.size():
		lights[index].position = (start if index == 0 else end) - position + Vector2(-.35,-.2)*field.radius
		lights[index].texture_scale = field.radius * 3.0 / 128.0
		lights[index].visible = quality == 2
		lights[index].energy = (1.1 if ice != null else .3) * _fade * minf(1.0, (clock - _born) / 0.18)
	queue_redraw()


func finish() -> void:
	_ending = true
	particles.emitting = false
	set_process(true)


func _process(delta: float) -> void:
	delta = BattleVisualClock.delta_for(self, delta)
	if not _ending:
		return
	_fade = maxf(0.0, _fade - delta / 0.4)
	surface.set_shader_parameter("fade", _fade)
	if ice != null: ice.set_fade(_fade)
	for light in lights:
		light.energy = 0.3 * _fade
	if _fade == 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
