class_name TermTooltips
extends Control
## Keeps Label shaping and input propagation intact. Resolves only the text under
## the pointer, once per mouse update; no per-frame catalog or label rebuilding.

var build_provider: Callable
var scope_provider: Callable
var _labels: Dictionary[int, WeakRef] = {}
var _pending := false
var _pointer := Vector2.ZERO
var _source: Label
var _term := ""
var _delay := 0.0
var _bubble: PanelContainer
var _title: Label
var _body: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.085, 0.96)
	style.set_corner_radius_all(9)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 10
	_bubble.add_theme_stylebox_override("panel", style)
	add_child(_bubble)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 9)
	_bubble.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color("e4c990"))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size.x = 350
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_override("font", PageShell.SMALL_FONT)
	_body.add_theme_font_size_override("font_size", 18)
	_body.add_theme_color_override("font_color", Color("e8e4d8"))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)
	_bubble.hide()


func register(label: Label) -> void:
	if is_ancestor_of(label): return
	_labels[label.get_instance_id()] = weakref(label)
	label.tree_exiting.connect(func() -> void:
		_labels.erase(label.get_instance_id())
		if _source == label: dismiss())


func dismiss() -> void:
	_source = null
	_term = ""
	_delay = 0.0
	if is_instance_valid(_bubble): _bubble.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = event.position
		if not _pending:
			_pending = true
			_resolve.call_deferred()
	elif event is InputEventMouseButton or event is InputEventKey:
		dismiss()


func _resolve() -> void:
	_pending = false
	var scope: Node = scope_provider.call() if scope_provider.is_valid() else get_parent()
	if not is_instance_valid(scope):
		dismiss()
		return
	for reference: WeakRef in _labels.values():
		var label := reference.get_ref() as Label
		if label == null or not label.is_visible_in_tree() or not scope.is_ancestor_of(label): continue
		var point := label.get_global_transform_with_canvas().affine_inverse() * _pointer
		if not Rect2(Vector2.ZERO, label.size).has_point(point): continue
		var ancestor := label.get_parent()
		var blocked := false
		while ancestor != scope:
			if ancestor is BaseButton or (ancestor is Control and ancestor.clip_contents and not Rect2(Vector2.ZERO, ancestor.size).has_point(ancestor.get_global_transform_with_canvas().affine_inverse() * _pointer)):
				blocked = true
				break
			ancestor = ancestor.get_parent()
		if blocked: continue
		for found in GameTerms.matches(label.text):
			for index in range(found.get_start(), found.get_end()):
				if not label.get_character_bounds(index).has_point(point): continue
				var term := found.get_string()
				if _source == label and _term == term: return
				_source = label
				_term = term
				_delay = 0.25
				_bubble.hide()
				return
	dismiss()


func _process(delta: float) -> void:
	if _term.is_empty(): return
	if not is_instance_valid(_source) or not _source.is_visible_in_tree():
		dismiss()
		return
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0:
			_title.text = _term
			var build: CompiledBuild = build_provider.call() if build_provider.is_valid() else null
			_body.text = GameTerms.explanation(_term, build)
			_bubble.reset_size()
			_bubble.show()
	var local_pointer := get_global_transform_with_canvas().affine_inverse() * _pointer
	var point := local_pointer + Vector2(20, 26)
	point.x = clampf(point.x, 12, size.x - _bubble.size.x - 12)
	if point.y + _bubble.size.y > size.y - 12: point.y = local_pointer.y - _bubble.size.y - 18
	point.y = maxf(12, point.y)
	_bubble.position = point
