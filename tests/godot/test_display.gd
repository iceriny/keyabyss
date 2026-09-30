extends SceneTree
## Real output buffers, native settings callbacks and layout across desktop aspects.

var app: KeyabyssApp
var evidence: String
var failures := 0
var checks: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	evidence = "res://.temp/display/run-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.sound = false
	app.settings.ambience = false
	app.settings.reduce_motion = true
	app.settings.resolution = Vector2i(1280, 720)
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	_check(root.size == Vector2i(1280, 720), "window preset sets actual client pixels")
	app._settings_page("home")
	await _settle()
	var picker := app.settings_controls["resolution"] as OptionButton
	_check(picker.item_count == AppSettings.RESOLUTIONS.size() and picker.focus_mode == Control.FOCUS_NONE, "resolution choices are exposed without keyboard focus traversal")
	_select_resolution(Vector2i(1600, 900))
	await _settle()
	var restored := AppSettings.new(app.settings.path)
	restored.load_settings()
	_check(restored.resolution == Vector2i(1600, 900), "native option callback persists resolution")
	_check(root.content_scale_size == root.size, "window UI and world use actual output pixels")
	root.size = Vector2i(1366, 768)
	await _settle()
	app._save_settings()
	await _settle()
	_check(root.size == Vector2i(1366, 768), "unrelated settings do not undo a manually resized window")
	var windowed_size := root.size
	(app.settings_controls["fullscreen"] as CheckButton).button_pressed = true
	await _settle()
	_check(root.content_scale_size == Vector2i(1600, 900), "fullscreen keeps the selected game output")
	(app.settings_controls["fullscreen"] as CheckButton).button_pressed = false
	await _settle()
	_check(root.size == windowed_size, "fullscreen return restores the previous window size")
	(app.settings_controls["fullscreen"] as CheckButton).button_pressed = true
	await _settle()
	for output in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(1440, 900), Vector2i(1600, 1200), Vector2i(1280, 1024), Vector2i(3440, 1440), Vector2i(5120, 1440)]:
		app._settings_page("home")
		_select_resolution(output)
		var scale_picker := app.settings_controls["ui_scale"] as OptionButton
		scale_picker.select(3)
		scale_picker.item_selected.emit(3)
		await _settle()
		var tag := "%dx%d" % [output.x, output.y]
		_check(Vector2i(root.get_texture().get_size()) == output, tag + " root framebuffer matches the selected resolution")
		_check(app.archive.stage.viewport.size == output, tag + " archive HDR and text share the output resolution")
		_check(root.oversampling_override >= app.root.scale.x, tag + " font rasterization covers layout magnification")
		_check(app.page.panel.get_rect().end.y <= app.root.size.y and app.page.scroll.size.y >= 200, tag + " settings retain fixed actions and usable scrolling")
		if output in [Vector2i(1280, 720), Vector2i(3840, 2160)]:
			await _capture(tag + "-settings")
		app._home()
		app.archive.set_prepared(true)
		await _settle()
		_check(not app.archive.left_wing.get_rect().intersects(app.archive.right_wing.get_rect()), tag + " preparation wings remain separated")
		_check(app.archive.right_wing.size.x >= app.archive.difficulty_buttons[0].size.x * 2 + 16, tag + " difficulty columns fit their wing")
		await _click(app.archive.back_button)
		_check(not app.archive.prepared, tag + " mouse input follows scaled and letterboxed UI")
		app.archive.set_prepared(true)
		await _settle()
		if output in [Vector2i(1440, 900), Vector2i(5120, 1440)]:
			await _capture(tag + "-preparation")
		app._start_battle()
		await app.departure.completed
		await _settle()
		app._pause()
		await _settle()
		var page := app.battle
		var before := page.session.elapsed
		var position := page.session.player_position
		var word_id: StringName = page.enemy_words.keys()[0]
		var word_width := page.enemy_words[word_id].size.x
		_check(page.stage.viewport.size == output, tag + " battle HDR and HUD share output pixels")
		_check(page.hud.position.x == BattleStage.arena_origin(page.size).x, tag + " HUD remains beside the arena on wide screens")
		app._settings_page("pause")
		var smaller_ui := app.settings_controls["ui_scale"] as OptionButton
		smaller_ui.select(0)
		smaller_ui.item_selected.emit(0)
		await _settle()
		_check(page.session.elapsed == before and page.session.player_position == position, tag + " display changes while paused preserve combat state")
		_check(Vector2i(root.get_texture().get_size()) == output and page.stage.viewport.size == output, tag + " UI scale never changes framebuffer resolution")
		_check(is_equal_approx(page.enemy_words[word_id].size.x, word_width), tag + " paused resize preserves measured target word widths (%s -> %s)" % [word_width, page.enemy_words[word_id].size.x])
		app._settings_back()
		app.page.hide()
		await _settle()
		if output in [Vector2i(1280, 720), Vector2i(1600, 1200), Vector2i(3440, 1440), Vector2i(5120, 1440)]:
			await _capture(tag + "-battle")
		app._home()
		await _settle()
	app._settings_page("home")
	app._defaults()
	await _settle()
	_check(app.settings.resolution == Vector2i.ZERO and not app.settings.fullscreen, "defaults restore automatic windowed display")
	_check(root.content_scale_size == root.size, "automatic output follows the restored window")
	var report := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures": failures, "checks": checks}, "\t"))
	report.close()
	app.queue_free()
	await process_frame
	await process_frame
	print("Display checks: %d passed, %d failed | %s" % [checks.size() - failures, failures, evidence])
	quit(0 if failures == 0 else 1)


func _select_resolution(value: Vector2i) -> void:
	var picker := app.settings_controls["resolution"] as OptionButton
	var index := AppSettings.RESOLUTIONS.find(value)
	picker.select(index)
	picker.item_selected.emit(index)


func _settle() -> void:
	for frame in 8:
		await process_frame


func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_screen_transform() * control.get_global_transform() * (control.size * 0.5)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _check(condition: bool, label: String) -> void:
	checks.append(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1
		push_error(label)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			image.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	image.save_png(evidence.path_join(label + ".png"))
	print("Captured " + label)
