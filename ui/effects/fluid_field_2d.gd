class_name FluidField2D
extends Control
## A bounded GPU velocity/density/heat field, independent of output pixel density.
## Multiple transformed fields and alpha masks provide arbitrary local coverage.

enum Quality { OFF, LOW, MEDIUM, HIGH, ULTRA }
const LONG_EDGES := [0, 96, 192, 384, 768]
const FOG_LONG_EDGES := [0, 192, 384, 768, 1536]
const PRESSURE_ITERATIONS := [0, 6, 10, 18, 24]

@export var quality: Quality = Quality.MEDIUM
@export var wind := Vector2(4, -2)
@export var buoyancy: float = 12.0
@export var vorticity: float = 0.45
@export var velocity_decay: float = 0.35
@export var density_decay: float = 0.16
@export var heat_decay: float = 0.5
@export_range(0.0, 1.0) var turbulence: float = 0.0
@export var settling: float = 0.0
@export var turbulence_scale: float = 240.0
@export var turbulence_force: float = 65.0
@export_range(0.0, 2.0) var turbulence_detail: float = 0.8
@export var fog_color := Color("668b9b")
@export var light_color := Color("d8c292")
@export_range(0.0, 1.0) var opacity: float = 0.12
@export var scattering: float = .6
@export_range(0.0, 1.0) var center_clear: float = .3
## Local patches can feather their border; screen-filling atmospheres can meet it.
@export_range(0.0, 0.25) var edge_fade: float = .07
@export var domain_mask: Texture2D
@export var fog_enabled := true
@export var sources: Array[FluidInfluence] = []
var obstacles: Array[FluidInfluence] = []
var reduced_motion := false
var active := true
var grid_size := Vector2i.ZERO
var fog_grid_size := Vector2i.ZERO
var tick_count := 0
var dropped_influences := 0
var _gpu := FluidGPU.new()
var _surface: ColorRect
var _material: ShaderMaterial
var _impulses: Array[FluidInfluence] = []
var _clock := 0.0
var _configured_quality := -1
var _configured_mask: Texture2D
var _particle_bindings: Array[Dictionary] = []
var _scene_sources: Array[FluidInfluence] = []
# A bounded packed motion block sits between scene prefix and ambient sources.
var _scene_motion_packed := PackedFloat32Array()
var _scene_motion_offset := 0
var _scene_source_capacity := FluidGPU.MAX_INFLUENCES
var _omitted_scene_sources := 0
var _emitters: Array[FluidEmitter2D] = []
const LIGHT_BUDGET := [3, 5, 8]
var scene_quality: int = 2
var visual_budget: BattleVisualBudget
var _lights: Array[PointLight2D] = []
var _light_texture: GradientTexture2D
var _light_energies := PackedFloat64Array()
var _light_order: Array[int] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_texture = preload("res://ui/effects/fluid_light.tres")
	_surface = preload("res://ui/scenes/fluid_surface.tscn").instantiate() as ColorRect
	_material = _surface.material as ShaderMaterial
	_material.set_shader_parameter("field_texture", _gpu.texture)
	_material.set_shader_parameter("density_texture", _gpu.density_texture)
	_material.set_shader_parameter("boundary_texture", _gpu.boundary_texture)
	_material.set_shader_parameter("matter_texture", _gpu.matter_texture)
	_surface.material = _material
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_configure)
	visibility_changed.connect(_visibility_changed)
	_configure()


func set_options(detail: int, less_motion: bool) -> void:
	if quality == detail and reduced_motion == less_motion and _configured_mask == domain_mask and is_node_ready():
		return
	quality = clampi(detail, Quality.OFF, Quality.ULTRA) as Quality
	reduced_motion = less_motion
	_impulses.clear()
	if is_node_ready():
		_configure()


func set_active(value: bool) -> void:
	active = value
	if not value:
		_impulses.clear()


func inject(influence: FluidInfluence) -> bool:
	if influence == null or influence.extent.x <= 0.0 or influence.extent.y <= 0.0:
		push_error("Fluid injection requires a shape with positive extent")
		return false
	if quality == Quality.OFF or reduced_motion or not active:
		return false
	if _impulses.size() >= FluidGPU.MAX_INFLUENCES:
		dropped_influences += 1
		return false
	var impulse := influence.duplicate() as FluidInfluence
	impulse.continuous = false
	_impulses.append(impulse)
	return true


func canvas_to_local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func emit_effect(profile: FluidEffectProfile, at: Vector2, angle: float = 0.0) -> FluidEmitter2D:
	## Effect origin and angle are local to this field. Profiles remain immutable.
	var emitter := FluidEmitter2D.new()
	emitter.field = self
	emitter.profile = profile
	emitter.position = at
	emitter.rotation = angle
	add_child(emitter)
	return emitter


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_impulses.clear()


func field_texture() -> Texture2D:
	return _gpu.texture


func density_texture() -> Texture2D:
	## Independent fog resolution: R density, G signed temperature.
	return _gpu.density_texture


func matter_texture() -> Texture2D:
	## Same resolution as density: density-weighted linear RGB and age.
	return _gpu.matter_texture


func bind_particles(particles: GPUParticles2D, coupling: float = 1.8) -> void:
	## Sphere/box emitters retain their burst, gravity, curves and draw material.
	## Simulation is in canvas world coordinates; no GPU readback is involved.
	var motion := particles.process_material as ParticleProcessMaterial
	if motion == null or motion.emission_shape not in [ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, ParticleProcessMaterial.EMISSION_SHAPE_BOX]:
		push_error("Fluid particles require a sphere or box ParticleProcessMaterial")
		return
	particles.local_coords = false
	particles.light_mask = 2
	var flow := FluidParticleFlow.create(motion, coupling)
	flow.set_shader_parameter("field_texture", field_texture())
	_particle_bindings.append({"node": weakref(particles), "motion": motion, "flow": flow})
	# Initialize only this emitter. Existing bindings are maintained once per frame.
	if quality != Quality.OFF and not reduced_motion:
		particles.process_material = flow
		flow.sync(self, motion)


func _sync_particles() -> void:
	for index in range(_particle_bindings.size() - 1, -1, -1):
		var binding := _particle_bindings[index]
		var particles := binding.node.get_ref() as GPUParticles2D
		if particles == null:
			_particle_bindings.remove_at(index)
			continue
		var flow := binding.flow as FluidParticleFlow
		var enabled := quality != Quality.OFF and not reduced_motion
		var desired: Material = flow if enabled else binding.motion
		if particles.process_material != desired:
			particles.process_material = desired
		if enabled:
			flow.sync(self, binding.motion)


func set_domain_mask(mask: Texture2D) -> void:
	domain_mask = mask
	if is_node_ready():
		_configure()


func reset_field() -> void:
	_configured_quality = -1
	_clock = 0.0
	_impulses.clear()
	if is_node_ready():
		_configure()


func _configure() -> void:
	if _material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_surface.visible = fog_enabled and quality != Quality.OFF and not reduced_motion
	var longest: int = LONG_EDGES[quality]
	var grid := Vector2i((size / maxf(size.x, size.y) * longest).ceil()).max(Vector2i(8, 8))
	var fog_grid := Vector2i((size / maxf(size.x, size.y) * FOG_LONG_EDGES[quality]).ceil()).max(Vector2i(8, 8))
	if quality == Quality.OFF:
		grid = Vector2i.ZERO
		fog_grid = Vector2i.ZERO
	if grid != grid_size or _configured_quality != quality or _configured_mask != domain_mask:
		_before_reconfigure()
		grid_size = grid
		fog_grid_size = fog_grid
		_configured_quality = quality
		_configured_mask = domain_mask
		_impulses.clear()
		if quality == Quality.OFF:
			RenderingServer.call_on_render_thread(_gpu.deactivate)
		else:
			var image := domain_mask.get_image() if domain_mask != null else Image.create(1, 1, false, Image.FORMAT_R8)
			image = image.duplicate() as Image
			if domain_mask == null:
				image.fill(Color.WHITE)
			image.convert(Image.FORMAT_R8)
			RenderingServer.call_on_render_thread(_gpu.configure.bind(grid_size, fog_grid_size, image))
		_after_reconfigure()
	_material.set_shader_parameter("domain_mask", domain_mask)
	_material.set_shader_parameter("masked", domain_mask != null)
	_material.set_shader_parameter("domain_size", size)
	_material.set_shader_parameter("light_samples", [1, 2, 4, 6, 8][quality])
	update_appearance()


func update_appearance() -> void:
	if _material == null:
		return
	_surface.visible = fog_enabled and quality != Quality.OFF and not reduced_motion
	_material.set_shader_parameter("fog_color", fog_color)
	_material.set_shader_parameter("light_color", light_color)
	_material.set_shader_parameter("opacity", opacity)
	_material.set_shader_parameter("scattering", scattering)
	_material.set_shader_parameter("center_clear", center_clear)
	_material.set_shader_parameter("edge_fade", edge_fade)


func _process(delta: float) -> void:
	var started := DebugLog.begin()
	_process_field(delta)
	DebugLog.end(&"fluid.prepare_submit", started)


func _process_field(delta: float) -> void:
	var bindings_started := DebugLog.begin()
	_sync_particles()
	_sync_lights()
	DebugLog.end(&"fluid.bindings", bindings_started)
	if not active or quality == Quality.OFF or reduced_motion or not is_visible_in_tree() or grid_size == Vector2i.ZERO:
		return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	_material.set_shader_parameter("screen_to_uv_basis", Vector4(inverse.x.x / size.x, inverse.x.y / size.y, inverse.y.x / size.x, inverse.y.y / size.y))
	if delta <= 0.0:
		return
	# Every displayed frame receives a new state at every quality. Detail changes
	# spatial cost, not temporal cadence; a stall never triggers catch-up batches.
	var dt := minf(delta, 0.05)
	_clock += dt
	_scene_sources.clear()
	_scene_motion_packed.clear()
	_scene_motion_offset = 0
	_omitted_scene_sources = 0
	var sources_started := DebugLog.begin()
	var capacity := FluidGPU.MAX_INFLUENCES
	var obstacle_count := mini(obstacles.size(), capacity)
	capacity -= obstacle_count
	var impulse_count := mini(_impulses.size(), capacity)
	capacity -= impulse_count
	var inputs: Array[FluidInfluence] = []
	for emitter in _emitters:
		if emitter.strength() > 0.0:
			inputs.append_array(emitter.sample(dt))
	# Emitters precede scene motion in the submitted buffer; walls and impulses
	# reserve slots first. Build only the motion sources that can reach the solver.
	_scene_source_capacity = maxi(0, capacity - inputs.size())
	var emitter_count := inputs.size()
	_before_step(dt)
	inputs.append_array(_scene_sources)
	inputs.append_array(sources)
	DebugLog.end(&"fluid.sources", sources_started)
	var pack_started := DebugLog.begin()
	var packed := PackedFloat32Array()
	@warning_ignore("integer_division")
	var motion_count := _scene_motion_packed.size() / 28
	var source_count := mini(inputs.size() + motion_count, capacity)
	packed = _pack_sources(inputs, capacity, emitter_count + _scene_motion_offset)
	for i in impulse_count:
		packed.append_array(_impulses[i].packed(fog_color))
	for i in obstacle_count:
		packed.append_array(obstacles[i].packed(fog_color))
	DebugLog.end(&"fluid.pack", pack_started)
	dropped_influences += inputs.size() + motion_count - source_count + _impulses.size() - impulse_count + obstacles.size() - obstacle_count + _omitted_scene_sources
	_impulses.clear()
	var parameters := PackedFloat32Array([size.x, size.y, dt, 0,
		wind.x, wind.y, buoyancy, vorticity,
		velocity_decay, density_decay, heat_decay, _clock,
		float(source_count + impulse_count), float(obstacle_count), 1.0 if domain_mask != null else 0.0, turbulence,
		settling, turbulence_scale, 0.0, turbulence_force,
		turbulence_detail, 0, 0, 0])
	RenderingServer.call_on_render_thread(_gpu.step.bind(parameters, packed, PRESSURE_ITERATIONS[quality]))
	tick_count += 1


func _pack_sources(inputs: Array[FluidInfluence], capacity: int, motion_at: int) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	var prefix := mini(motion_at, capacity)
	for i in prefix:
		packed.append_array(inputs[i].packed(fog_color))
	var available := capacity - prefix
	packed.append_array(_scene_motion_packed.slice(0, available * 28))
	@warning_ignore("integer_division")
	available -= mini(available, _scene_motion_packed.size() / 28)
	for i in range(motion_at, mini(inputs.size(), motion_at + available)):
		packed.append_array(inputs[i].packed(fog_color))
	return packed


func _before_step(_delta: float) -> void:
	pass


func _before_reconfigure() -> void:
	pass


func _after_reconfigure() -> void:
	pass


func _scene_light_energies() -> PackedFloat64Array:
	return PackedFloat64Array()


func _scene_light_input(_index: int) -> Dictionary:
	return {}


func _sync_lights() -> void:
	var inputs: Array[Dictionary] = []
	var energies := _scene_light_energies() if active else PackedFloat64Array()
	var scene_count := energies.size()
	for emitter in _emitters:
		if emitter.profile.light_energy > 0.0 and (not reduced_motion or emitter.profile.duration == 0.0):
			inputs.append_array(emitter.light_inputs())
	energies.resize(scene_count + inputs.size())
	for i in inputs.size(): energies[scene_count + i] = inputs[i].energy
	if energies != _light_energies:
		_light_energies = energies
		_light_order.assign(range(energies.size()))
		_light_order.sort_custom(func(a: int, b: int) -> bool: return energies[a] > energies[b])
	var count := mini(energies.size(), LIGHT_BUDGET[scene_quality])
	while _lights.size() < count:
		var light := PointLight2D.new()
		light.name = "FluidLight%d" % _lights.size()
		light.texture = _light_texture
		light.range_item_cull_mask = 2
		add_child(light)
		_lights.append(light)
		if visual_budget != null: visual_budget.register_light(light, 3)
	for i in _lights.size():
		var light := _lights[i]
		light.enabled = i < count
		light.visible = i < count
		if i < count:
			var index := _light_order[i]
			var input := _scene_light_input(index) if index < scene_count else inputs[index - scene_count]
			light.position = input.point
			light.color = input.color
			light.energy = input.energy
			light.texture_scale = input.radius * 2.0 / _light_texture.width


func _exit_tree() -> void:
	for binding in _particle_bindings:
		var particles := binding.node.get_ref() as GPUParticles2D
		if particles != null:
			particles.process_material = binding.motion
	RenderingServer.call_on_render_thread(_gpu.dispose)
