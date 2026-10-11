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
	_bubble = preload("res://ui/scenes/term_tooltip.tscn").instantiate() as PanelContainer
	add_child(_bubble)
	_title = _bubble.get_node("Reading/Title") as Label
	_body = _bubble.get_node("Reading/Body") as Label
	ProseDecoration.attach(_body, false)
	_bubble.resized.connect(_layout_surface)
	_bubble.hide()


func _layout_surface() -> void:
	var surface := _bubble.get_node("Backdrop/Depth") as ColorRect
	surface.size = _bubble.size
	(surface.material as ShaderMaterial).set_shader_parameter("canvas_size", surface.size)


func register(label: Label) -> void:
	if is_ancestor_of(label): return
	var ancestor := label.get_parent()
	while ancestor != null:
		if ancestor is BaseButton: return
		ancestor = ancestor.get_parent()
	ProseDecoration.attach(label)
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
