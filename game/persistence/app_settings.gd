class_name AppSettings
extends RefCounted

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
	Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1680, 1050),
	Vector2i(1920, 1200), Vector2i(2560, 1600),
	Vector2i(1024, 768), Vector2i(1600, 1200), Vector2i(1280, 1024),
	Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(5120, 1440),
]

var fullscreen: bool = false
var resolution := Vector2i.ZERO
var ui_scale: float = 1.0
var reduce_motion: bool = false
var quality: int = 2
var fluid_quality: int = 2
var show_fps: bool = false
var vsync: bool = true
var first_setup_complete: bool = false
var show_meaning: bool = true # Enemy overhead meanings; the bottom cast hint is independent.
var volume: float = 0.28
var sound: bool = true
var ambience: bool = true
var effects_volume: float = 1.0
var intro_complete: bool = false
var book_id: String = "frost"
var difficulty: String = "normal"
var run_seed: String = ""
var vocabulary_id: String = "primary3"
var min_length: int = 1
var max_length: int = 12
var progressive: bool = true
var last_error: String = ""
var path: String
var _display_applied := false
var _applied_resolution := Vector2i.ZERO
var _applied_fullscreen := false
var _windowed_size := Vector2i(1920, 1080)


func _init(settings_path: String = "user://settings.cfg") -> void:
	path = settings_path


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK or int(config.get_value("meta", "schema_version", 0)) != 1:
		last_error = "设置文件无法读取；已保留原文件。"
		if config.load(path + ".bak") != OK or int(config.get_value("meta", "schema_version", 0)) != 1:
			return
		last_error += "已恢复上次备份。"
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	var stored_resolution: Variant = config.get_value("display", "resolution", Vector2i.ZERO)
	resolution = stored_resolution if stored_resolution is Vector2i and stored_resolution in RESOLUTIONS else Vector2i.ZERO
	ui_scale = clampf(float(config.get_value("display", "ui_scale", 1.0)), 0.85, 1.25)
	reduce_motion = bool(config.get_value("display", "reduce_motion", false))
	quality = clampi(int(config.get_value("display", "quality", 2)), 0, 2)
	fluid_quality = clampi(int(config.get_value("display", "fluid_quality", 2)), 0, 4)
	show_fps = bool(config.get_value("display", "show_fps", false))
	vsync = bool(config.get_value("display", "vsync", true))
	# Existing players keep their choices; new user directories open calibration.
	first_setup_complete = bool(config.get_value("presentation", "first_setup_complete", true))
	show_meaning = bool(config.get_value("words", "show_meaning", true))
	volume = clampf(float(config.get_value("audio", "volume", 0.28)), 0.0, 1.0)
	sound = bool(config.get_value("audio", "sound", true))
	ambience = bool(config.get_value("audio", "ambience", true))
	effects_volume = clampf(float(config.get_value("audio", "effects_volume", 1.0)), 0.0, 1.0)
	book_id = str(config.get_value("preparation", "book_id", "frost"))
	difficulty = str(config.get_value("preparation", "difficulty", "normal"))
	run_seed = str(config.get_value("preparation", "run_seed", ""))
	vocabulary_id = str(config.get_value("words", "vocabulary_id", "primary3"))
	min_length = clampi(int(config.get_value("words", "min_length", 1)), 1, 24)
	max_length = clampi(int(config.get_value("words", "max_length", 12)), min_length, 24)
	progressive = bool(config.get_value("words", "progressive", true))
	intro_complete = bool(config.get_value("presentation", "intro_complete", false))


func save_settings() -> bool:
	# Startup reads display settings before the application and its diagnostics load.
	var logger: Script = load("res://app/debug_log.gd")
	var started: int = logger.begin()
	var saved := _save_settings()
	logger.operation(&"settings.save", started, {"ok": saved, "error": last_error}, true)
	return saved


func _save_settings() -> bool:
	last_error = ""
	var config := ConfigFile.new()
	config.set_value("meta", "schema_version", 1)
	for property: String in ["fullscreen", "resolution", "ui_scale", "reduce_motion", "quality", "fluid_quality", "show_fps", "vsync"]:
		config.set_value("display", property, get(property))
	for property: String in ["show_meaning", "vocabulary_id", "min_length", "max_length", "progressive"]:
		config.set_value("words", property, get(property))
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "sound", sound)
	config.set_value("audio", "ambience", ambience)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("presentation", "intro_complete", intro_complete)
	config.set_value("presentation", "first_setup_complete", first_setup_complete)
	for property: String in ["book_id", "difficulty", "run_seed"]:
		config.set_value("preparation", property, get(property))
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return _save_error("创建设置目录", error)
	error = config.save(path + ".tmp")
	if error != OK:
		return _save_error("写入临时设置", error)
	var verify := ConfigFile.new()
	error = verify.load(path + ".tmp")
	if error != OK:
		return _save_error("读取临时设置", error)
	if FileAccess.file_exists(path):
		# A corrupt primary must not overwrite the valid backup used for recovery.
		var previous := ConfigFile.new()
		if previous.load(path) == OK and int(previous.get_value("meta", "schema_version", 0)) == 1:
			error = DirAccess.copy_absolute(path, path + ".bak")
			if error != OK:
				return _save_error("备份设置", error)
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		return _save_error("替换设置文件", error)
	return true


func _save_error(action: String, error: Error) -> bool:
	last_error = "设置未保存：%s失败（%s）。" % [action, error_string(error)]
	return false


func apply(window: Window) -> void:
	var native_window := DisplayServer.get_name() != "headless"
	# One output resolution for the whole game. Layout scaling belongs to GameDisplay.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	window.min_size = Vector2i(960, 540)
	if not _display_applied or fullscreen != _applied_fullscreen or resolution != _applied_resolution:
		if fullscreen and not _applied_fullscreen:
			_windowed_size = window.size
		if native_window:
			window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if not fullscreen:
			var requested := resolution if resolution != Vector2i.ZERO else Vector2i(1920, 1080)
			if _display_applied and _applied_fullscreen and resolution == _applied_resolution:
				requested = _windowed_size
			if native_window:
				var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
				var borders := window.get_size_with_decorations() - window.size
				var available := (usable.size - borders - Vector2i(16, 16)).max(window.min_size)
				var fit := minf(1.0, minf(float(available.x) / requested.x, float(available.y) / requested.y))
				window.size = Vector2i(Vector2(requested) * fit)
				window.position = usable.position + Vector2i(Vector2(usable.size - window.size) * 0.5)
			else:
				window.size = requested
		_applied_resolution = resolution
		_applied_fullscreen = fullscreen
		_display_applied = true
	apply_frame_pacing(window)
	update_output(window)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


func apply_frame_pacing(window: Window) -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED, window.get_window_id())
	# Turning off synchronization still respects this monitor's refresh ceiling.
	var refresh_rate := DisplayServer.screen_get_refresh_rate(window.current_screen)
	Engine.max_fps = 0 if vsync or refresh_rate <= 0.0 else roundi(refresh_rate)


func update_output(window: Window) -> void:
	var output := resolution if fullscreen and resolution != Vector2i.ZERO else window.size
	if window.content_scale_size != output:
		window.content_scale_size = output
