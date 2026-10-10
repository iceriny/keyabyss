class_name GameDisplay
extends Control
## Output pixels and logical layout are independent; all layers share one pixel budget.

signal layout_changed

const DESIGN_SIZE := Vector2(1920, 1080)
var settings: AppSettings
var _frame_limit_screen := -1


func _ready() -> void:
	# Moving word labels share the world's subpixel positions; static UI uses layout coordinates.
	get_window().gui_snap_controls_to_pixels = false
	get_window().size_changed.connect(refresh, CONNECT_DEFERRED)
	refresh()


func _process(_delta: float) -> void:
	if settings.vsync: return
	var window := get_window()
	if window.current_screen != _frame_limit_screen:
		_frame_limit_screen = window.current_screen
		settings.apply_frame_pacing(window)


func refresh() -> void:
	settings.update_output(get_window())
	var output := Vector2(get_window().content_scale_size)
	var layout_scale := minf(output.x / DESIGN_SIZE.x, output.y / DESIGN_SIZE.y) * settings.ui_scale
	get_window().oversampling_override = maxf(1.0, ceilf(layout_scale))
	scale = Vector2.ONE * layout_scale
	size = output / layout_scale
	layout_changed.emit()
