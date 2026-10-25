class_name FrostGrowth
extends Node
## Bounded dendrite growth and basal deposition; film settles for ten seconds.
const SHADER: RDShaderFile = preload("res://ui/effects/frost_growth.glsl")
const SURFACE_SHADER: RDShaderFile = preload("res://ui/effects/frost_surface.glsl")
const GPU_TIMING = preload("res://ui/effects/gpu_effect_timing.gd")
const GRID := 320
const MAX_STEPS := 3000
var grid := GRID
var max_steps := MAX_STEPS
var texture := Texture2DRD.new()
var surface_texture := Texture2DRD.new()
var vapor_density := .42
var iteration := 0
var surface_age := 0.0
var _surface_initialized := false
var _seed := 1
var _extra_roots := 0
var _rd: RenderingDevice
var _pipeline: RID
var _program: EffectPipeline
var _surface_program: EffectPipeline
var _owned: Array[RID] = []
var _images: Array[RID] = []
var _sets: Array[RID] = []
var _side := 0
var _surface_pipeline: RID
var _surface_images: Array[RID] = []
var _surface_sets: Array[RID] = []


func configure(resolution: int = GRID, seed_value: int = 1, large_region: bool = false) -> void:
	grid = resolution
	max_steps = int(MAX_STEPS * float(grid) / GRID)
	_seed = seed_value
	_extra_roots = 3 if large_region else 0
	_rd=RenderingServer.get_rendering_device()
	_program = EffectPipeline.acquire(SHADER)
	var shader := _program.shader
	_pipeline = _program.pipeline
	var format:=RDTextureFormat.new()
	format.width=grid
	format.height=grid
	format.format=RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	for i in 2: _images.append(_keep(_rd.texture_create(format,RDTextureView.new())))
	for i in 2:
		var uniforms: Array[RDUniform]=[]
		for binding in 2:
			var uniform:=RDUniform.new()
			uniform.binding=binding
			uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
			uniform.add_id(_images[i if binding==0 else 1-i])
			uniforms.append(uniform)
		_sets.append(_keep(_rd.uniform_set_create(uniforms,shader,0)))
	texture.texture_rd_rid=_images[0]
	_surface_program = EffectPipeline.acquire(SURFACE_SHADER)
	var surface_shader := _surface_program.shader
	_surface_pipeline = _surface_program.pipeline
	format.format=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	for i in 2: _surface_images.append(_keep(_rd.texture_create(format,RDTextureView.new())))
	for crystal_side in 2:
		for i in 2:
			var uniforms: Array[RDUniform]=[]
			var images: Array[RID]=[_images[crystal_side],_surface_images[i],_surface_images[1-i]]
			for binding in 3:
				var uniform:=RDUniform.new()
				uniform.binding=binding
				uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.add_id(images[binding])
				uniforms.append(uniform)
			_surface_sets.append(_keep(_rd.uniform_set_create(uniforms,surface_shader,0)))
	surface_texture.texture_rd_rid=_surface_images[0]
	reset()


func reset(advance_seed: bool = true) -> void:
	iteration=0
	surface_age=0.0
	_surface_initialized = false
	_side = 0
	if advance_seed: _seed+=1
	var list:=_rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_dispatch(list,1,2)
	_rd.compute_list_bind_compute_pipeline(list,_surface_pipeline)
	_surface_dispatch(list,0,0.0,true)
	_surface_dispatch(list,1,0.0,true)
	_rd.compute_list_end()
	texture.texture_rd_rid=_images[_side]


func step(count: int,delta: float) -> void:
	if iteration>=max_steps and surface_age>=10.0: return
	var growth_steps := mini(count, max_steps - iteration)
	if growth_steps == 0 and delta <= 0.0 and _surface_initialized: return
	var diffusion_scale := pow(float(grid)/GRID, 2.0)
	var pairs := maxi(1,ceili(delta*maxf(1.0,diffusion_scale)/.05))
	var timing := 0
	if GPU_TIMING.enabled:
		timing = GPU_TIMING.begin(_rd, "ice", get_instance_id(), 2, {
			"grid": grid, "iteration": iteration, "steps": growth_steps, "surface_pairs": pairs,
			"dispatches": growth_steps + pairs * 2, "surface_age": surface_age, "seed": _seed})
	var list:=_rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	for i in growth_steps:
		_dispatch(list,_side,0)
		_side=1-_side
		iteration+=1
	if timing != 0: GPU_TIMING.mark(_rd, timing, "growth")
	# Bound the explicit film diffusion step even when combat accelerates growth
	# or a slow frame reaches its catch-up limit. Publish on image zero each pair.
	_rd.compute_list_bind_compute_pipeline(list,_surface_pipeline)
	for part in pairs:
		_surface_dispatch(list,0,delta/(pairs*2.0),false,part==0 and (growth_steps > 0 or not _surface_initialized))
		_surface_dispatch(list,1,delta/(pairs*2.0),false,false)
	surface_age+=delta
	_surface_initialized = true
	_rd.compute_list_end()
	if growth_steps > 0: texture.texture_rd_rid=_images[_side]
	if timing != 0: GPU_TIMING.mark(_rd, timing, "surface")


func _dispatch(list: int,side: int,mode: int) -> void:
	_rd.compute_list_bind_uniform_set(list,_sets[side],0)
	var bytes:=PackedFloat32Array([mode,iteration,_seed,vapor_density, float(GRID)/grid,_extra_roots,0,0]).to_byte_array()
	_rd.compute_list_set_push_constant(list,bytes,bytes.size())
	_rd.compute_list_dispatch(list,ceili(grid/8.0),ceili(grid/8.0),1)
	_rd.compute_list_add_barrier(list)


func _surface_dispatch(list: int,side: int,delta: float,resetting: bool,refresh_enclosure: bool = true) -> void:
	_rd.compute_list_bind_uniform_set(list,_surface_sets[_side*2+side],0)
	var bytes:=PackedFloat32Array([delta,1.0 if resetting else 0.0,iteration,side if refresh_enclosure else 1]).to_byte_array()
	_rd.compute_list_set_push_constant(list,bytes,bytes.size())
	_rd.compute_list_dispatch(list,ceili(grid/8.0),ceili(grid/8.0),1)
	_rd.compute_list_add_barrier(list)


func _keep(id: RID) -> RID:
	_owned.append(id)
	return id


func dispose() -> void:
	texture.texture_rd_rid=RID()
	surface_texture.texture_rd_rid=RID()
	_owned.reverse()
	for id in _owned: _rd.free_rid(id)
	_owned.clear()
	_program = null
	_surface_program = null


func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(dispose)
