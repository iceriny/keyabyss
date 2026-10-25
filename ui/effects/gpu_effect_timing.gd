extends RefCounted
## Opt-in GPU queries. Recording/collection state belongs to the render thread;
## completed batches are delivered to the main thread without a GPU wait.

const PREFIX := "keyabyss_gpu/"
static var enabled := false
static var _connected := false # Main thread only.
static var _receiver: Callable
static var _context: Dictionary = {}
static var _serial := 0
static var _recording_query_frame := -1
static var _result_frame := -1
static var _marker_limit := 0
static var _markers := 0
static var _skipped := 0


static func start(receiver: Callable) -> bool:
	if not OS.get_cmdline_user_args().has("--gpu-profile"):
		return false
	if RenderingServer.get_rendering_device() == null:
		return false
	var capacity := int(ProjectSettings.get_setting("debug/settings/profiler/max_timestamp_query_elements"))
	# Leave queries for viewport/engine profiling and reserve a whole job at once.
	var limit := mini(256, floori(capacity / 2.0))
	RenderingServer.call_on_render_thread(_enable.bind(receiver, limit))
	RenderingServer.frame_post_draw.connect(_queue_collection)
	_connected = true
	return true


static func stop() -> void:
	if not _connected: return
	RenderingServer.frame_post_draw.disconnect(_queue_collection)
	_connected = false
	RenderingServer.call_on_render_thread(_disable)


static func set_context(context: Dictionary) -> void:
	if _connected:
		RenderingServer.call_on_render_thread(_set_context.bind(context.duplicate(true)))


static func _enable(receiver: Callable, limit: int) -> void:
	_receiver = receiver
	_marker_limit = limit
	_recording_query_frame = -1
	_result_frame = -1
	_markers = 0
	_skipped = 0
	enabled = true


static func _disable() -> void:
	_report_skipped()
	enabled = false
	_receiver = Callable()
	_context = {}


static func _set_context(context: Dictionary) -> void:
	_context = context


static func begin(rd: RenderingDevice, effect: String, instance: int, stages: int, details: Dictionary) -> int:
	# This identifier changes when the RD rotates its query buffer. Using it for
	# the budget avoids depending on a main-thread frame counter during recording.
	var frame := rd.get_captured_timestamps_frame()
	if frame != _recording_query_frame:
		_report_skipped()
		_recording_query_frame = frame
		_markers = 0
	if _markers + stages + 1 > _marker_limit:
		_skipped += 1
		return 0
	_markers += stages + 1
	_serial += 1
	details["effect"] = effect
	# JSON parses numbers as doubles; retain the full 64-bit ObjectID.
	details["instance"] = str(instance)
	details["recorded_render_frame"] = Engine.get_frames_drawn()
	details["query_frame_at_recording"] = frame
	details["process_frame_at_recording"] = Engine.get_process_frames()
	details["context"] = _context
	# Metadata travels with the query, so delayed results cannot inherit a new
	# book/quality or retain a freed effect instance. No pending-history map.
	rd.capture_timestamp(PREFIX + str(_serial) + "/begin/" + JSON.stringify(details))
	return _serial


static func mark(rd: RenderingDevice, token: int, stage: String) -> void:
	rd.capture_timestamp(PREFIX + str(token) + "/stage/" + stage)


static func _queue_collection() -> void:
	RenderingServer.call_on_render_thread(_collect)


static func _collect() -> void:
	if not enabled: return
	var rd := RenderingServer.get_rendering_device()
	var frame := rd.get_captured_timestamps_frame()
	if frame == _result_frame: return
	_result_frame = frame
	var jobs: Dictionary = {}
	var rows: Array[Dictionary] = []
	for index in rd.get_captured_timestamps_count():
		var name := rd.get_captured_timestamp_name(index)
		if not name.begins_with(PREFIX): continue
		var parts := name.trim_prefix(PREFIX).split("/", true, 2)
		var token := int(parts[0])
		var gpu_ns := rd.get_captured_timestamp_gpu_time(index)
		var cpu_us := rd.get_captured_timestamp_cpu_time(index)
		if parts[1] == "begin":
			jobs[token] = {"details": JSON.parse_string(parts[2]), "gpu_ns": gpu_ns, "cpu_us": cpu_us}
		else:
			var job: Dictionary = jobs[token]
			rows.append({"job": token, "stage": parts[2], "details": job.details,
				"gpu_ms": float(gpu_ns - int(job.gpu_ns)) / 1000000.0,
				"render_cpu_ms": float(cpu_us - int(job.cpu_us)) / 1000.0,
				"cpu_begin_us": job.cpu_us, "cpu_end_us": cpu_us})
			job.gpu_ns = gpu_ns
			job.cpu_us = cpu_us
	if not rows.is_empty():
		_receiver.call_deferred({"query_frame": frame, "rows": rows})


static func _report_skipped() -> void:
	if _skipped > 0:
		_receiver.call_deferred({"query_frame_at_recording": _recording_query_frame, "skipped_jobs": _skipped})
		_skipped = 0
