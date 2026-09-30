class_name GameDisplay
extends Control
## Output pixels and logical layout are independent; all layers share one pixel budget.

signal layout_changed

const DESIGN_SIZE := Vector2(1920, 1080)
var settings: AppSettings


func _ready() -> void:
	# Moving word labels share the world's subpixel positions; static UI uses layout coordinates.
	get_window().gui_snap_controls_to_pixels = false
	get_window().size_changed.connect(refresh, CONNECT_DEFERRED)
	refresh()


func refresh() -> void:
	settings.update_output(get_window())
	var output := Vector2(get_window().content_scale_size)
	var layout_scale := minf(output.x / DESIGN_SIZE.x, output.y / DESIGN_SIZE.y) * settings.ui_scale
	get_window().oversampling_override = maxf(1.0, ceilf(layout_scale))
	scale = Vector2.ONE * layout_scale
	size = output / layout_scale
	layout_changed.emit()
