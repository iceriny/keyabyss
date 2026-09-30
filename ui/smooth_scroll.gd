class_name SmoothScroll
extends ScrollContainer

@export var wheel_step := 72.0
@export var settle_time := 0.13

var reduced_motion := false
var _target := 0.0
var _current := 0.0
var _animating := false
var _writing_scroll := false


func _ready() -> void:
	_target = float(scroll_vertical)
	_current = _target
	add_to_group("smooth_scroll_controls")
	get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	set_process(false)


func set_motion_reduced(value: bool) -> void:
	reduced_motion = value
	if value and _animating:
		_current = _target
		_write_scroll(roundi(_target))
		_animating = false
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var wheel := event as InputEventMouseButton
	if not wheel.pressed or wheel.ctrl_pressed or wheel.shift_pressed:
		return
	if wheel.button_index != MOUSE_BUTTON_WHEEL_UP and wheel.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	if vertical_scroll_mode == SCROLL_MODE_DISABLED:
		return
	# Fractional wheel input is commonly a precision touchpad: leave its native timing intact.
	if wheel.factor > 0.0 and wheel.factor < 1.0:
		return
	var bar := get_v_scroll_bar()
	var maximum := maxf(0.0, bar.max_value - bar.page)
	if maximum <= 0.0:
		return
	var direction := -1.0 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
	var amount := wheel_step * maxf(1.0, wheel.factor)
	_target = clampf((_target if _animating else float(scroll_vertical)) + direction * amount, 0.0, maximum)
	accept_event()
	if reduced_motion:
		_current = _target
		_write_scroll(roundi(_target))
		return
	_animating = true
	set_process(true)


func _process(delta: float) -> void:
	_current = lerpf(_current, _target, 1.0 - exp(-delta / maxf(0.01, settle_time)))
	if absf(_current - _target) < 0.5:
		_current = _target
		_animating = false
		set_process(false)
	_write_scroll(roundi(_current))


func _write_scroll(value: int) -> void:
	_writing_scroll = true
	scroll_vertical = value
	_writing_scroll = false


func _on_scroll_changed(value: float) -> void:
	if _writing_scroll:
		return
	_current = value
	_target = value
	_animating = false
	set_process(false)
