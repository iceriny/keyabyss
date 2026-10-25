class_name RenderPreparation
extends Node
## Replays renderer primitives using authored materials, without gameplay nodes.

signal compute_completed
@export var scenes: Array[PackedScene] = []
@export var materials: Array[Material] = []
@export var computes: Array[RDShaderFile] = []
var _programs: Array[EffectPipeline] = []
var _seen_scenes: Dictionary[String, bool] = {}
var _seen_materials: Dictionary[int, bool] = {}
var _catalog: Array[Material] = []
var _variants: Array[Material] = []
@onready var viewport: SubViewport = $World
@onready var light: PointLight2D = $World/Light
@onready var particles: GPUParticles2D = $World/Particles
@onready var probes: Array[CanvasItem] = [$World/Quad, $World/Polygon, $World/Mesh, $World/Line]


func prepare(feedback: LoadingFeedback) -> void:
	if RenderingServer.get_rendering_device() == null:
		return
	for scene in scenes:
		_collect_scene(scene)
	for material in materials:
		_collect_material(material)
	feedback.update_stage("正在准备元素效果", 0, computes.size())
	for index in computes.size():
		await _present()
		RenderingServer.call_on_render_thread(_prepare_compute.bind(computes[index]))
		await compute_completed
		feedback.update_stage("正在准备元素效果", index + 1, computes.size())
	await _present()
	RenderingServer.call_on_render_thread(_exercise_compute)
	await compute_completed
	LightningArc.prepare_geometry()
	var motion_kernel: RefCounted = preload("res://ui/effects/FluidMotionKernel.cs").new()
	motion_kernel.call("Prepare")
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var total := _catalog.size()
	print("[RENDER] Material preparation: %d resources" % total)
	for index in total:
		feedback.update_stage("正在准备画面与光效", index, total)
		await _present()
		var candidate := _catalog[index]
		if candidate is ParticleProcessMaterial or (candidate is ShaderMaterial and (candidate as ShaderMaterial).shader.get_mode() == Shader.MODE_PARTICLES):
			await _prepare_particles(candidate)
		else:
			for probe in probes:
				probe.material = candidate
			particles.material = candidate
			particles.restart()
			light.enabled = false
			await _present()
			light.enabled = true
			await _present()
	feedback.update_stage("画面准备完成", total, total)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	particles.emitting = false
	for probe in probes:
		probe.material = null
	particles.material = null
	await _present()
	print("[RENDER] Material preparation complete | canvas=%d" % int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)))


func _prepare_particles(candidate: Material) -> void:
	particles.material = null
	var process := candidate.duplicate() as Material
	_variants.append(process)
	particles.process_material = process
	if process is ShaderMaterial:
		process.set_shader_parameter("domain_size", Vector2(512, 512))
		process.set_shader_parameter("scale_range", Vector2(1, 2))
		process.set_shader_parameter("tint", Color.WHITE)
	particles.restart()
	await _present()
	await _present()
	if process is ParticleProcessMaterial:
		var box := process.duplicate() as ParticleProcessMaterial
		box.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		box.emission_box_extents = Vector3(8, 8, 0)
		_variants.append(box)
		particles.process_material = box
		particles.restart()
		await _present()
	particles.process_material = $World/ProcessTemplate.process_material


func _collect_scene(scene: PackedScene) -> void:
	if _seen_scenes.has(scene.resource_path): return
	_seen_scenes[scene.resource_path] = true
	var state := scene.get_state()
	for index in state.get_node_count():
		var nested := state.get_node_instance(index)
		if nested != null: _collect_scene(nested)
		for property in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index, property)
			if value is Material: _collect_material(value)


func _collect_material(material: Material) -> void:
	var key := material.get_instance_id()
	if _seen_materials.has(key): return
	_seen_materials[key] = true
	_catalog.append(material)


func _prepare_compute(source: RDShaderFile) -> void:
	_programs.append(EffectPipeline.acquire(source))
	compute_completed.emit.call_deferred()


func _exercise_compute() -> void:
	var solver := FluidGPU.new()
	var mask := Image.create(1, 1, false, Image.FORMAT_R8)
	mask.fill(Color.WHITE)
	solver.configure(Vector2i(16, 16), Vector2i(16, 16), mask)
	solver.step(PackedFloat32Array([16, 16, 0.016, 0, 0, 0, 0, 0, 0.35, 0.16, 0.5, 0, 0, 0, 0, 0, 0, 240, 0, 0, 0, 0, 0, 0]), PackedFloat32Array(), 2)
	var fire := Combustion.new()
	fire.configure(solver.texture, Vector2i(16, 16))
	fire.advance(PackedFloat32Array([16, 16, 0.016, 0]), PackedFloat32Array())
	var frost := FrostGrowth.new()
	frost.configure(16)
	frost.step(2, 0.016)
	frost.dispose()
	frost.free()
	fire.dispose()
	fire.free()
	solver.dispose()
	compute_completed.emit.call_deferred()


func _present() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
