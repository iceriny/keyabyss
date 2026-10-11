class_name TutorialOverlay
extends Control
## Read-only guidance over BattlePage. Combat input remains with InputRouter.

signal exit_requested
signal retry_requested
signal next_requested

var exit_button: OpenButton
var retry_button: OpenButton
var next_button: OpenButton
var reduced_motion := false
var _accent := Color("8bdeff")
var _step := -1
var _total := 1
var _complete := false
var _feedback: Tween
var _content: Control
var _title: Label
var _instruction: Label
var _progress: Label
var _counter: Label
var _steps: Control


static func create_overlay(book: BookPresentation, motion_reduced: bool) -> TutorialOverlay:
	var overlay := load("res://ui/scenes/tutorial_overlay.tscn").instantiate() as TutorialOverlay
	overlay.reduced_motion = motion_reduced
	overlay._accent = book.color
	overlay._bind_nodes()
	(overlay.get_node("Content/Book") as Label).text = book.title + " · 习术"
	(overlay.get_node("Content/Seal") as TextureRect).texture = book.seal
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
	for control: OpenButton in [exit_button, retry_button, next_button]:
		control.set_motion_reduced(reduced_motion)
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	next_button.pressed.connect(func() -> void: next_requested.emit())
	_steps.draw.connect(_draw_steps)
	($Content/GoldBranch as CrystalInlay).set_motion_reduced(reduced_motion)


func _ready() -> void:
	resized.connect(_layout)
	_instruction.minimum_size_changed.connect(_layout)
	_progress.minimum_size_changed.connect(_layout)
	_layout()


## index is zero-based; complete marks the whole lesson as finished.
func show_step(index: int, total: int, title: String, instruction: String, progress: String, complete: bool = false) -> void:
	assert(total > 0 and index >= 0 and index < total, "Tutorial step must be inside the lesson.")
	var changed := index != _step or complete != _complete
	_step = index
	_total = total
	_complete = complete
	_title.text = title
	_instruction.text = instruction
	_progress.text = progress
	_layout()
	_counter.text = "练习完成" if complete else "第 %02d / %02d 步" % [index + 1, total]
	_counter.add_theme_color_override("font_color", Color("f0ddae") if complete else _accent)
	_progress.add_theme_color_override("font_color", Color("f0ddae") if complete else Color("e8e4d8"))
	exit_button.set_caption("返回教学" if complete else "退出练习")
	next_button.set_caption("完成练习" if index == total - 1 else "下一步")
	next_button.visible = not complete
	_steps.queue_redraw()
	if changed and is_inside_tree():
		if _feedback != null:
			_feedback.kill()
		_title.modulate.a = 1.0 if reduced_motion else 0.5
		if not reduced_motion:
			_feedback = create_tween()
			_feedback.tween_property(_title, "modulate:a", 1.0, 0.24)


func set_goal_ready(achieved: bool) -> void:
	next_button.disabled = not achieved


## BattlePage-local bounds, available to the host's word placement algorithm.
func get_reserved_rect() -> Rect2:
	return Rect2(position + _content.position, _content.size * _content.scale)


func _layout() -> void:
	# GameDisplay already owns UI scaling; keep the same coordinate space as HUD.
	_content.position = Vector2(54.0, 204.0)
	_progress.position.y = maxf(351.0, _instruction.position.y + _instruction.get_minimum_size().y + 12.0)
	var actions := $Content/Actions as HBoxContainer
	actions.position.y = maxf(399.0, _progress.position.y + maxf(_progress.size.y, _progress.get_minimum_size().y) + 11.0)
	_content.size.y = actions.position.y + actions.size.y
	($Content/Veil as TextureRect).size.y = _content.size.y + 43.0


func _draw_steps() -> void:
	var stride := minf(34.0, (_steps.size.x - 12.0) / float(maxi(1, _total - 1)))
	for index in _total:
		var at := Vector2(6.0 + float(index) * stride, 10.0)
		var done := _complete or index < _step
		var active := not _complete and index == _step
		var color := Color("f0ddae") if done else (_accent if active else Color("617578"))
		if index < _total - 1:
			_steps.draw_line(at + Vector2(7.0, 0.0), at + Vector2(stride - 7.0, 0.0), Color(color, 0.3), 1.0, true)
		_steps.draw_circle(at, 3.5 if active else 2.5, color, done or active, -1.0 if done or active else 1.0, true)
