class_name InputRouter
extends Node
## Exactly one owner receives each event. Text controls retain native editing.

signal command_requested(command: String)
signal command_progress(value: String)
signal command_character
signal command_rejected
signal back_requested
signal action_requested(action: StringName)
signal focus_lost

enum Context { MENU, TYPING, MODAL }
var context: Context = Context.MENU
var typing: TypingSession
var commands: PackedStringArray = []
var buffer: String = ""
var _shift_down: bool = false
var _shift_solo: bool = false


func configure(next_context: Context, next_commands: PackedStringArray = []) -> void:
	context = next_context
	commands = next_commands
	if context == Context.MENU and not "imsuperman" in commands:
		commands = commands.duplicate()
		commands.append("imsuperman")
	clear_held()
	buffer = ""
	command_progress.emit(buffer)


func clear_held() -> void:
	_shift_down = false
	_shift_solo = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_held()
		buffer = ""
		command_progress.emit(buffer)
		focus_lost.emit()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.echo:
		if context == Context.TYPING:
			get_viewport().set_input_as_handled()
		return
	if key.pressed and key.keycode == KEY_F11:
		action_requested.emit(&"fullscreen")
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	# Sliders become keyboard-editable only after their explicit word command.
	if focus is Slider:
		if key.pressed and key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			focus.release_focus()
			get_viewport().set_input_as_handled()
			return
		if key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END]:
			return
		if key.pressed:
			focus.release_focus()
	if key.pressed and key.keycode == KEY_TAB and context != Context.TYPING:
		get_viewport().set_input_as_handled()
		return
	if focus is LineEdit or focus is TextEdit:
		clear_held()
		if key.pressed and key.is_action_pressed("cancel_or_pause"):
			focus.release_focus()
			get_viewport().set_input_as_handled()
		return
	if context == Context.MODAL:
		clear_held()
		return
	if key.keycode == KEY_SHIFT:
		if key.pressed:
			_shift_down = true
			_shift_solo = not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed
		else:
			if _shift_down and _shift_solo and context == Context.TYPING:
				action_requested.emit(&"ultimate")
			clear_held()
		return
	if key.pressed and _shift_down:
		_shift_solo = false
	if not key.pressed:
		return
	if key.is_action_pressed("cancel_or_pause"):
		get_viewport().set_input_as_handled()
		if context == Context.MENU and not buffer.is_empty():
			buffer = ""
			command_progress.emit(buffer)
		else:
			back_requested.emit()
		return
	if context == Context.TYPING:
		# Explicit lesson buttons own these shortcuts through native GUI routing.
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_F1, KEY_F3]:
			return
		get_viewport().set_input_as_handled()
		if key.keycode == KEY_CTRL and not key.alt_pressed and not key.meta_pressed:
			action_requested.emit(&"assist")
		elif key.is_action_pressed("cycle_target"):
			var previous := typing.target_id
			typing.cycle_target(key.shift_pressed)
			if typing.target_id != previous:
				typing.feedback_requested.emit(&"target")
		elif key.is_action_pressed("abandon_word"):
			var had_target := typing.target_id != &""
			typing.cancel()
			if had_target:
				typing.feedback_requested.emit(&"cancel")
		elif key.is_action_pressed("parry"):
			action_requested.emit(&"parry")
		elif key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ALT]:
			match key.keycode:
				KEY_LEFT: action_requested.emit(&"dodge_left")
				KEY_RIGHT: action_requested.emit(&"dodge_right")
				KEY_UP: action_requested.emit(&"dodge_up")
				KEY_DOWN: action_requested.emit(&"dodge_down")
				KEY_ALT: action_requested.emit(&"dodge_auto")
		elif key.unicode > 0 and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed:
			typing.feed(String.chr(key.unicode))
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if buffer.is_empty():
			match key.keycode:
				KEY_LEFT: action_requested.emit(&"menu_previous")
				KEY_RIGHT: action_requested.emit(&"menu_next")
				KEY_UP: action_requested.emit(&"menu_up")
				KEY_DOWN: action_requested.emit(&"menu_down")
				_: action_requested.emit(&"menu_confirm")
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_BACKSPACE:
		buffer = buffer.left(maxi(0, buffer.length() - 1))
		command_progress.emit(buffer)
		get_viewport().set_input_as_handled()
	else:
		var character := String.chr(key.unicode).to_lower() if key.unicode > 0 else ""
		if character.is_empty():
			var physical := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if physical >= KEY_0 and physical <= KEY_9:
				character = str(physical - KEY_0)
			else:
				var keypad := [KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]
				var digit := keypad.find(physical)
				if digit >= 0:
					character = str(digit)
		if character.is_empty():
			return
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-":
			return
		get_viewport().set_input_as_handled()
		var next := buffer + character
		for command in commands:
			if command.begins_with(next):
				buffer = next
				command_character.emit()
				command_progress.emit(buffer)
				if command == buffer:
					buffer = ""
					command_progress.emit(buffer)
					command_requested.emit(command)
				return
		command_rejected.emit()
