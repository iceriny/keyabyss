class_name FrameCapture
extends Node
## Opt-in frame trace, saved when the game exits or an explicit duration expires.

var seconds: int = 0
var output_path: String = ""

var _app: KeyabyssApp
var _frames: Array[Dictionary] = []
var _viewports: Array[SubViewport] = []
var _main_rid: RID
var _started_us: int
var _previous_us: int
var _last_route: String = ""
var _active: bool = false
var _started_at: String = ""
var _resources_start: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var enabled := false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--frame-profile":
			enabled = true
		elif argument.begins_with("--frame-profile-seconds="):
			var value := argument.trim_prefix("--frame-profile-seconds=")
			if value.is_valid_int():
				seconds = 0 if value.to_int() == 0 else clampi(value.to_int(), 5, 120)
			else:
				push_warning("FrameCapture: invalid duration; using %d seconds" % seconds)
	if not enabled:
		return
	seconds = 0 if seconds == 0 else clampi(seconds, 5, 120)
	_app = get_parent() as KeyabyssApp
	_main_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_main_rid, true)
	_refresh_viewports()
	_started_at = Time.get_datetime_string_from_system()
	_resources_start = _resource_snapshot()
	_started_us = Time.get_ticks_usec()
	_previous_us = _started_us
	_active = true
	print("FrameCapture: recording until game exit" if seconds == 0 else "FrameCapture: recording %d seconds" % seconds)
	set_process(true)


func _process(_delta: float) -> void:
	var now_us := Time.get_ticks_usec()
	var elapsed_ms := float(now_us - _started_us) / 1000.0
	if _last_route != _app.route:
		_refresh_viewports()
		_last_route = _app.route
	var subviews: Array[Dictionary] = []
	for viewport: SubViewport in _viewports:
		if is_instance_valid(viewport):
			var rid := viewport.get_viewport_rid()
			var drawing := viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED
			subviews.append({
				"path": str(viewport.get_path()),
				"update_mode": viewport.render_target_update_mode,
				"cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid) if drawing else 0.0,
				"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid) if drawing else 0.0,
			})
	_frames.append({
		"t_ms": elapsed_ms,
		"wall_ms": float(now_us - _previous_us) / 1000.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_setup_cpu_ms": RenderingServer.get_frame_setup_time_cpu(),
		"main_render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_main_rid),
		"main_render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_main_rid),
		"subviews": subviews,
		"route": _app.route,
	})
	_previous_us = now_us
	if seconds > 0 and elapsed_ms >= seconds * 1000.0:
		_finish()


func _exit_tree() -> void:
	if _active:
		_finish()


func _refresh_viewports() -> void:
	var found: Array[SubViewport] = []
	_collect_viewports(_app, found)
	for viewport: SubViewport in _viewports:
		if is_instance_valid(viewport) and not found.has(viewport):
			RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), false)
	for viewport: SubViewport in found:
		if not _viewports.has(viewport):
			RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	_viewports = found


func _collect_viewports(node: Node, found: Array[SubViewport]) -> void:
	for child: Node in node.get_children():
		if child is SubViewport:
			found.append(child as SubViewport)
		_collect_viewports(child, found)


func _finish() -> void:
	_active = false
	set_process(false)
	RenderingServer.viewport_set_measure_render_time(_main_rid, false)
	for viewport: SubViewport in _viewports:
		if is_instance_valid(viewport):
			RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), false)
	var path := output_path
	if path.is_empty():
		path = "user://performance/frames-%s-%d.json" % [Time.get_datetime_string_from_system().replace(":", "-"), OS.get_process_id()]
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("FrameCapture: cannot create output directory (%d): %s" % [error, directory])
		return
	var report := {
		"schema": 1,
		"started_at": _started_at,
		"duration_requested_s": seconds,
		"capture_mode": "until_exit" if seconds == 0 else "timed",
		"warmup_ms": 2000.0,
		"timing_note": "wall_ms is the interval since the previous callback. process_ms is Performance.TIME_PROCESS (whole engine frame, not isolated GDScript CPU time). Physics and viewport render times are the most recently completed frame and may lag by one row. Disabled viewports report zero rather than stale timestamps. Report serialization runs only after capture has stopped.",
		"system": {
			"game_version": ProjectSettings.get_setting("application/config/version"),
			"debug_build": OS.is_debug_build(),
			"quality": _app.settings.quality,
			"fluid_quality": _app.settings.fluid_quality,
			"reduced_motion": _app.settings.reduce_motion,
			"fullscreen": _app.settings.fullscreen,
			"os": OS.get_name(),
			"cpu": OS.get_processor_name(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"display_px": str(DisplayServer.screen_get_size()),
			"window_px": str(get_window().size),
			"engine": Engine.get_version_info().get("string", ""),
			"renderer": RenderingServer.get_current_rendering_method(),
			"driver": RenderingServer.get_current_rendering_driver_name(),
		},
		"resources_start": _resources_start,
		"resources_end": _resource_snapshot(),
		"summary_after_warmup": _summarize(_frames, ""),
		"frames": _frames,
	}
	var routes: Dictionary = {}
	for frame: Dictionary in _frames:
		routes[frame["route"]] = true
	var phases: Dictionary = {}
	for route: String in routes:
		phases[route] = _summarize(_frames, route)
	report["summary_by_route_after_warmup"] = phases
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("FrameCapture: cannot open output (%d): %s" % [FileAccess.get_open_error(), path])
		return
	file.store_string(JSON.stringify(report))
	file.close()
	print("FrameCapture: %s" % ProjectSettings.globalize_path(path))


func _resource_snapshot() -> Dictionary:
	return {
		"process_memory_bytes": OS.get_static_memory_usage(),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}


func _summarize(frames: Array[Dictionary], route: String) -> Dictionary:
	var times: Array[float] = []
	var over_33 := 0
	var over_50 := 0
	var spikes: Array[Dictionary] = []
	for frame: Dictionary in frames:
		if float(frame["t_ms"]) < 2000.0 or (not route.is_empty() and frame["route"] != route):
			continue
		var duration: float = frame["wall_ms"]
		times.append(duration)
		if duration > 33.3:
			over_33 += 1
		if duration > 50.0:
			over_50 += 1
			spikes.append({"t_ms": frame["t_ms"], "wall_ms": duration, "route": frame["route"]})
	if times.is_empty():
		return {"frames": 0}
	times.sort()
	return {
		"frames": times.size(),
		"p50_ms": _percentile(times, 0.50),
		"p95_ms": _percentile(times, 0.95),
		"p99_ms": _percentile(times, 0.99),
		"max_ms": times.back(),
		"over_33_3_ms": over_33,
		"over_50_ms": over_50,
		"spikes_over_50_ms": spikes,
	}


func _percentile(sorted: Array[float], fraction: float) -> float:
	return sorted[maxi(0, int(ceil(fraction * sorted.size())) - 1)]
