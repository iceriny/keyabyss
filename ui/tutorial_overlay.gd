class_name TutorialOverlay
extends Control
## Read-only guidance over BattlePage. Combat input remains with InputRouter.

signal exit_requested
signal retry_requested
signal next_requested
signal step_requested(index: int)

var exit_button: OpenButton
var retry_button: OpenButton
var next_button: OpenButton
var reduced_motion := false
var _accent := Color("8bdeff")
var _step := -1
var _total := 1
var _complete := false
var _goal_ready := false
var _at_bottom := false
var _feedback: Tween
var _content: Control
var _title: Label
var _instruction: Label
var _progress: Label
var _counter: Label
var _steps: Control
var _passed_steps := 0
var _step_buttons: Array[Button] = []
var _step_name: Label
var _hovered_step := -1


static func create_overlay(book: BookPresentation, motion_reduced: bool) -> TutorialOverlay:
	var overlay := load("res://ui/scenes/tutorial_overlay.tscn").instantiate() as TutorialOverlay
	overlay.reduced_motion = motion_reduced
	overlay._accent = book.color
	overlay._bind_nodes()
	(overlay.get_node("Content/Book") as Label).text = book.title + " · 练习"
	(overlay.get_node("Content/Seal") as TextureRect).texture = ArcanaRunes.seal(book.id, 30.0)
	(overlay.get_node("Content/Seal") as TextureRect).modulate = Color(book.color, 0.55)
	return overlay


func _bind_nodes() -> void:
	_content = $Content
	_title = $Content/Title
	_instruction = $Content/Instruction
	_progress = $Content/Progress
	_counter = $Content/Counter
	_steps = $Content/Steps
	exit_button = $Content/Actions/Exit
	retry_button = $Content/Actions/Retry
	next_button = $Content/Actions/Next
	_bind_shortcut(next_button, [KEY_ENTER, KEY_KP_ENTER])
	_bind_shortcut(retry_button, [KEY_F1])
	_bind_shortcut(exit_button, [KEY_F3])
	for control: OpenButton in [exit_button, retry_button, next_button]:
		control.set_motion_reduced(reduced_motion)
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	next_button.pressed.connect(func() -> void: next_requested.emit())
	_steps.draw.connect(_draw_steps)
	($Content/GoldBranch as CrystalInlay).set_motion_reduced(reduced_motion)


func _bind_shortcut(control: OpenButton, keys: Array[Key]) -> void:
	control.shortcut = Shortcut.new()
	control.shortcut_in_tooltip = false
	control.ready.connect(func() -> void:
		var hint := control.get_node("ShortcutHint") as Control
		var key_frame := hint.get_node("KeyFrame") as Control
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			control.get_theme_stylebox(state).content_margin_left = hint.position.x + key_frame.get_combined_minimum_size().x + 8.0
		control._sync_light_text())
	for key: Key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		control.shortcut.events.append(event)


func _ready() -> void:
	resized.connect(_layout)
	_instruction.minimum_size_changed.connect(_layout)
	_progress.minimum_size_changed.connect(_layout)
	_layout()


func configure_steps(titles: PackedStringArray, passed: int) -> void:
	_step_name = Label.new()
	_step_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_name.position = Vector2(-40, 24)
	_step_name.size = Vector2(224, 27)
	_step_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step_name.add_theme_font_override("font", KeyHint.SMALL_FONT)
	_step_name.add_theme_font_size_override("font_size", 16)
	_step_name.hide()
	_steps.add_child(_step_name)
	for index in titles.size():
		var button := Button.new()
		button.name = "Step%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.size = Vector2(24, 24)
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.mouse_entered.connect(func() -> void:
			_hovered_step = index
			_step_name.text = titles[index]
			_step_name.show()
			_steps.queue_redraw())
		button.mouse_exited.connect(func() -> void:
			_hovered_step = -1
			_step_name.hide()
			_steps.queue_redraw())
		button.pressed.connect(func() -> void: step_requested.emit(index))
		_steps.add_child(button)
		_step_buttons.append(button)
	set_passed_steps(passed)


func set_passed_steps(passed: int) -> void:
	_passed_steps = passed
	_update_step_buttons()
	_steps.queue_redraw()


func _update_step_buttons() -> void:
	var stride := minf(34.0, (_steps.size.x - 12.0) / float(maxi(1, _step_buttons.size() - 1)))
	for index in _step_buttons.size():
		var button := _step_buttons[index]
		button.position = Vector2(6.0 + index * stride, 10.0) - button.size * 0.5
		button.disabled = index > _passed_steps or index == _step
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND


## index is zero-based; complete marks the whole lesson as finished.
func show_step(index: int, total: int, title: String, instruction: String, progress: String, complete: bool = false) -> void:
	assert(total > 0 and index >= 0 and index < total, "Tutorial step must be inside the lesson.")
	var changed := index != _step or complete != _complete
	_step = index
	_total = total
	_complete = complete
	_update_step_buttons()
	if changed: _at_bottom = false
	_title.text = title
	_instruction.text = instruction
	_progress.text = progress
	_layout()
	_counter.text = "练习完成" if complete else "第 %02d / %02d 步" % [index + 1, total]
	_counter.add_theme_color_override("font_color", Color("f0ddae") if complete else _accent)
	exit_button.set_caption("返回教学" if complete else "退出练习")
	next_button.set_caption("完成并返回" if index == total - 1 else "下一步")
	next_button.visible = not complete
	_steps.queue_redraw()
	if changed and is_inside_tree():
		if _feedback != null:
			_feedback.kill()
		_title.modulate.a = 1.0 if reduced_motion else 0.5
		if not reduced_motion:
			_feedback = create_tween()
			_feedback.tween_property(_title, "modulate:a", 1.0, 0.24)


func show_save_error(message: String) -> void:
	_progress.text = message
	next_button.set_caption("重试保存")


func set_goal_ready(achieved: bool) -> void:
	next_button.disabled = not achieved
	(next_button.get_node("ShortcutHint") as Control).modulate.a = 1.0 if achieved else 0.4
	next_button.set_selected_visual(achieved)
	_progress.add_theme_color_override("font_color", Color("f0ddae") if achieved else Color("e8e4d8"))
	($Content/GoalMark as ColorRect).color = Color("f0ddae") if achieved else _accent
	if achieved and not _goal_ready and not reduced_motion:
		var feedback := create_tween()
		_progress.modulate.a = 0.5
		feedback.tween_property(_progress, "modulate:a", 1.0, 0.2)
	_goal_ready = achieved


## BattlePage-local bounds, available to the host's word placement algorithm.
func get_reserved_rect() -> Rect2:
	return Rect2(position + _content.position, _content.size * _content.scale)


## Move only when the player would enter the reading area, before a dodge arrives.
func avoid_player(at: Vector2) -> void:
	if not get_reserved_rect().grow(64.0).has_point(at): return
	_at_bottom = not _at_bottom
	_layout()


func _layout() -> void:
	# GameDisplay already owns UI scaling; keep the same coordinate space as HUD.
	# Keep reading directly above the practice scene, with a stable goal and action row.
	var top := maxf(70.0, size.y * 0.5 - _content.size.y - 98.0)
	var left := maxf(54.0, size.x * 0.5 - _content.size.x - 96.0) if _at_bottom else (size.x - _content.size.x) * 0.5
	_content.position = Vector2(roundf(left), size.y - _content.size.y - 132.0 if _at_bottom else top)


func _draw_steps() -> void:
	var stride := minf(34.0, (_steps.size.x - 12.0) / float(maxi(1, _total - 1)))
	for index in _total:
		var at := Vector2(6.0 + float(index) * stride, 10.0)
		var done := _complete or index < _passed_steps
		var active := not _complete and index == _step
		var color := Color("f0ddae") if done else (_accent if active else Color("617578"))
		if index < _total - 1:
			_steps.draw_line(at + Vector2(7.0, 0.0), at + Vector2(stride - 7.0, 0.0), Color(color, 0.3), 1.0, true)
		_steps.draw_circle(at, 3.5 if active else 2.5, color, done or active, -1.0 if done or active else 1.0, true)
		if index == _hovered_step:
			_steps.draw_arc(at, 7.0, 0, TAU, 24, Color(color, 0.6), 1.0, true)
