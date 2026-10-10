extends SceneTree

var failures: int = 0
var commands: Array[String] = []
var actions: Array[StringName] = []
var completions: Array[Dictionary] = []
var backs: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var router := InputRouter.new()
	var typing := TypingSession.new()
	router.typing = typing
	root.add_child(router)
	router.command_requested.connect(func(command: String) -> void: commands.append(command))
	router.action_requested.connect(func(action: StringName) -> void: actions.append(action))
	router.back_requested.connect(func() -> void: backs += 1)
	typing.completed.connect(func(id: StringName, count: int, assisted: bool, attempt_id: String) -> void: completions.append({"id": id, "count": count, "assisted": assisted, "attempt_id": attempt_id}))

	router.configure(InputRouter.Context.MENU, PackedStringArray(["start"]))
	await _key(KEY_S, "s")
	await _key(KEY_T, "t")
	await _key(KEY_A, "a")
	await _key(KEY_R, "r")
	await _key(KEY_T, "t")
	_check(commands == ["start"] and router.buffer.is_empty(), "menu command receives real keys once")
	_check(typing.drain_receipts().is_empty(), "menu does not write typing receipts")

	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == field, "text control gained focus")
	await _key(KEY_S, "s")
	_check(router.buffer.is_empty() and commands.size() == 1, "focused text owns menu key")
	await _key(KEY_ESCAPE)
	_check(root.gui_get_focus_owner() != field and backs == 0, "Escape releases text focus only")

	router.configure(InputRouter.Context.TYPING)
	var targets: Dictionary[StringName, String] = {&"first": "a b", &"other": "z"}
	typing.set_targets(targets)
	field.grab_focus()
	await process_frame
	await _key(KEY_A, "a")
	_check(typing.progress == 0 and typing.target_id == &"", "focused text owns typing key")
	field.release_focus()
	await _key(KEY_A, "a")
	_check(typing.target_id == &"first" and typing.progress == 1 and typing.display_boundary() == 2, "typing target and visible space")
	await _key(KEY_B, "b", true, false, true)
	_check(typing.progress == 1, "echo cannot type twice")
	await _key(KEY_X, "x")
	_check(typing.progress == 1 and typing.mistakes == 1, "wrong key preserves progress")
	await _key(KEY_SPACE, " ")
	_check(actions.has(&"parry") and typing.progress == 1, "space is an action, not a word character")
	await _key(KEY_B, "b")
	_check(completions.size() == 1 and completions[0]["count"] == 2 and not completions[0]["assisted"], "manual completion")
	var receipts := typing.drain_receipts()
	_check(receipts.size() == 2 and receipts[0].id != receipts[1].id and receipts[1].completes_word, "accepted physical keys yield unique receipts")
	_check(typing.drain_receipts().is_empty(), "receipts drain only once")

	var next_targets: Dictionary[StringName, String] = {&"cat": "cat", &"dog": "dog"}
	typing.set_targets(next_targets)
	await _key(KEY_C, "c")
	await _key(KEY_BACKSPACE)
	_check(typing.target_id == &"" and typing.progress == 0, "Backspace abandons word")
	_check(typing.drain_receipts().size() == 1 and typing.drain_receipts().is_empty(), "cancellation cannot replay a receipt")
	await _key(KEY_SHIFT)
	await _key(KEY_SHIFT, "", false)
	_check(actions.count(&"ultimate") == 1, "solo Shift requests ultimate")
	await _key(KEY_SHIFT)
	await _key(KEY_TAB, "", true, true)
	await _key(KEY_SHIFT, "", false)
	_check(typing.target_id == &"dog" and actions.count(&"ultimate") == 1, "initial Shift+Tab selects the last target")
	typing.select_target(&"cat")
	await _key(KEY_SHIFT)
	await _key(KEY_TAB, "", true, true)
	await _key(KEY_SHIFT, "", false)
	_check(typing.target_id == &"dog" and actions.count(&"ultimate") == 1, "Shift+Tab cycles without ultimate")

	var shared_targets: Dictionary[StringName, String] = {&"cat": "cat", &"car": "car", &"dog": "dog"}
	typing.set_targets(shared_targets)
	await _key(KEY_C, "c")
	_check(typing.target_id == &"cat" and typing.progress == 1, "first character locks first shared-prefix target")
	await _key(KEY_TAB)
	_check(typing.target_id == &"car" and typing.progress == 1, "Tab cycles within matching prefix without resetting progress")
	await _key(KEY_TAB)
	_check(typing.target_id == &"cat" and typing.progress == 1, "Tab skips nonmatching targets")
	await _key(KEY_SHIFT)
	await _key(KEY_TAB, "", true, true)
	await _key(KEY_SHIFT, "", false)
	_check(typing.target_id == &"car" and typing.progress == 1 and actions.count(&"ultimate") == 1, "Shift+Tab reverses matching cycle without ultimate")
	await _key(KEY_A, "a")
	_check(typing.target_id == &"car" and typing.progress == 2, "shared prefix continues once")
	await _key(KEY_SHIFT)
	await _key(KEY_TAB, "", true, true)
	await _key(KEY_SHIFT, "", false)
	_check(typing.target_id == &"cat" and typing.progress == 2, "reverse cycle preserves two-character prefix")
	await _key(KEY_R, "r")
	_check(completions.size() == 2 and completions[1]["id"] == &"car" and completions[1]["count"] == 3 and typing.mistakes == 1, "next character retargets instead of causing a mistake")
	var shared_receipts := typing.drain_receipts()
	_check(shared_receipts.size() == 3 and shared_receipts[0].target_id == &"cat" and shared_receipts[1].target_id == &"car" and shared_receipts[2].target_id == &"car" and shared_receipts[0].position == 1 and shared_receipts[1].position == 2 and shared_receipts[2].position == 3 and shared_receipts[0].id != shared_receipts[1].id and shared_receipts[1].id != shared_receipts[2].id and shared_receipts[0].attempt_id == shared_receipts[2].attempt_id and completions[1]["attempt_id"] == shared_receipts[2].attempt_id and shared_receipts[2].completes_word, "retargeting preserves one paid attempt across unique physical receipts")
	_check(typing.drain_receipts().is_empty(), "retargeted receipts drain only once")
	await _key(KEY_C, "c")
	typing.select_target(&"cat")
	_check(typing.target_id == &"cat" and typing.progress == 0, "explicit selection of current target resets typed prefix")
	await _key(KEY_C, "c")
	typing.select_target(&"dog")
	_check(typing.target_id == &"dog" and typing.progress == 0, "explicit target selection resets typed prefix")
	await _key(KEY_BACKSPACE)
	var selection_receipts := typing.drain_receipts()
	_check(typing.target_id == &"" and typing.progress == 0 and selection_receipts.size() == 2 and selection_receipts[0].id != selection_receipts[1].id, "abandon after explicit selection resets target without duplicating input")
	await _key(KEY_ESCAPE)
	_check(backs == 1, "Escape routes back outside text focus")

	var assisted_targets: Dictionary[StringName, String] = {&"assist": "road"}
	typing.set_targets(assisted_targets)
	await _key(KEY_R, "r")
	typing.assisted_authorizer = func() -> bool: return true
	typing.complete_assisted()
	_check(completions.size() == 3 and completions[2]["assisted"] and completions[2]["count"] == 1, "assisted completion reports manual count")
	_check(typing.drain_receipts().size() == 1 and typing.drain_receipts().is_empty(), "assisted completion mints no extra receipt")
	router.configure(InputRouter.Context.MODAL)
	await _key(KEY_S, "s")
	_check(router.buffer.is_empty() and typing.drain_receipts().is_empty(), "modal owns key independently")

	_test_settings()
	root.remove_child(field)
	field.queue_free()
	root.remove_child(router)
	router.queue_free()
	if failures == 0:
		print("Input and settings tests passed")
	quit(0 if failures == 0 else 1)


func _key(code: Key, character: String = "", pressed: bool = true, shifted: bool = false, repeated: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = character.unicode_at(0) if not character.is_empty() else 0
	event.pressed = pressed
	event.shift_pressed = shifted
	event.echo = repeated
	Input.parse_input_event(event)
	await process_frame


func _test_settings() -> void:
	var folder := ProjectSettings.globalize_path("res://.temp/godot-m1/input-settings")
	var create_error := DirAccess.make_dir_recursive_absolute(folder)
	_check(create_error == OK, "isolated test directory")
	if create_error != OK:
		return
	var path := folder.path_join("settings.cfg")
	var settings := AppSettings.new(path)
	_check(not settings.show_fps and not settings.first_setup_complete and settings.show_meaning, "fresh defaults open calibration, retain Chinese and hide FPS")
	settings.ui_scale = 1.1
	settings.resolution = Vector2i(2560, 1440)
	settings.volume = 0.3
	settings.fluid_quality = 3
	settings.show_fps = true
	settings.first_setup_complete = true
	settings.vocabulary_id = "cpp"
	_check(settings.save_settings(), "first settings save")
	settings.ui_scale = 1.2
	_check(settings.save_settings() and FileAccess.file_exists(path + ".bak"), "second save creates backup")
	var restored := AppSettings.new(path)
	restored.load_settings()
	_check(restored.show_fps and restored.first_setup_complete, "FPS and first-visit completion survive restart")
	_check(restored.fluid_quality == 3, "independent fluid quality survives a settings round trip")
	_check(restored.resolution == Vector2i(2560, 1440), "game resolution survives a settings round trip")
	_check(is_equal_approx(restored.ui_scale, 1.2) and is_equal_approx(restored.volume, 0.3) and restored.vocabulary_id == "cpp", "settings round trip")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	_check(corrupt != null, "open isolated settings for corruption")
	if corrupt != null:
		corrupt.store_string("not a config file")
		corrupt.close()
	var recovered := AppSettings.new(path)
	recovered.load_settings()
	_check(is_equal_approx(recovered.ui_scale, 1.1) and recovered.last_error.contains("备份"), "bad settings recover from backup")
	_check(FileAccess.get_file_as_string(path) == "not a config file", "bad original remains for inspection")
	recovered.ui_scale = 1.2
	_check(recovered.save_settings(), "save after backup recovery")
	var backup := ConfigFile.new()
	_check(backup.load(path + ".bak") == OK and is_equal_approx(float(backup.get_value("display", "ui_scale", 0.0)), 1.1), "recovery save preserves valid backup")
	corrupt = FileAccess.open(path, FileAccess.WRITE)
	_check(corrupt != null, "open recovered settings for second corruption")
	if corrupt != null:
		corrupt.store_string("corrupt again")
		corrupt.close()
	var recovered_again := AppSettings.new(path)
	recovered_again.load_settings()
	_check(is_equal_approx(recovered_again.ui_scale, 1.1) and recovered_again.last_error.contains("备份"), "backup survives save and second corruption")
	var blocked := folder.path_join("blocked")
	DirAccess.make_dir_absolute(blocked)
	var failed := AppSettings.new(blocked)
	_check(not failed.save_settings() and not failed.last_error.is_empty(), "save failure is reported")


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Input/settings test failed: " + label)
