class_name FluidParticleFlow
extends ShaderMaterial
## Shared velocity-field advection for the game's sphere and box emitters.
var _world := Transform2D.IDENTITY
var _size := Vector2.ZERO
var _box := Vector2.ZERO
var _emission_shape := -1
var _sphere_radius := -1.0


static func create(motion: ParticleProcessMaterial, coupling: float) -> FluidParticleFlow:
	# The authored template has no uniform overrides. Cloning ShaderMaterial
	# enumerates shader properties; a burst needs only a fresh parameter store.
	var flow := FluidParticleFlow.new()
	flow.shader = preload("res://ui/effects/fluid_particles.gdshader")
	flow.set_shader_parameter("coupling", coupling)
	flow.set_shader_parameter("box_emission", motion.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX)
	flow.set_shader_parameter("sphere_radius", motion.emission_sphere_radius)
	flow.set_shader_parameter("direction", Vector2(motion.direction.x, motion.direction.y))
	flow.set_shader_parameter("spread", deg_to_rad(motion.spread))
	flow.set_shader_parameter("speed_range", Vector2(motion.initial_velocity_min, motion.initial_velocity_max))
	flow.set_shader_parameter("gravity", Vector2(motion.gravity.x, motion.gravity.y))
	flow.set_shader_parameter("damping_range", Vector2(motion.damping_min, motion.damping_max))
	flow.set_shader_parameter("scale_range", Vector2(motion.scale_min, motion.scale_max))
	flow.set_shader_parameter("angular_range", Vector2(deg_to_rad(motion.angular_velocity_min), deg_to_rad(motion.angular_velocity_max)))
	flow.set_shader_parameter("tint", motion.color)
	flow.set_shader_parameter("color_ramp", motion.color_ramp)
	flow.set_shader_parameter("has_ramp", motion.color_ramp != null)
	flow.set_shader_parameter("scale_curve", motion.scale_curve)
	flow.set_shader_parameter("has_scale_curve", motion.scale_curve != null)
	return flow


func sync(field: FluidField2D, motion: ParticleProcessMaterial) -> void:
	# Fields set their paid radius after binding. Keep the GPU emitter in sync.
	if motion.emission_shape != _emission_shape:
		_emission_shape = motion.emission_shape
		set_shader_parameter("box_emission", _emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX)
	if motion.emission_sphere_radius != _sphere_radius:
		_sphere_radius = motion.emission_sphere_radius
		set_shader_parameter("sphere_radius", _sphere_radius)
	var world := field.get_global_transform()
	if world != _world or field.size != _size:
		_world = world
		_size = field.size
		var inverse := world.affine_inverse()
		set_shader_parameter("world_to_field", Vector4(inverse.x.x, inverse.x.y, inverse.y.x, inverse.y.y))
		set_shader_parameter("field_origin", inverse.origin)
		set_shader_parameter("domain_size", field.size)
		set_shader_parameter("field_to_world", Vector4(world.x.x, world.x.y, world.y.x, world.y.y))
	var box := Vector2(motion.emission_box_extents.x, motion.emission_box_extents.y)
	if box != _box:
		_box = box
		set_shader_parameter("box_extents", box)
