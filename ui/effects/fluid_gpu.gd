class_name FluidGPU
extends RefCounted
## Owned by the rendering thread. No per-frame GPU readback, submit or sync.

const MAX_INFLUENCES := 48
const SHADER: RDShaderFile = preload("res://ui/effects/fluid_solver.glsl")
const GPU_TIMING = preload("res://ui/effects/gpu_effect_timing.gd")
var texture := Texture2DRD.new()
var boundary_texture := Texture2DRD.new()
var matter_texture := Texture2DRD.new()
var density_texture := Texture2DRD.new()
var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _program: EffectPipeline
var _buffer: RID
var _sampler: RID
var _mask: RID
var _geometry: RID
var _states: Array[RID] = []
var _matter: Array[RID] = []
var _dye: Array[RID] = []
var _pressures: Array[RID] = []
var _sets: Array[RID] = []
var _owned: Array[RID] = []
var _grid := Vector2i.ZERO
var _dye_grid := Vector2i.ZERO
var _fog_side := 0


func configure(grid: Vector2i, dye_grid: Vector2i, mask_image: Image) -> void:
	# Canvas/particle materials retain the RenderingServer texture RID, not the
	# Texture2DRD object. Keep that RID alive and replace its backing RD image.
	var previous := _take_resources()
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return # Headless and Compatibility have no compute device.
	_grid = grid
	_dye_grid = dye_grid
	_program = EffectPipeline.acquire(SHADER)
	_shader = _program.shader
	_pipeline = _program.pipeline
	_buffer = _keep(_rd.storage_buffer_create(MAX_INFLUENCES * 112))
	var sampler := RDSamplerState.new()
	sampler.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _keep(_rd.sampler_create(sampler))
	var format := RDTextureFormat.new()
	format.width = mask_image.get_width()
	format.height = mask_image.get_height()
	format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	_mask = _keep(_rd.texture_create(format, RDTextureView.new(), [mask_image.get_data()]))
	for i in 2:
		_states.append(_image(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT))
		_matter.append(_image(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, _dye_grid))
		_dye.append(_image(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, _dye_grid))
		_pressures.append(_image(RenderingDevice.DATA_FORMAT_R32_SFLOAT))
	_geometry = _image(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	# Five velocity/pressure binding variants for each independent fog side.
	# Velocity stays on image zero for combustion and particles; fog alternates.
	for fog_side in 2:
		for state_index in 2:
			for pressure_index in (3 if state_index == 0 else 2):
				var refresh := pressure_index == 2
				var uniforms: Array[RDUniform] = []
				var ids: Array[RID] = [_states[state_index], _states[state_index if refresh else 1 - state_index], _pressures[pressure_index % 2], _pressures[1 - pressure_index % 2], _geometry, _buffer]
				for binding in ids.size():
					var uniform := RDUniform.new()
					uniform.binding = binding
					uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER if binding == 5 else RenderingDevice.UNIFORM_TYPE_IMAGE
					uniform.add_id(ids[binding])
					uniforms.append(uniform)
				var mask_uniform := RDUniform.new()
				mask_uniform.binding = 6
				mask_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				mask_uniform.add_id(_sampler)
				mask_uniform.add_id(_mask)
				uniforms.append(mask_uniform)
				for side in 2:
					var matter_uniform := RDUniform.new()
					matter_uniform.binding = 7 + side
					matter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
					matter_uniform.add_id(_matter[fog_side if side == 0 else 1 - fog_side])
					uniforms.append(matter_uniform)
					var dye_uniform := RDUniform.new()
					dye_uniform.binding = 9 + side
					dye_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
					dye_uniform.add_id(_dye[fog_side if side == 0 else 1 - fog_side])
					uniforms.append(dye_uniform)
				_sets.append(_keep(_rd.uniform_set_create(uniforms, _shader, 0)))
	texture.texture_rd_rid = _states[0]
	boundary_texture.texture_rd_rid = _geometry
	matter_texture.texture_rd_rid = _matter[0]
	density_texture.texture_rd_rid = _dye[0]
	_free_resources(previous)


func step(parameters: PackedFloat32Array, influences: PackedFloat32Array, iterations: int) -> void:
	if _rd == null:
		return
	if not influences.is_empty():
		var bytes := influences.to_byte_array()
		_rd.buffer_update(_buffer, 0, bytes.size(), bytes)
	var timing := 0
	if GPU_TIMING.enabled:
		timing = GPU_TIMING.begin(_rd, "fluid", get_instance_id(), 7, {
			"grid": [_grid.x, _grid.y], "fog_grid": [_dye_grid.x, _dye_grid.y],
			"iterations": iterations, "dispatches": iterations + 6,
			"sources": int(parameters[12]), "obstacles": int(parameters[13]), "clock": parameters[11]})
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	var set_base := _fog_side * 5
	_dispatch(list, set_base, 4, parameters) # Rasterize moving solids once per tick.
	if timing != 0: GPU_TIMING.mark(_rd, timing, "geometry")
	_dispatch(list, set_base, 0, parameters) # Advect velocity, then apply forces and sources.
	if timing != 0: GPU_TIMING.mark(_rd, timing, "velocity")
	_dispatch(list, set_base + 4, 1, parameters) # Divergence and clear pressure 0.
	if timing != 0: GPU_TIMING.mark(_rd, timing, "divergence")
	for i in iterations:
		_dispatch(list, set_base + 3 + (i % 2), 2, parameters)
	if timing != 0: GPU_TIMING.mark(_rd, timing, "pressure")
	_dispatch(list, set_base + 3, 3, parameters) # Project this tick's velocity into texture 0.
	if timing != 0: GPU_TIMING.mark(_rd, timing, "projection")
	_dispatch(list, set_base, 5, parameters) # Advect matter with the newly projected flow.
	if timing != 0: GPU_TIMING.mark(_rd, timing, "transport")
	_fog_side = 1 - _fog_side
	_dispatch(list, _fog_side * 5 + 2, 7, parameters) # Refresh from this tick's fog.
	_rd.compute_list_end()
	matter_texture.texture_rd_rid = _matter[_fog_side]
	density_texture.texture_rd_rid = _dye[_fog_side]
	if timing != 0: GPU_TIMING.mark(_rd, timing, "publish")


func _dispatch(list: int, set_index: int, mode: int, parameters: PackedFloat32Array) -> void:
	parameters[3] = float(mode)
	var bytes := parameters.to_byte_array()
	_rd.compute_list_bind_uniform_set(list, _sets[set_index], 0)
	_rd.compute_list_set_push_constant(list, bytes, bytes.size())
	var resolution := _dye_grid if mode == 5 else _grid
	_rd.compute_list_dispatch(list, ceili(resolution.x / 8.0), ceili(resolution.y / 8.0), 1)
	_rd.compute_list_add_barrier(list)


func _image(format_id: RenderingDevice.DataFormat, resolution: Vector2i = Vector2i.ZERO) -> RID:
	var dimensions := _grid if resolution == Vector2i.ZERO else resolution
	var format := RDTextureFormat.new()
	format.width = dimensions.x
	format.height = dimensions.y
	format.format = format_id
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var rid := _keep(_rd.texture_create(format, RDTextureView.new()))
	_rd.texture_clear(rid, Color(0, 0, 0, 0), 0, 1, 0, 1)
	return rid


func _keep(rid: RID) -> RID:
	_owned.append(rid)
	return rid


func _take_resources() -> Array[RID]:
	var previous := _owned
	_owned = []
	_states = []
	_matter = []
	_dye = []
	_pressures = []
	_sets = []
	_fog_side = 0
	return previous


func _free_resources(resources: Array[RID]) -> void:
	if _rd != null:
		resources.reverse()
		for rid in resources:
			_rd.free_rid(rid)


func dispose() -> void:
	texture.texture_rd_rid = RID()
	boundary_texture.texture_rd_rid = RID()
	matter_texture.texture_rd_rid = RID()
	density_texture.texture_rd_rid = RID()
	_free_resources(_take_resources())
	_program = null
	_rd = null


func deactivate() -> void:
	# Preserve sampler bindings across OFF -> ON, while freeing solver storage.
	var previous := _take_resources()
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	_grid = Vector2i.ONE
	var empty := _image(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	texture.texture_rd_rid = empty
	boundary_texture.texture_rd_rid = empty
	matter_texture.texture_rd_rid = empty
	density_texture.texture_rd_rid = empty
	_free_resources(previous)
