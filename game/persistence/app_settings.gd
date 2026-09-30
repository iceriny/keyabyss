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
	last_error = ""
	var config := ConfigFile.new()
	config.set_value("meta", "schema_version", 1)
	for property: String in ["fullscreen", "resolution", "ui_scale", "reduce_motion", "quality", "fluid_quality"]:
		config.set_value("display", property, get(property))
	for property: String in ["show_meaning", "vocabulary_id", "min_length", "max_length", "progressive"]:
		config.set_value("words", property, get(property))
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "sound", sound)
	config.set_value("audio", "ambience", ambience)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("presentation", "intro_complete", intro_complete)
	for property: String in ["book_id", "difficulty", "run_seed"]:
		config.set_value("preparation", property, get(property))
	var error := config.save(path + ".tmp")
	var verify := ConfigFile.new()
	if error == OK:
		error = verify.load(path + ".tmp")
	if error == OK and FileAccess.file_exists(path):
		# A corrupt primary must not overwrite the valid backup used for recovery.
		var previous := ConfigFile.new()
		if previous.load(path) == OK and int(previous.get_value("meta", "schema_version", 0)) == 1:
			error = DirAccess.copy_absolute(path, path + ".bak")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		last_error = "设置未保存，请检查用户目录的可写权限（%s）。" % error_string(error)
		return false
	return true


func apply(window: Window) -> void:
	# One output resolution for the whole game. Layout scaling belongs to GameDisplay.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	window.min_size = Vector2i(960, 540)
	if not _display_applied or fullscreen != _applied_fullscreen or resolution != _applied_resolution:
		var native_window := DisplayServer.get_name() != "headless"
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
	update_output(window)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


func update_output(window: Window) -> void:
	var output := resolution if fullscreen and resolution != Vector2i.ZERO else window.size
	if window.content_scale_size != output:
		window.content_scale_size = output
