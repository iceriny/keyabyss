class_name DebugLog
extends Node
## Sparse session journal. Frame scopes run on the main thread; file I/O runs on
## one dedicated writer. Engine/viewport monitors may describe the preceding frame.

static var enabled: bool = OS.is_debug_build()
static var _instance: DebugLog
static var _spans: Dictionary = {}

var _writer := Thread.new()
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _pending: Array[Dictionary] = []
var _stopping := false
var _dropped := 0
var _path: String
var _app: KeyabyssApp
var _viewports: Array[SubViewport] = []
var _main_rid: RID
var _started: int
var _previous: int
var _heartbeat: int
var _last_spike: int = 0
var _route: String
var _recent: Array[Dictionary] = []
var _frame_count := 0
var _slow_count := 0
var _maximum_ms := 0.0


static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func end(scope: StringName, started: int) -> float:
	if started == 0:
		return 0.0
	var duration := (Time.get_ticks_usec() - started) / 1000.0
	if not Thread.is_main_thread(): return duration
	_spans[scope] = float(_spans.get(scope, 0.0)) + duration
	return duration


static func operation(scope: StringName, started: int, details: Dictionary, always: bool = false) -> void:
	var duration := end(scope, started)
	if enabled and _instance != null and (always or duration >= 10.0):
		_instance._record("operation", {"scope": scope, "ms": duration, "details": details})


static func background_operation(scope: StringName, duration_ms: float, details: Dictionary) -> void:
	# Background latency is not CPU time spent in the frame receiving its result.
	if enabled and _instance != null:
		_instance._record("background_operation", {"scope": scope, "ms": duration_ms, "details": details})


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	var directory := "user://diagnostics"
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--debug-log": enabled = true
		elif argument == "--no-debug-log": enabled = false
		elif argument.begins_with("--diagnostics-dir="):
			directory = argument.trim_prefix("--diagnostics-dir=")
	if not enabled:
		set_process(false)
		_spans.clear()
		return
	_instance = self
	_app = get_parent() as KeyabyssApp
	directory = ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("DebugLog: cannot create directory: %s (%s)" % [directory, error_string(error)])
		enabled = false
		set_process(false)
		return
	_path = directory.path_join("session-%s-%d.jsonl" % [Time.get_datetime_string_from_system().replace(":", "-"), OS.get_process_id()])
	_started = Time.get_ticks_usec()
	_previous = _started
	_heartbeat = _started
	_main_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_main_rid, true)
	_refresh_viewports()
	error = _writer.start(_write_loop)
	if error != OK:
		push_error("DebugLog: writer could not start (%s)" % error_string(error))
		enabled = false
		set_process(false)
		return
	_record("session", {
		"version": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info().get("string", ""), "debug_build": OS.is_debug_build(),
		"os": OS.get_name(), "os_version": OS.get_version(), "cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"note": "Scopes are inclusive and can overlap. Engine/render monitors can lag a frame; recent rows preserve context. wall_ms includes render waits, OS scheduling and FPS limiting. No GPU readback or forced GPU sync.",
	})
	print("[DEBUG] Session log: ", _path)
	print("[DEBUG] Long frames >=50 ms; heartbeat every 5 s; asynchronous disk writer")


func _process(_delta: float) -> void:
	if not enabled: return
	var now := Time.get_ticks_usec()
	if _route != _app.route:
		_route = _app.route
		_refresh_viewports()
		_record("route", {"route": _route})
	var wall_ms := (now - _previous) / 1000.0
	_previous = now
	var frame := {
		"t_ms": (now - _started) / 1000.0, "frame": Engine.get_process_frames(),
		"wall_ms": wall_ms, "scopes_ms": _spans,
		"engine_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_setup_ms": RenderingServer.get_frame_setup_time_cpu(),
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_main_rid),
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_main_rid),
		"pipelines": _pipelines(),
	}
	_spans = {}
	_frame_count += 1
	_maximum_ms = maxf(_maximum_ms, wall_ms)
	if wall_ms >= 50.0:
		_slow_count += 1
		# Up to four reports/sec; a once-per-second stall is never throttled.
		if now - _last_spike >= 250000:
			_last_spike = now
			_record("long_frame", {"route": _route, "frame": frame, "preceding": _recent.duplicate(), "state": _state(), "viewports": _render_times()})
			print("[DEBUG] Long frame %.1f ms | %s | scopes %s" % [wall_ms, _route, str(frame.scopes_ms)])
	_recent.append(frame)
	if _recent.size() > 8: _recent.pop_front()
	if now - _heartbeat >= 5000000:
		var summary := {"route": _route, "fps": _frame_count * 1000000.0 / (now - _heartbeat), "max_ms": _maximum_ms, "over_50_ms": _slow_count, "state": _state(), "viewports": _render_times(), "pipelines": _pipelines()}
		_record("heartbeat", summary)
		# A render-thread marker detects queue/scheduling delay without GPU sync.
		RenderingServer.call_on_render_thread(_render_probe.bind(Time.get_ticks_usec()))
		print("[DEBUG] %s | %.1f fps | max %.1f ms | long frames %d" % [_route, summary.fps, _maximum_ms, _slow_count])
		_heartbeat = now
		_frame_count = 0
		_slow_count = 0
		_maximum_ms = 0.0


func _pipelines() -> Dictionary:
	return {"canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS), "draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW), "specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}


func _state() -> Dictionary:
	var state := {
		"quality": _app.settings.quality, "fluid_quality": _app.settings.fluid_quality,
		"reduced_motion": _app.settings.reduce_motion, "window": str(get_window().size),
		"focused": get_window().has_focus(), "paused": get_tree().paused,
		"fps_limit": Engine.max_fps, "vsync": DisplayServer.window_get_vsync_mode(),
		"home_interactive": _app.archive.interactive, "intro_complete": _app.settings.intro_complete,
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_memory_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}
	if is_instance_valid(_app.battle):
		var battle := _app.battle.session
		state.merge({"book": battle.book_id, "enemies": battle.enemies.size(), "projectiles": battle.projectiles.size(), "threats": battle.threats.size(), "effects": battle.effects.size()})
	return state


func _refresh_viewports() -> void:
	_viewports.clear()
	_collect_viewports(_app)


func _collect_viewports(node: Node) -> void:
	for child: Node in node.get_children():
		if child is SubViewport:
			_viewports.append(child as SubViewport)
			RenderingServer.viewport_set_measure_render_time(child.get_viewport_rid(), true)
		_collect_viewports(child)


func _render_times() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for viewport: SubViewport in _viewports:
		if is_instance_valid(viewport) and viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			var rid := viewport.get_viewport_rid()
			result.append({"path": str(viewport.get_path()), "cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid), "gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid)})
	return result


func _record(kind: String, data: Dictionary) -> void:
	var event := {"kind": kind, "time": Time.get_datetime_string_from_system(), "t_ms": (Time.get_ticks_usec() - _started) / 1000.0, "data": data}
	_mutex.lock()
	if _stopping:
		_mutex.unlock()
		return
	if _pending.size() < 128:
		_pending.append(event)
	else:
		_dropped += 1
	_mutex.unlock()
	_wake.post()


func _render_probe(requested: int) -> void:
	# Only immutable values and the guarded journal queue cross this boundary.
	_record("render_probe", {"queue_delay_ms": (Time.get_ticks_usec() - requested) / 1000.0})


func _write_loop() -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		call_deferred("_writer_failed", FileAccess.get_open_error())
		return
	while true:
		_wake.wait()
		_mutex.lock()
		var batch := _pending
		_pending = []
		var stopping := _stopping
		var dropped := _dropped
		_dropped = 0
		_mutex.unlock()
		if dropped > 0: file.store_line(JSON.stringify({"kind": "dropped", "count": dropped}))
		for event in batch:
			file.store_line(JSON.stringify(event))
		if not batch.is_empty():
			file.flush()
			var error := file.get_error()
			if error != OK:
				call_deferred("_writer_failed", error)
				break
		if stopping: break
	file.close()


func _writer_failed(error: int) -> void:
	push_error("DebugLog: journal write failed: %s (%s)" % [_path, error_string(error)])


func _exit_tree() -> void:
	if _writer.is_started():
		_record("session_end", {"recent": _recent})
		_mutex.lock()
		_stopping = true
		_mutex.unlock()
		_wake.post()
		_writer.wait_to_finish()
		RenderingServer.viewport_set_measure_render_time(_main_rid, false)
		for viewport in _viewports:
			if is_instance_valid(viewport): RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), false)
	_instance = null
