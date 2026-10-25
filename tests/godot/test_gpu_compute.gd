extends SceneTree
## Exact old/new compute outputs and paired GPU intervals, in two workloads.
const GPU_TIMING = preload("res://ui/effects/gpu_effect_timing.gd")
var workload := "baseline"
var label := ""
var reference: String
var directory: String
var old_ice: Node
var ice: FrostGrowth
var old_fluid: RefCounted
var fluid: FluidGPU
var checks: Array[Dictionary] = []
var batches: Array[Dictionary] = []
var failures := 0
var tick := 0
var source_count := 3
var iterations := 10
var grid := Vector2i(192, 108)
var fog_grid := Vector2i(384, 216)
var mask: Image


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--workload="): workload = argument.trim_prefix("--workload=")
		elif argument.begins_with("--reference="): reference = argument.trim_prefix("--reference=")
		elif argument.begins_with("--label="): label = argument.trim_prefix("--label=").validate_filename()
	assert(workload in ["baseline", "extreme"] and not reference.is_empty())
	directory = "res://.temp/gpu-compute-20261025/" + ((label + "-") if not label.is_empty() else "") + workload
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(FpsDisplay.create())
	if workload == "extreme":
		grid = Vector2i(768, 432)
		fog_grid = Vector2i(1536, 864)
		source_count = 36
		iterations = 24
	old_ice = load(reference.path_join("frost_growth.gd")).new()
	ice = FrostGrowth.new()
	old_fluid = load(reference.path_join("fluid_gpu.gd")).new()
	fluid = FluidGPU.new()
	root.add_child(old_ice)
	root.add_child(ice)
	mask = Image.create(16, 16, false, Image.FORMAT_R8)
	mask.fill(Color.WHITE)
	mask.set_pixel(8, 8, Color.BLACK)
	RenderingServer.call_on_render_thread(_configure)
	await RenderingServer.frame_post_draw
	var stable_matter := fluid.matter_texture.get_rid()
	var stable_dye := fluid.density_texture.get_rid()
	_compare_outputs("initial")
	# Include attached cells at corners/edges to exercise clamped donor centers.
	RenderingServer.call_on_render_thread(_set_ice_edges)
	await RenderingServer.frame_post_draw
	for count in [1, 31, 128]:
		RenderingServer.call_on_render_thread(_advance.bind(count, false))
		await RenderingServer.frame_post_draw
		_compare_outputs("growth-" + str(count))
	RenderingServer.call_on_render_thread(_pause)
	await RenderingServer.frame_post_draw
	_compare_outputs("pause")
	_save()
	if failures == 0:
		assert(GPU_TIMING.start(_receive))
		GPU_TIMING.set_context({"workload": workload, "phase": "paired-compute"})
		# Both implementations receive identical inputs each frame. Readbacks are
		# outside these timestamp intervals; these are compute costs, not game FPS.
		for sample in 45:
			RenderingServer.call_on_render_thread(_advance.bind(8 if workload == "baseline" else 24, sample % 2 == 0))
			await RenderingServer.frame_post_draw
		_compare_outputs("continuous")
		for _frame in RenderingServer.get_rendering_device().get_frame_delay() + 2:
			await RenderingServer.frame_post_draw
		GPU_TIMING.stop()
		await process_frame
		_check(fluid.matter_texture.get_rid() == stable_matter and fluid.density_texture.get_rid() == stable_dye, "public texture identity")
		RenderingServer.call_on_render_thread(_reset)
		await RenderingServer.frame_post_draw
		_compare_outputs("reset-reconfigure")
		RenderingServer.call_on_render_thread(_advance.bind(1, false))
		await RenderingServer.frame_post_draw
		_compare_outputs("restart")
	_save()
	old_ice.queue_free()
	ice.queue_free()
	RenderingServer.call_on_render_thread(old_fluid.dispose)
	RenderingServer.call_on_render_thread(fluid.dispose)
	await process_frame
	await process_frame
	print("GPU_COMPUTE ", workload, " checks=", checks.size(), " failures=", failures, " evidence=", directory)
	quit(0 if failures == 0 else 1)


func _compile(path: String) -> RDShaderFile:
	var source := RDShaderSource.new()
	source.source_compute = FileAccess.get_file_as_string(path).replace("#[compute]", "")
	var spirv := RenderingServer.get_rendering_device().shader_compile_spirv_from_source(source)
	assert(spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE).is_empty(), spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
	var shader := RDShaderFile.new()
	shader.set_bytecode(spirv)
	shader.take_over_path(path)
	return shader


func _configure() -> void:
	old_ice.reference_shader = _compile(reference.path_join("frost_growth.glsl"))
	old_fluid.reference_shader = _compile(reference.path_join("fluid_solver.glsl"))
	var resolution := 128 if workload == "baseline" else 384
	old_ice.configure(resolution, 31415, workload == "extreme")
	ice.configure(resolution, 31415, workload == "extreme")
	old_fluid.configure(grid, fog_grid, mask)
	fluid.configure(grid, fog_grid, mask)


func _set_ice_edges() -> void:
	var rd := RenderingServer.get_rendering_device()
	# Write through storage usage, matching the solver's actual texture contract.
	var source := RDShaderSource.new()
	source.source_compute = "#version 450\nlayout(local_size_x=1) in; layout(set=0,binding=0,rgba32f) uniform image2D cells; void main(){ivec2 n=imageSize(cells);vec4 s=vec4(0,.025,1,1);imageStore(cells,ivec2(0),s);imageStore(cells,ivec2(n.x-1,0),s);imageStore(cells,ivec2(0,n.y-1),s);}"
	var shader := rd.shader_create_from_spirv(rd.shader_compile_spirv_from_source(source))
	var pipeline := rd.compute_pipeline_create(shader)
	var sets: Array[RID] = []
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipeline)
	for texture: Texture2DRD in [old_ice.texture, ice.texture]:
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.add_id(texture.texture_rd_rid)
		var bindings := rd.uniform_set_create([uniform], shader, 0)
		sets.append(bindings)
		rd.compute_list_bind_uniform_set(list, bindings, 0)
		rd.compute_list_dispatch(list, 1, 1, 1)
		rd.compute_list_add_barrier(list)
	rd.compute_list_end()
	for bindings in sets: rd.free_rid(bindings)
	rd.free_rid(pipeline)
	rd.free_rid(shader)


func _advance(count: int, reverse: bool) -> void:
	var inputs := PackedFloat32Array()
	for index in source_count + 2:
		var influence := FluidInfluence.new()
		influence.center = Vector2(220 + index * 77 % 1400, 150 + index * 137 % 700) + Vector2(sin(tick * .07), cos(tick * .09)) * 24
		influence.extent = Vector2(70, 45)
		influence.velocity = Vector2(60, -35)
		influence.rotation = index * .17
		influence.density = .8
		influence.temperature = .4
		influence.spin = 15
		influence.expansion = 12
		influence.medium = FluidMedium.new()
		influence.medium.dissipation = .7
		influence.medium.emission = .4
		if index >= source_count: influence.density = 0
		inputs.append_array(influence.packed())
	var parameters := PackedFloat32Array([1920, 1080, 1.0 / 60.0, 0, 12, -6, 0, 15, .2, .1, .1, tick / 60.0, source_count, 2, 1, .1, 0, 240, 0, 20, .2, 0, 0, 0])
	for original in ([false, true] if reverse else [true, false]):
		var token := 0
		var rd := RenderingServer.get_rendering_device()
		if original:
			if GPU_TIMING.enabled: token = GPU_TIMING.begin(rd, "reference_ice", old_ice.get_instance_id(), 1, {"grid": ice.grid, "steps": count, "sample": tick})
			old_ice.step(count, 1.0 / 60.0)
			if token != 0: GPU_TIMING.mark(rd, token, "complete")
			if GPU_TIMING.enabled: token = GPU_TIMING.begin(rd, "reference_fluid", old_fluid.get_instance_id(), 1, {"grid": [grid.x, grid.y], "sample": tick})
			old_fluid.step(parameters.duplicate(), inputs, iterations)
			if token != 0: GPU_TIMING.mark(rd, token, "complete")
		else:
			ice.step(count, 1.0 / 60.0)
			fluid.step(parameters.duplicate(), inputs, iterations)
	tick += 1


func _pause() -> void:
	old_ice.step(0, 0)
	ice.step(0, 0)


func _reset() -> void:
	old_ice.reset(false)
	ice.reset(false)
	old_fluid.deactivate()
	fluid.deactivate()
	old_fluid.configure(grid, fog_grid, mask)
	fluid.configure(grid, fog_grid, mask)


func _compare_outputs(phase: String) -> void:
	var pairs: Array = [["ice", old_ice.texture, ice.texture], ["film", old_ice.surface_texture, ice.surface_texture], ["velocity", old_fluid.texture, fluid.texture], ["matter", old_fluid.matter_texture, fluid.matter_texture], ["density", old_fluid.density_texture, fluid.density_texture]]
	for pair: Array in pairs:
		var a: Image = pair[1].get_image()
		var b: Image = pair[2].get_image()
		_check(a.get_data() == b.get_data(), phase + "/" + str(pair[0]))
	_save()


func _check(condition: bool, check_label: String) -> void:
	checks.append({"check": check_label, "passed": condition})
	if not condition:
		failures += 1
		push_error(check_label)


func _receive(batch: Dictionary) -> void:
	batches.append(batch)


func _save() -> void:
	var hashes: Dictionary = {}
	for resource: String in ["ui/effects/frost_growth.gd", "ui/effects/frost_growth.glsl", "ui/effects/fluid_gpu.gd", "ui/effects/fluid_solver.glsl", "ui/effects/gpu_effect_timing.gd", "tests/godot/test_gpu_compute.gd"]:
		hashes[resource] = FileAccess.get_sha256("res://" + resource)
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"workload": workload, "reference": reference, "checks": checks, "failures": failures, "engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(), "source_sha256": hashes}))
	var gpu_file := FileAccess.open(directory.path_join("gpu-effects.jsonl"), FileAccess.WRITE)
	for batch in batches: gpu_file.store_line(JSON.stringify(batch))
