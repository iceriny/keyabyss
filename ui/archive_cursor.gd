class_name ArchiveCursor
extends Control

const CURSOR_NORMAL := "res://ui/controls/cursor-arrow.svg"
const CURSOR_HOT := "res://ui/controls/cursor-hot.svg"
const PULSE_DURATION := 0.42
const RING_RADIUS := 13.5

var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_inside_tree():
			_update_motion()

var _normal_texture: Texture2D
var _hot_texture: Texture2D
var _cursor_position := Vector2.ZERO
var _show_ring := false
var _hot := false
var _hover_pending := false
var _pulse_elapsed := PULSE_DURATION
var _ring_angle := 0.0
var _ring_tween: Tween


func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_normal_texture = _load_cursor(CURSOR_NORMAL)
	_hot_texture = _load_cursor(CURSOR_HOT)
	_apply_cursor()
	var window := get_window()
	window.mouse_exited.connect(_hide_ring)
	window.focus_exited.connect(_hide_ring)
	queue_redraw()


func _exit_tree() -> void:
	if _ring_tween and _ring_tween.is_running():
		_ring_tween.kill()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_position = get_local_mouse_position()
		_show_ring = true
		queue_redraw()
		if not _hover_pending:
			_hover_pending = true
			call_deferred("_refresh_hover")
	elif event is InputEventScreenTouch:
		_hide_ring()
	elif event is InputEventMouseButton and event.pressed and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		_cursor_position = get_local_mouse_position()
		_show_ring = true
		if not reduced_motion:
			_pulse_elapsed = 0.0
			set_process(true)
		queue_redraw()


func _process(delta: float) -> void:
	_pulse_elapsed += delta
	if _pulse_elapsed >= PULSE_DURATION:
		_pulse_elapsed = PULSE_DURATION
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if not _show_ring:
		return
	if _hot:
		for index in 12:
			var start_angle := _ring_angle + TAU * float(index) / 12.0
			draw_arc(_cursor_position, RING_RADIUS, start_angle, start_angle + TAU / 24.0, 3, Color("e6d5a7", 0.53), 1.0, true)
	else:
		draw_arc(_cursor_position, RING_RADIUS, 0.0, TAU, 48, Color("e6d5a7", 0.29), 1.0, true)
	if not reduced_motion and _pulse_elapsed < PULSE_DURATION:
		var progress := _pulse_elapsed / PULSE_DURATION
		var eased := 1.0 - pow(1.0 - progress, 2.0)
		draw_arc(_cursor_position, 6.0 + 18.0 * eased, 0.0, TAU, 48, Color("ffe8b0", 0.8 * (1.0 - eased)), 1.0, true)


func _load_cursor(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _apply_cursor() -> void:
	var arrow_texture := _hot_texture if _hot and _hot_texture else _normal_texture
	if arrow_texture:
		Input.set_custom_mouse_cursor(arrow_texture, Input.CURSOR_ARROW, Vector2(2, 2))
	if _hot_texture:
		Input.set_custom_mouse_cursor(_hot_texture, Input.CURSOR_POINTING_HAND, Vector2(2, 2))
	if _normal_texture:
		Input.set_custom_mouse_cursor(_normal_texture, Input.CURSOR_IBEAM, Vector2(2, 2))


func _refresh_hover() -> void:
	_hover_pending = false
	var hovered := get_viewport().gui_get_hovered_control()
	var interactive := false
	while hovered:
		if hovered is BaseButton or hovered is LineEdit or hovered is TextEdit or hovered is SpinBox or hovered is Slider or hovered is ScrollBar or not hovered.tooltip_text.is_empty():
			interactive = true
			break
		hovered = hovered.get_parent_control()
	if interactive == _hot:
		return
	_hot = interactive
	_apply_cursor()
	_update_motion()
	queue_redraw()


func _update_motion() -> void:
	if _ring_tween and _ring_tween.is_running():
		_ring_tween.kill()
	if reduced_motion:
		_pulse_elapsed = PULSE_DURATION
		set_process(false)
	if _hot and not reduced_motion:
		_ring_tween = create_tween().set_loops()
		_ring_tween.tween_method(_set_ring_angle, 0.0, TAU, 8.0)
	else:
		_ring_angle = 0.0
		queue_redraw()


func _set_ring_angle(angle: float) -> void:
	_ring_angle = angle
	queue_redraw()


func _hide_ring() -> void:
	_show_ring = false
	queue_redraw()
