class_name EffectPipeline
extends RefCounted
## Render-thread-only programs. Instances own data; preparation retains programs.

static var _programs: Dictionary[String, WeakRef] = {}
var shader: RID
var pipeline: RID


static func acquire(source: RDShaderFile) -> EffectPipeline:
	var key := source.resource_path
	if _programs.has(key):
		var existing := _programs[key].get_ref() as EffectPipeline
		if existing != null:
			return existing
	var rd := RenderingServer.get_rendering_device()
	var program := EffectPipeline.new()
	var started := Time.get_ticks_usec()
	program.shader = rd.shader_create_from_spirv(source.get_spirv())
	program.pipeline = rd.compute_pipeline_create(program.shader)
	_programs[key] = weakref(program)
	print("[RENDER] Compute ready: %s (%.1f ms)" % [key.get_file(), (Time.get_ticks_usec() - started) / 1000.0])
	return program


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and shader.is_valid():
		RenderingServer.call_on_render_thread(_release.bind(pipeline, shader))


static func _release(pipeline_rid: RID, shader_rid: RID) -> void:
	var rd := RenderingServer.get_rendering_device()
	rd.free_rid(pipeline_rid)
	rd.free_rid(shader_rid)
