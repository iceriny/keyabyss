extends SceneTree
## Native window integration: events traverse the real GUI and InputRouter.
## Run without --headless for screenshots, or headless for interaction assertions.

var app: KeyabyssApp
var failures: int = 0
var evidence: String
var checks: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	evidence = "res://.temp/godot-m1/application/run-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	_check(app.route == "home" and app.archive != null and not app.archive.prepared, "archive home loads after native fonts")
	await create_timer(1.3).timeout
	await _capture("01-home")
	await _click(app.archive.cards[3])
	_check(app.archive.selected == 3, "left book is clickable without cycling through the right books")
	await create_timer(.25).timeout
	await _capture("01-book-refraction")
	await create_timer(1.3).timeout
	await _click(app.archive.cards[0])
	_check(app.archive.selected == 0, "right book is clickable after reversing the orbit")
	for index in [1,2,3,0,1,2]:
		app.archive.select_book(index)
		await create_timer(.03).timeout
	await create_timer(.09).timeout
	var book_voices := 0
	for voice: AudioStreamPlayer in app.sound._voices:
		if voice.playing and app.sound._voice_cues.get(voice) == "ui.book":
			book_voices += 1
	_check(book_voices == 1, "rapid book changes retire earlier audio instead of accumulating voices")
	for book_id: String in ["frost", "storm", "spirit", "flame"]:
		await _type(book_id)
		_check(app.route == "home" and str(ArchiveHome.BOOKS[app.archive.selected].id) == book_id and app.settings.book_id == book_id, "book command selects " + book_id)
	await _type("1")
	_check(app.archive.selected == 0 and app.settings.book_id == "frost", "number command selects first book")
	await _key(KEY_RIGHT)
	_check(app.archive.selected == 1, "right key selects the next book without GUI focus")
	await _key(KEY_LEFT)
	_check(app.archive.selected == 0 and root.gui_get_focus_owner() == null, "left key selects the previous book without GUI focus")
	await create_timer(1.3).timeout
	_check(is_equal_approx(app.archive.orbit,app.archive.orbit_target), "interrupted book selections settle on the final selected book")
	await _type("s")
	_check(app.archive.cards[1].get_meta("command_match",false), "menu prefix lights the matching book without executing it")
	await _key(KEY_ESCAPE)
	_check(app.route == "home" and app.router.buffer.is_empty(), "Escape clears an unfinished menu command before navigating")
	await _click(app.archive.prepare_button)
	_check(app.archive.left_wing.position.x > app.archive.size.x*.05 and app.archive.right_wing.position.x < app.archive.size.x*.95-app.archive.right_wing.size.x, "preparation wings unfold outward from the center")
	await create_timer(.7).timeout
	_check(app.route == "prepare" and app.archive.prepared and not app.archive.prepare_button.disabled, "preparation remains actionable with a direct battle entry")
	await _capture("01-prepare")
	await _click(app.archive.difficulty_buttons[2])
	app.archive.seed_edit.text = "arc123"
	app.archive.seed_edit.text_changed.emit("arc123")
	var prepared_settings := AppSettings.new(app.settings.path)
	prepared_settings.load_settings()
	_check(prepared_settings.difficulty == "hard" and prepared_settings.run_seed == "arc123", "difficulty and seed persist from preparation")
	await _type("words")
	_check(app.route == "words" and app.archive_return == "prepare", "vocabulary opens above preparation")
	await _key(KEY_ESCAPE)
	_check(app.route == "prepare" and app.archive.prepared, "closing vocabulary returns to preparation")
	await _type("vocab")
	_check(app.route == "words", "vocab command reopens vocabulary")
	var first_book: Control
	for button in app.page.find_children("*", "Button", true, false):
		if (button as Button).text.begins_with("小学一年级"):
			first_book = button
			break
	var list_scroll: ScrollContainer
	if first_book != null:
		list_scroll = first_book.get_parent().get_parent() as ScrollContainer
		print("Vocabulary first row rect=%s list viewport=%s" % [first_book.get_global_rect(), list_scroll.get_global_rect() if list_scroll != null else Rect2()])
	_check(first_book != null and list_scroll != null and first_book.get_global_rect().intersects(list_scroll.get_global_rect()), "initial vocabulary focus leaves first row visible")
	await _capture("02-vocabulary")
	var footer_position := app.page.footer.global_position
	var details := app.page.find_child("WordDetails", true, false) as ScrollContainer
	details.scroll_vertical = 500
	await _settle()
	_check(app.page.footer.global_position == footer_position, "detail scroll leaves fixed controls in place")
	await _type("import")
	_check(app.route == "import", "import page")
	print("Import layout page=%s panel_position=%s panel_size=%s panel_min=%s scroll_position=%s scroll_size=%s footer_position=%s footer_size=%s viewport=%s" % [app.page.size, app.page.panel.position, app.page.panel.size, app.page.panel.get_combined_minimum_size(), app.page.scroll.position, app.page.scroll.size, app.page.footer.global_position, app.page.footer.size, root.get_visible_rect().size])
	_check(app.page.footer.get_global_rect().end.y <= root.get_visible_rect().size.y, "import footer stays inside native window")
	await _click(app.import_text)
	await _type("word,meaning\nhello world,你好\nbook,书\nbook,重复\n7bad,无效")
	_check(app.route == "import" and app.router.buffer.is_empty(), "text editor owns input")
	await _click(app.page.find_child("Preview", true, false) as Control)
	_check(app.preview != null and app.preview.entries.size() == 2 and app.preview.duplicates == 1 and app.preview.issues.size() == 1, "import preview counts and row issues")
	await _capture("03-import-preview")
	await _click(app.page.find_child("File", true, false) as Control)
	var dialogs := app.root.find_children("*", "FileDialog", true, false)
	_check(dialogs.size() == 1, "file button opens native dialog")
	if dialogs.is_empty():
		print("Application stopped after missing FileDialog | %s" % evidence)
		quit(1)
		return
	var dialog := dialogs[0] as FileDialog
	_check(app.router.context == InputRouter.Context.MODAL, "file dialog owns modal input")
	dialog.file_selected.emit(evidence.path_join("missing.txt"))
	await _settle()
	_check(app.preview == null and app.import_save.disabled, "failed file selection invalidates prior preview")
	await _click(app.page.find_child("Preview", true, false) as Control)
	await _click(app.import_save)
	_check(app.route == "words" and app.selected_id.begins_with("custom-"), "save import opens the persisted vocabulary")
	app.grow.button_pressed = false
	await _click(app.page.find_child("Use", true, false) as Control)
	var restored := AppSettings.new(app.settings.path)
	restored.load_settings()
	_check(restored.vocabulary_id == app.selected_id and not restored.progressive, "vocabulary choice persists")
	await _key(KEY_ESCAPE)
	_check(app.route == "prepare" and app.archive.prepared, "imported vocabulary closes back to preparation")
	await _type("guide")
	_check(app.route == "guide", "guide command opens help from preparation")
	await _type("practice")
	_check(app.route == "practice", "guide starts word practice using the selected library")
	await _type("he")
	_check(app.practice.typing.word == "hello world" and app.practice.typing.progress == 2, "first letter locks phrase and physical characters advance")
	await _type("x")
	_check(app.practice.typing.progress == 2 and app.practice.typing.mistakes == 1, "wrong character preserves progress")
	await _capture("04-typing")
	await _key(KEY_ESCAPE)
	_check(paused and app.route == "pause", "Escape pauses session")
	var count := app.practice.manual_characters
	await _type("z")
	_check(app.practice.typing.progress == 2 and app.practice.manual_characters == count, "pause cannot type or grant receipts")
	await _capture("05-pause")
	await _key(KEY_ESCAPE)
	_check(not paused and app.route == "practice" and app.practice.typing.progress == 2, "resume retains progress")
	await _type("llo")
	await _key(KEY_SPACE, 32)
	_check(app.practice.typing.progress == 5, "Space remains defense and skips visible phrase space")
	await _type("world")
	await _settle()
	_check(app.practice.completed_words == 1 and app.practice.manual_characters == 10, "one phrase completion counts ten physical characters")
	await _key(KEY_ESCAPE)
	await _type("settings")
	_check(app.route == "settings" and paused, "settings available while paused")
	var volume_slider := app.settings_controls["volume"] as HSlider
	var volume_before := app.settings.volume
	volume_slider.value = .42
	volume_slider.value = .56
	var saved_volume := AppSettings.new(app.settings.path)
	saved_volume.load_settings()
	_check(is_equal_approx(app.settings.volume,.56) and is_equal_approx(saved_volume.volume,volume_before), "audio previews immediately without saving every slider step")
	await create_timer(.45).timeout
	saved_volume.load_settings()
	_check(is_equal_approx(saved_volume.volume,.56) and not app._audio_settings_dirty, "audio settings debounce saves the last value while paused")
	var scale_option := app.settings_controls["ui_scale"] as OptionButton
	await _click(scale_option)
	await _key(KEY_ESCAPE)
	_check(app.route == "settings", "Escape closes option popup without leaving settings")
	(app.settings_controls["reduce_motion"] as CheckButton).button_pressed = true
	scale_option.selected = 3
	scale_option.item_selected.emit(3)
	await _settle()
	var display_settings := AppSettings.new(app.settings.path)
	display_settings.load_settings()
	_check(app.settings.reduce_motion and display_settings.reduce_motion and is_equal_approx(minf(app.root.size.x / 1920.0, app.root.size.y / 1080.0), 1.0 / 1.25), "display settings apply and save automatically while paused")
	await _capture("06-settings-large")
	await _type("back")
	await _key(KEY_ESCAPE)
	_check(app.route == "practice" and not paused, "settings return through pause to session")
	app.router.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle()
	_check(app.route == "pause" and paused, "focus loss pauses without synthesizing held keys")
	await _type("quit")
	await _type("confirm")
	_check(app.route == "home" and not paused and app.archive.reduced_motion, "return to archive keeps reduced motion")
	var frozen_clock := app.archive.clock
	await create_timer(0.12).timeout
	_check(is_equal_approx(app.archive.clock, frozen_clock), "reduced motion freezes archive clock")
	if DisplayServer.get_name() != "headless":
		await create_timer(1.0).timeout
		_check(app.archive.stage.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "settled reduced-motion scenery stops redrawing its HDR viewport")
	await _type("flame")
	_check(app.archive.selected == 3 and is_equal_approx(app.archive.orbit, app.archive.orbit_target), "reduced motion switches books without orbit transition")
	await _type("help")
	_check(app.route == "guide", "help command opens guide from archive")
	await _capture("07-guide-top")
	footer_position = app.page.footer.global_position
	app.page.scroll.scroll_vertical = 800
	await _settle()
	_check(app.page.footer.global_position == footer_position, "long guide scroll has fixed footer")
	await _capture("07-guide-scrolled")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1600, 900)
		await _settle()
		_check(app.page.footer.get_global_rect().end.y <= root.get_visible_rect().size.y, "1600x900 layout")
		_check(app.page.pattern.position.is_equal_approx(app.page.panel.position + Vector2(-25,-40)), "page emblem follows panel placement after resize")
		await _capture("08-window-large")
		root.size = Vector2i(1024, 768)
		await _settle()
		_check(app.page.footer.get_global_rect().end.y <= root.get_visible_rect().size.y, "4:3 layout keeps footer visible")
		await _capture("09-window-4x3")
		await _key(KEY_ESCAPE)
		await _type("settings")
		(app.settings_controls["fullscreen"] as CheckButton).button_pressed = true
		await create_timer(0.5).timeout
		_check(root.mode == Window.MODE_FULLSCREEN, "native fullscreen applied")
		await _capture("10-fullscreen")
		(app.settings_controls["fullscreen"] as CheckButton).button_pressed = false
		await _settle()
		_check(root.mode == Window.MODE_WINDOWED, "return to windowed")
	var path := app.settings.path
	var book_id := app.settings.vocabulary_id
	app.queue_free()
	await process_frame
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(path)
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	_check(app.settings.reduce_motion and app.settings.vocabulary_id == book_id and app.vocabulary.load_entries(book_id).size() == 2 and app.settings.book_id == "flame" and app.settings.difficulty == "hard" and app.settings.run_seed == "arc123", "application restart restores preparation, settings and custom library")
	var vocab_button := app.archive.menu.find_child("Vocab", true, false) as Button
	var help_button := app.archive.menu.find_child("Help", true, false) as Button
	_check(vocab_button != null and help_button != null and vocab_button.focus_mode == Control.FOCUS_NONE and help_button.focus_mode == Control.FOCUS_NONE, "menu controls have no keyboard focus navigation")
	if vocab_button != null and help_button != null:
		await _key(KEY_TAB)
		_check(root.gui_get_focus_owner() == null, "Tab does not create menu focus")
		app.settings.reduce_motion = false
		app.settings.progressive = false
		root.size = Vector2i(1920, 1080)
		await _settle()
		await _key(KEY_ENTER)
		_check(app.route == "departure" and root.gui_get_focus_owner() == null, "Enter starts the departure ritual without creating GUI focus")
		await _key(KEY_ENTER)
		for step in 90:
			if app.route != "departure":
				break
			await create_timer(0.05).timeout
		_check(app.route == "battle" and app.battle.session.manual_characters == 0, "Departure hands over once; repeated input does not reach combat")
		await _capture("07-battle-ready")
		# Arrivals begin outside combat; type only after the advertised word exists.
		for step in 240:
			if app.battle.session.typing._targets.has(app.battle.session.enemies[0].id):
				break
			await physics_frame
		var first_spell := app.battle.session.enemies[0].word.replace(" ", "")
		await _type(first_spell.left(1))
		# A tiny custom library can repeat words; the first character owns the lock.
		var paid_target := app.battle.session.enemy_by_id(app.battle.session.typing.target_id)
		await _type(first_spell.substr(1))
		# An edge arrival needs longer flight than a target already near the player.
		for step in 180:
			if paid_target.hp_q < paid_target.max_hp_q:
				break
			await physics_frame
		_check(app.battle.session.manual_characters == first_spell.length() and app.battle.session.completed_words == 1 and paid_target.hp_q < paid_target.max_hp_q, "native battle turns real keys into a paid hit (input %d/%d, words %d, target %s, hp %d/%d)" % [app.battle.session.manual_characters, first_spell.length(), app.battle.session.completed_words, paid_target.id, paid_target.hp_q, paid_target.max_hp_q])
		if DisplayServer.get_name() != "headless":
			_check(app.battle.audio._voices.size() > 0, "committed cast and impact play native battle audio")
		await _capture("07-battle-cast")
		var before_dodge := app.battle.session.player_position
		await _key(KEY_LEFT)
		await create_timer(.2).timeout
		_check(app.battle.session.player_position.x < before_dodge.x and root.gui_get_focus_owner() == null, "battle direction key performs a spatial dodge without moving GUI focus")
		await _key(KEY_ESCAPE)
		_check(app.route == "pause" and paused, "battle Escape pauses fixed-step simulation")
		_check(app.battle.audio._voices.is_empty(), "pause stops active battle voices")
		app._home()
		await create_timer(.25).timeout
		await _click(help_button)
		_check(app.route == "guide", "mouse opens guide with focus navigation disabled")
	app._settings_page("home")
	app._defaults()
	(app.settings_controls["ui_scale"] as OptionButton).selected = 0
	(app.settings_controls["quality"] as OptionButton).selected = 0
	app._save_settings()
	app._defaults()
	var reset_settings := AppSettings.new(app.settings.path)
	reset_settings.load_settings()
	_check(is_equal_approx(reset_settings.ui_scale,1.0) and reset_settings.quality == 2, "restore defaults persists when only dropdown values differ")
	var report := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "headless": DisplayServer.get_name() == "headless"}, "\t"))
	report.close()
	print("Application checks: %d passed, %d failed | %s" % [checks.size() - failures, failures, evidence])
	quit(0 if failures == 0 else 1)


func _type(value: String) -> void:
	for character in value:
		await _key(KEY_ENTER if character == "\n" else (character.to_upper().unicode_at(0) as Key), character.unicode_at(0))


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


func _click(control: Control) -> void:
	if control == null:
		_check(false, "click target exists")
		return
	var event := InputEventMouseButton.new()
	event.position = root.get_screen_transform() * control.get_global_transform() * (control.size * .5)
	event.button_index = MOUSE_BUTTON_LEFT
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


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	print("Capture %s source image format: %s" % [label, source.get_format()])
	var image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			image.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	image.save_png(evidence.path_join(label + ".png"))


func _check(condition: bool, label: String) -> void:
	checks.append(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1
		push_error(label)
