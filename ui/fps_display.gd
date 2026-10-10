class_name FpsDisplay
extends Label
## Counts presented process frames against wall time, including long frames.

var frames_per_second := 0.0
var sample_ready := false
var _frames := 0
var _started_usec := 0
var _preparation_frames := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_override("font", preload("res://assets/fonts/jinghua-song.ttf"))
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color("b3c7c2"))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -130.0
	offset_right = -24.0
	offset_top = 8.0
	offset_bottom = 28.0
	text = "— FPS"


static func create() -> FpsDisplay:
	return load("res://ui/fps_display.tscn").instantiate() as FpsDisplay


func _ready() -> void:
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()


func restart_sampling(preparation_frames: int = 0) -> void:
	_preparation_frames = preparation_frames
	_started_usec = 0
	_frames = 0
	sample_ready = false
	text = "准备中…" if preparation_frames > 0 else "— FPS"


func _visibility_changed() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree(): restart_sampling(_preparation_frames)


func _process(_delta: float) -> void:
	if _preparation_frames > 0:
		_preparation_frames -= 1
		return
	var now := Time.get_ticks_usec()
	if _started_usec == 0:
		_started_usec = now
		return
	_frames += 1
	var elapsed := float(now - _started_usec) / 1000000.0
	if elapsed < .5: return
	frames_per_second = _frames / elapsed
	sample_ready = true
	text = "%d FPS" % roundi(frames_per_second)
	_started_usec = now
	_frames = 0
