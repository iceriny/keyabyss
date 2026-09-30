extends SceneTree
## Native GUI events for control commands, key hints and smooth scrolling.

var app: KeyabyssApp
var evidence: String
var failures := 0
var checks: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	evidence = "res://.temp/ui-refinement/run-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.sound = false
	app.settings.ambience = false
	app.settings.reduce_motion = true
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	if "--m2-pages-only" in OS.get_cmdline_user_args():
		await _review_m2_pages()
		return

	var hint := KeyHint.create("Tab", "切换目标")
	root.add_child(hint)
	await _settle()
	_check(hint.key_text == "Tab" and (hint.get_node("KeyFrame/Key") as Label).text == "Tab" and (hint.get_node("Description") as Label).text == "切换目标", "key hint scene binds its editable text")
	hint.queue_free()

	await _move_to(app.archive.prepare_button)
	var prepare := app.archive.prepare_button
	print("Prepare layout: alignment=%s, size=%s, margin=%s, badge=%s" % [prepare._caption_alignment, prepare.size, prepare.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT), prepare._command_badge.position])
	_check(is_equal_approx(float(prepare._light_material.get_shader_parameter("text_center_x")) - OpenButton.LIGHT_PADDING, prepare.size.x * 0.5), "primary action caption and glow share the center")
	await _capture("home-hover")
	app.archive.set_prepared(true)
	await _settle()
	_check(app.route == "prepare" and app.archive.seed_edit.editable, "preparation seed is editable")
	await _capture("preparation")
	await _click(app.archive.seed_edit)
	await _type("7")
	_check(app.archive.seed_edit.text == "7", "pointer click gives seed editing ownership")
	await _key(KEY_BACKSPACE)
	await _key(KEY_ESCAPE)
	await _type("seed")
	_check(root.gui_get_focus_owner() == app.archive.seed_edit, "seed word focuses the real edit field")
	await _type("hard")
	_check(app.archive.seed_edit.text == "hard" and app.settings.difficulty == "normal" and app.router.buffer.is_empty(), "typing in seed does not trigger a command")
	await _key(KEY_ESCAPE)
	_check(root.gui_get_focus_owner() != app.archive.seed_edit, "Escape leaves seed editing")
	await _type("hard")
	_check(app.settings.difficulty == "hard" and app.archive.seed_edit.text == "hard", "commands resume after seed editing")

	await _type("settings")
	await _settle()
	_check(app.route == "settings", "settings word opens settings")
	await _type("translation")
	_check(not app.settings.show_meaning and not (app.settings_controls["show_meaning"] as CheckButton).button_pressed, "translation word operates the overhead meaning option")
	var restored := AppSettings.new(evidence.path_join("settings.cfg"))
	restored.load_settings()
	_check(not restored.show_meaning, "overhead meaning choice persists in the existing settings key")
	await _type("translation")
	var sound_toggle := app.settings_controls["sound"] as CheckButton
	var music_toggle := app.settings_controls["ambience"] as CheckButton
	await _type("sound")
	_check(sound_toggle.button_pressed and app.settings.sound, "sound word toggles the visible control")
	await _type("music")
	_check(music_toggle.button_pressed and app.settings.ambience, "music word toggles the visible control")
	var volume := app.settings_controls["volume"] as HSlider
	var before := volume.value
	await _type("volume")
	_check(root.gui_get_focus_owner() == volume, "volume word focuses its slider")
	await _key(KEY_RIGHT)
	_check(volume.value > before, "arrow adjusts the focused volume slider")
	await _key(KEY_ESCAPE)
	_check(root.gui_get_focus_owner() != volume and app.route == "settings", "Escape leaves slider editing without leaving settings")
	await _capture("settings")
	var crystal := music_toggle.get_node("CrystalInlay") as CrystalInlay
	(app.settings_controls["reduce_motion"] as CheckButton).button_pressed = false
	await _move_to(music_toggle)
	await create_timer(0.35).timeout
	_check(crystal.activity > 0.8 and float(crystal.filaments.ribbon.get_shader_parameter("trigger_time")) >= 0.0, "crystal responds and starts path flow on real pointer entry (activity=%s)" % crystal.activity)
	await _capture("crystal-hover")
	await _type("music")
	_check(not music_toggle.button_pressed and crystal.pulse > 0.0, "word toggle drives the same crystal response as pointer input (pulse=%s)" % crystal.pulse)
	await _capture("crystal-toggle")
	await create_timer(1.0).timeout
	await _capture("crystal-flow")
	if "--record-gold" in OS.get_cmdline_user_args():
		await _capture_gold_flow(music_toggle)
	(app.settings_controls["reduce_motion"] as CheckButton).button_pressed = true
	await _settle()
	_check(is_zero_approx(float(crystal.glass.get_shader_parameter("clock"))), "reduced motion freezes crystal flow while retaining material")
	_check(not bool(crystal.filaments.ribbon.get_shader_parameter("motion_enabled")), "reduced motion stops the arc-length travelling light")
	await _type("effects")
	var quality := app.settings_controls["quality"] as OptionButton
	_check(quality.get_popup().visible and app.route == "settings", "effects word opens the quality options")
	await _capture("settings-options")
	await _key(KEY_ESCAPE)

	app.queue_free()
	await _settle()
	var motif := GoldFilaments.new()
	root.add_child(motif)
	motif.configure(Vector2(180, 64), hash("music"))
	var original := motif.vertices.duplicate()
	motif.configure(Vector2(180, 64), hash("sound"))
	_check(motif.vertices != original, "same-size controls receive distinct word-seeded curves")
	motif.configure(Vector2(180, 64), hash("music"))
	_check(motif.vertices == original, "reopening the same control preserves its curve geometry")
	motif.queue_free()
	await _test_scroll()
	var report := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "headless": DisplayServer.get_name() == "headless"}, "\t"))
	report.close()
	print("UI refinement checks: %d passed, %d failed | %s" % [checks.size() - failures, failures, evidence])
	quit(0 if failures == 0 else 1)


func _review_m2_pages() -> void:
	app._settings_page("home")
	await _settle()
	await _type("resolution")
	var menu := (app.settings_controls["resolution"] as OptionButton).get_popup()
	_check(menu.visible and menu.size.y <= 420, "long resolution menu stays bounded (visible=%s size=%s min=%s max=%s scale=%s)" % [menu.visible, menu.size, menu.min_size, menu.max_size, menu.content_scale_factor])
	await _capture("resolution-options")
	await _key(KEY_ESCAPE)
	if "--popup-only" in OS.get_cmdline_user_args():
		print("Popup review: %d failed | %s" % [failures, evidence])
		app.queue_free()
		await process_frame
		quit(0 if failures == 0 else 1)
		return
	app._home()
	app.settings.reduce_motion = false
	app._start_battle()
	await create_timer(0.65).timeout
	_check((app.departure.get_node("Book") as Label).modulate.a == 0.0, "departure names wait until the archive is covered")
	await _capture("departure-cover")
	await app.departure.completed
	app.battle.session.set_physics_process(false)
	app._pause()
	await create_timer(0.6).timeout
	await _capture("battle-pause")
	app._resume()
	# Presentation fixture, not proof of a played victory; the room test owns that.
	app.battle.session.result = 1
	app._battle_finished(true)
	await create_timer(0.55).timeout
	await _capture("victory-arrival")
	await create_timer(2.0).timeout
	await _capture("victory-settled")
	app.battle.session.result = -1
	app._battle_finished(false)
	await create_timer(0.7).timeout
	await _capture("defeat-arrival")
	app._home()
	app._start_battle()
	await process_frame
	app._home()
	await create_timer(2.5).timeout
	_check(app.battle == null and app.departure == null and app.route == "home", "leaving the ritual cancels its pending battle handover")
	print("M2 pages: %d checks, %d failed | %s" % [checks.size(), failures, evidence])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _test_scroll() -> void:
	var scroll := SmoothScroll.new()
	scroll.position = Vector2(40, 40)
	scroll.custom_minimum_size = Vector2(260, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(240, 1000)
	scroll.add_child(content)
	await _settle()
	_check(scroll.is_in_group("smooth_scroll_controls"), "smooth scroll joins its dedicated motion group")
	await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN)
	await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN)
	_check(scroll._target >= scroll.wheel_step * 2.0 and scroll.scroll_vertical < scroll._target, "repeated wheel events accumulate a smooth target")
	await create_timer(0.8).timeout
	_check(not scroll._animating and scroll.scroll_vertical == roundi(scroll._target), "smooth scroll reaches and stops at the exact target")
	await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN)
	scroll.get_v_scroll_bar().value = 35.0
	_check(not scroll._animating and is_equal_approx(scroll._current, 35.0), "scrollbar drag replaces an active wheel target")
	scroll.set_motion_reduced(true)
	await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN)
	_check(not scroll._animating and scroll.scroll_vertical == roundi(scroll._target), "reduced motion moves directly to the next wheel target")
	scroll.queue_free()


func _wheel(control: Control, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_screen_transform() * control.get_global_transform() * Vector2(30, 30)
	event.button_index = button
	event.factor = 1.0
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame


func _move_to(control: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_screen_transform() * control.get_global_transform() * (control.size * 0.5)
	Input.parse_input_event(event)
	await _settle()


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


func _type(value: String) -> void:
	for character in value:
		await _key(character.to_upper().unicode_at(0) as Key, character.unicode_at(0))


func _key(code: Key, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _settle() -> void:
	for frame in 3:
		await process_frame


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


func _capture_gold_flow(control: Control) -> void:
	await _move_to(app.page.heading)
	await _move_to(control)
	var rect := control.get_global_rect().grow(24.0)
	var screen := root.get_screen_transform()
	var crop := Rect2i(screen * rect.position, rect.size * screen.get_scale())
	for frame in 36:
		await RenderingServer.frame_post_draw
		var source := root.get_texture().get_image().get_region(crop)
		var output := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		for y in source.get_height():
			for x in source.get_width():
				output.set_pixel(x,y,source.get_pixel(x,y).linear_to_srgb())
		output.save_png(evidence.path_join("gold-flow-%02d.png" % frame))
		if frame % 6 == 0:
			await _capture("crystal-motion-%02d" % frame)
		await create_timer(0.12).timeout
