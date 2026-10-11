class_name MenuNavigation
extends RefCounted
## Menu selection follows visible geometry without acquiring native GUI focus.

signal selection_changed(control: Control)

var primary_word: String = ""
var selected: Control
var _targets: Array[Dictionary] = []


func reset(primary: String = "") -> void:
	clear_selection()
	for target in _targets:
		var control := (target["control"] as WeakRef).get_ref() as Control
		if is_instance_valid(control):
			control.mouse_entered.disconnect(target["hover"])
	_targets.clear()
	primary_word = primary


func register(control: Control, word: String) -> void:
	if not is_instance_valid(control) or control.is_queued_for_deletion():
		return
	for target in _targets:
		if (target["control"] as WeakRef).get_ref() == control:
			target["word"] = word
			return
	var hover := _on_mouse_entered.bind(control)
	control.mouse_entered.connect(hover)
	_targets.append({"control": weakref(control), "word": word, "hover": hover})


func select_word(word: String) -> void:
	var control := _find_word(word)
	if control != null:
		_set_selection(control)


func clear_selection() -> void:
	_set_selection(null)


func selected_word() -> String:
	if not is_instance_valid(selected) or not _available(selected):
		return ""
	for target in _targets:
		if (target["control"] as WeakRef).get_ref() == selected:
			return target["word"]
	return ""


func handle(action: StringName) -> String:
	if action == &"menu_confirm":
		var word := selected_word()
		if not word.is_empty():
			return word
		return primary_word if _find_word(primary_word) != null else ""
	var direction: Vector2
	match action:
		&"menu_previous": direction = Vector2.LEFT
		&"menu_next": direction = Vector2.RIGHT
		&"menu_up": direction = Vector2.UP
		&"menu_down": direction = Vector2.DOWN
		_: return ""
	if selected_word().is_empty():
		var start := _find_word(primary_word)
		if start == null:
			for target in _targets:
				var control := (target["control"] as WeakRef).get_ref() as Control
				if _available(control):
					start = control
					break
		if start == null:
			clear_selection()
			return ""
		_set_selection(start)
	var origin := selected.get_global_rect()
	var nearest: Control
	var nearest_score := INF
	var nearest_in_lane := false
	for target in _targets:
		var control := (target["control"] as WeakRef).get_ref() as Control
		if control == selected or not _available(control):
			continue
		var bounds := control.get_global_rect()
		var delta := bounds.get_center() - origin.get_center()
		var along := delta.dot(direction)
		if along <= 0.0:
			continue
		var across := absf(delta.cross(direction))
		var in_lane := origin.position.y < bounds.end.y and bounds.position.y < origin.end.y if direction.x != 0.0 else origin.position.x < bounds.end.x and bounds.position.x < origin.end.x
		var score := along + across * 2.0
		if (in_lane and not nearest_in_lane) or (in_lane == nearest_in_lane and score < nearest_score):
			nearest = control
			nearest_score = score
			nearest_in_lane = in_lane
	if nearest != null:
		_set_selection(nearest)
	return ""


func _find_word(word: String) -> Control:
	if word.is_empty():
		return null
	for target in _targets:
		var control := (target["control"] as WeakRef).get_ref() as Control
		if target["word"] == word and _available(control):
			return control
	return null


func _available(control: Control) -> bool:
	return is_instance_valid(control) and not control.is_queued_for_deletion() and control.is_visible_in_tree() and not (control is BaseButton and control.disabled)


func _set_selection(control: Control) -> void:
	if is_instance_valid(selected) and selected == control:
		return
	if is_instance_valid(selected) and selected.has_method("set_keyboard_selected"):
		selected.call("set_keyboard_selected", false)
	selected = control
	if selected != null:
		if selected.has_method("set_keyboard_selected"):
			selected.call("set_keyboard_selected", true)
		var ancestor := selected.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(selected)
			ancestor = ancestor.get_parent()
	selection_changed.emit(selected)


func _on_mouse_entered(control: Control) -> void:
	if selected_word().is_empty():
		return
	for target in _targets:
		if (target["control"] as WeakRef).get_ref() == control and _available(control):
			_set_selection(control)
			return
