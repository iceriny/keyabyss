class_name Combustion
extends Node
## Passive fuel/heat transport; velocity and pressure remain owned by FluidField2D.
const SHADER: RDShaderFile = preload("res://ui/effects/combustion.glsl")
const GRID := Vector2i(512,288)
const MAX_SOURCES := 64
var grid := GRID
var configured := false
var _sources: RID
var texture := Texture2DRD.new()
var _rd: RenderingDevice
var _owned: Array[RID] = []
var _images: Array[RID] = []
var _sets: Array[RID] = []
var _pipeline: RID
var _program: EffectPipeline
var _side := 0


func configure(flow: Texture2DRD, resolution: Vector2i = GRID) -> void:
	var previous := _take_resources()
	grid = resolution
	_rd = RenderingServer.get_rendering_device()
	_program = EffectPipeline.acquire(SHADER)
	var shader := _program.shader
	_pipeline = _program.pipeline
	var sampling := RDSamplerState.new()
	sampling.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampling.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampling.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampling.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	var sampler := _keep(_rd.sampler_create(sampling))
	var format := RDTextureFormat.new()
	format.width = grid.x
	format.height = grid.y
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	for i in 2:
		_images.append(_keep(_rd.texture_create(format,RDTextureView.new())))
		_rd.texture_clear(_images[i],Color(0,0,0,0),0,1,0,1)
	_sources = _keep(_rd.storage_buffer_create(MAX_SOURCES * 32))
	for i in 2:
		var uniforms: Array[RDUniform] = []
		for binding in 3:
			var uniform := RDUniform.new()
			uniform.binding = binding
			uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE if binding == 1 else RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
			if binding != 1: uniform.add_id(sampler)
			uniform.add_id([_images[i],_images[1-i],flow.texture_rd_rid][binding])
			uniforms.append(uniform)
		var sources := RDUniform.new()
		sources.binding = 3
		sources.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		sources.add_id(_sources)
		uniforms.append(sources)
		_sets.append(_keep(_rd.uniform_set_create(uniforms,shader,0)))
	texture.texture_rd_rid = _images[0]
	_free_resources(previous)
	configured = true


func step(parameters: PackedFloat32Array) -> void:
	var sources := PackedFloat32Array([parameters[4],parameters[5],parameters[4],parameters[5],parameters[6],parameters[7],0,0])
	advance(parameters.slice(0,4),sources)


func advance(domain: PackedFloat32Array, sources: PackedFloat32Array) -> void:
	if not configured: return
	var count := mini(floori(sources.size()/8.0), MAX_SOURCES)
	if count > 0:
		var source_bytes := sources.slice(0,count*8).to_byte_array()
		_rd.buffer_update(_sources,0,source_bytes.size(),source_bytes)
	var parameters := domain.duplicate()
	parameters.append_array(PackedFloat32Array([count,0,0,0]))
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_rd.compute_list_bind_uniform_set(list,_sets[_side],0)
	var bytes := parameters.to_byte_array()
	_rd.compute_list_set_push_constant(list,bytes,bytes.size())
	_rd.compute_list_dispatch(list,ceili(grid.x/8.0),ceili(grid.y/8.0),1)
	_rd.compute_list_end()
	_side = 1-_side
	texture.texture_rd_rid = _images[_side]


func _keep(id: RID) -> RID:
	_owned.append(id)
	return id


func dispose() -> void:
	texture.texture_rd_rid = RID()
	_free_resources(_take_resources())
	_program = null


func unbind_flow() -> void:
	# Release dependencies before FluidGPU destroys its old velocity image,
	# but retain the RenderingServer sampler identity held by canvas materials.
	for id in _sets:
		_rd.free_rid(id)
		_owned.erase(id)
	_sets.clear()
	configured = false


func deactivate() -> void:
	var previous := _take_resources()
	_rd = RenderingServer.get_rendering_device()
	var format := RDTextureFormat.new()
	format.width = 1
	format.height = 1
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var empty := _keep(_rd.texture_create(format,RDTextureView.new(),[PackedByteArray([0,0,0,0,0,0,0,0])]))
	texture.texture_rd_rid = empty
	_free_resources(previous)


func _take_resources() -> Array[RID]:
	var previous := _owned
	_owned = []
	_images = []
	_sets = []
	_side = 0
	configured = false
	return previous


func _free_resources(resources: Array[RID]) -> void:
	resources.reverse()
	for id in resources: _rd.free_rid(id)


func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(dispose)
