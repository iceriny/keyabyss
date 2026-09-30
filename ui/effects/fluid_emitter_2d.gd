class_name FluidEmitter2D
extends Node2D
## Place under any moving visual, assign a field and profile; visibility and
## lifetime govern its contributions. Sampled at solver cadence, not render cadence.

@export var field: FluidField2D
@export var profile: FluidEffectProfile
var age := 0.0
## Optional endpoint relative to this node; used by beams and swept slashes.
@export var end_offset := Vector2.ZERO
var _sample_pools: Array[Array] = []
var _paths: Array[FluidMotionPath] = []
var _particles: GPUParticles2D


func _ready() -> void:
	if field == null or profile == null:
		push_error("FluidEmitter2D requires a field and effect profile")
		return
	for source in profile.influences:
		_sample_pools.append([])
		var path := FluidMotionPath.new()
		path.reset(_to_field() * source.center)
		_paths.append(path)
	field._emitters.append(self)
	if profile.particles != null:
		_particles = profile.particles.instantiate() as GPUParticles2D
		add_child(_particles)
		field.bind_particles(_particles, profile.particle_coupling)


func _process(delta: float) -> void:
	if field == null or profile == null:
		return
	if not field.active:
		rebase()
		return
	age += delta
	if profile.duration > 0.0 and age >= profile.duration:
		if _particles != null:
			_particles.emitting = false
		if age >= profile.duration + (_particles.lifetime if _particles != null else 0.0):
			queue_free()
	if not is_visible_in_tree() or field.quality == FluidField2D.Quality.OFF or field.reduced_motion:
		rebase()
	else:
		for i in _paths.size():
			_paths[i].append(_to_field() * profile.influences[i].center)


func rebase() -> void:
	for i in _paths.size():
		_paths[i].reset(_to_field() * profile.influences[i].center)


func strength() -> float:
	if not is_visible_in_tree() or not field.active:
		return 0.0
	if profile.duration <= 0.0:
		return modulate.a
	if profile.fade_out == 0.0:
		return modulate.a if age < profile.duration else 0.0
	return modulate.a * (1.0 - smoothstep(1.0 - profile.fade_out, 1.0, age / profile.duration))


func sample(delta: float) -> Array[FluidInfluence]:
	var local_frame := _to_field()
	var local_scale := local_frame.get_scale().abs()
	var weight := strength()
	var samples: Array[FluidInfluence] = []
	for i in _paths.size():
		var original := profile.influences[i]
		var point := local_frame * original.center
		var path := _paths[i]
		path.append(point)
		var distance := path.length()
		var count := maxi(1, path.points.size() - 1) if profile.sweep else 1
		for j in count:
			if _sample_pools[i].size() <= j:
				_sample_pools[i].append(original.duplicate() as FluidInfluence)
			var source := _sample_pools[i][j] as FluidInfluence
			source.continuous = true
			source.shape = original.shape
			source.center = point
			source.extent = original.extent * local_scale
			source.rotation = original.rotation + local_frame.get_rotation()
			source.displacement_radius = original.displacement_radius * maxf(local_scale.x, local_scale.y)
			source.body_shape = original.body_shape
			source.body_aspect = original.body_aspect
			source.response_speed = original.response_speed * maxf(local_scale.x, local_scale.y)
			source.sweep_length = 0.0
			var travel := point - path.points[0]
			var exposure := weight
			if profile.sweep and distance > 0.0:
				var radius := maxf(source.extent.x, source.extent.y)
				var start := path.points[j]
				var end := path.points[j + 1]
				travel = (end - start).normalized() * distance
				FluidMotionPath.sweep(source, start, end, radius)
				exposure *= FluidMotionPath.exposure(start.distance_to(end), distance, radius)
			if profile.along_path and end_offset.length_squared() > 1.0:
				FluidMotionPath.sweep(source, point, point + local_frame.basis_xform(end_offset), source.extent.y)
			source.velocity = (local_frame.basis_xform(original.velocity) + travel / delta * profile.inherit_velocity) * weight
			source.density = original.density * exposure
			source.temperature = original.temperature * exposure
			if profile.emission_per_distance:
				source.density *= distance / delta
				source.temperature *= distance / delta
			source.spin = original.spin * weight
			source.radial = original.radial * exposure
			source.coupling = original.coupling * exposure
			if source.displacement_radius > 0.0 and profile.sweep and distance > 0.0:
				source.coupling = original.coupling * weight * FluidMotionPath.exposure(source.sweep_length, distance, source.displacement_radius)
			if original.coupling == 0.0:
				source.velocity *= exposure / maxf(weight, .0001)
			samples.append(source)
		path.reset(point)
	return samples


func light_inputs() -> Array[Dictionary]:
	var local_frame := _to_field()
	var lights: Array[Dictionary] = []
	var count := 3 if profile.along_path and end_offset.length_squared() > 1.0 else 1
	for i in count:
		var along := (float(i) + .5) / count if count > 1 else 0.0
		lights.append({"point": local_frame * (end_offset * along), "color": profile.light_color,
			"energy": profile.light_energy * strength() / sqrt(float(count)), "radius": profile.light_radius * local_frame.get_scale().abs().x})
	return lights


func _to_field() -> Transform2D:
	return field.get_global_transform().affine_inverse() * get_global_transform()


func _exit_tree() -> void:
	if is_instance_valid(field):
		field._emitters.erase(self)
