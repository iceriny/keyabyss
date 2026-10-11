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
	app.profile_base_path = evidence.path_join("profiles")
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = "--setup-feedback" in OS.get_cmdline_user_args()
	root.add_child(app)
	await _settle()
	if "--relic-upgrade" in OS.get_cmdline_user_args():
		await _review_relic_upgrade()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cleanup-route="):
			await _review_cleanup(argument.trim_prefix("--cleanup-route="))
			return
	if "--setup-feedback" in OS.get_cmdline_user_args():
		await _review_setup_feedback()
		return
	if "--vsync-only" in OS.get_cmdline_user_args():
		await _review_vsync()
		return
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


func _review_relic_upgrade() -> void:
	await create_timer(0.4).timeout
	await _capture("relic-home")
	var catalog := BuildCatalog.new()
	for id in catalog.relic_ids():
		var relic := catalog.get_definition(StringName(id)) as RelicDefinition
		for stack in [1, relic.max_stacks]:
			var description := ContentDescription.summary(relic, stack)
			_check(not description.contains("{") and not description.contains("}"), "%s layer %d renders every numeric token" % [id, stack])
	_check(ContentDescription.summary(catalog.get_definition(&"R001"), 2).contains("56.25"), "compound growth reads the same numeric definition")
	_check(GameTerms.matches("完美御术后获得护盾").size() == 2, "longest terms avoid nested duplicate explanations")
	app.run = RunSession.new(app.saves, app.profile)
	_check(app.run.begin(&"frost", app.settings), "isolated UI run starts")
	app.run.phase = "REWARD"
	app.run.rewards.earned = 3
	app.run.offer = {"id": "ui-relic", "candidates": ["G001", "F007", "F026"]}
	app.run.selection.assets = {&"F003": 1, &"F007": 1}
	app._show_run_stage(false)
	await _settle()
	var choices := app.page.body.get_node("RewardChoices")
	var first := choices.get_child(0) as RelicRewardChoice
	var second := choices.get_child(1) as RelicRewardChoice
	var third := choices.get_child(2) as RelicRewardChoice
	_check(first._surface != second._surface and second._surface != third._surface, "rarity cards own independent shader state")
	_check(first._surface.get_shader_parameter("rarity_color") != third._surface.get_shader_parameter("rarity_color"), "rarities visibly use different colors")
	_check(bool(third._surface.get_shader_parameter("awakening")), "awakening enables the book effect")
	var original_rect := first.get_global_rect()
	var button := first.content.get_child(first.content.get_child_count() - 1) as Button
	var button_rect := button.get_global_rect()
	await _capture("relic-summary")
	await _alt(true)
	_check(first.detail_mode and second.detail_mode and third.detail_mode, "physical Alt opens all card details")
	_check((second.get_node("Content/Reading/Description") as Label).text.contains("取得后 · 2层"), "owned relic preview shows actual next layer")
	_check(first.get_global_rect() == original_rect and button.get_global_rect() == button_rect, "Alt keeps card and action positions fixed")
	await _capture("relic-alt")
	await _alt(false)
	_check(not first.detail_mode and not third.detail_mode, "releasing Alt restores summaries")
	var prose := second.get_node("Content/Reading/Description") as Label
	var found := GameTerms.matches(prose.text)
	_check(not found.is_empty(), "reward effect contains a registered term")
	if not found.is_empty():
		var bounds := prose.get_character_bounds(found[0].get_start())
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_screen_transform() * prose.get_global_transform() * bounds.get_center()
		Input.parse_input_event(motion)
		await create_timer(0.4).timeout
		_check(app.term_tooltips._bubble.visible and app.term_tooltips._title.text == found[0].get_string(), "real pointer over a shaped character opens its glossary entry")
		_check(app.term_tooltips._bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tooltip never intercepts reward input")
		await _capture("relic-tooltip")
		await _move_to(app.page.heading)
		_check(not app.term_tooltips._bubble.visible, "moving away dismisses term explanation")
	third.reduced_motion = false
	await create_timer(0.4).timeout
	_check(float(third._surface.get_shader_parameter("clock")) > 0.0, "awakening motion advances with normal motion")
	await _capture("relic-frost-motion")
	third.reduced_motion = true
	await _settle()
	_check(is_zero_approx(float(third._surface.get_shader_parameter("clock"))), "reduced motion freezes awakening animation")
	for book in [&"flame", &"storm", &"spirit"]:
		app.run.selection.book_id = book
		app.run.selection.assets.clear()
		var awakening: String = {&"flame": "A021", &"storm": "T026", &"spirit": "P026"}[book]
		app.run.offer.candidates = [awakening, "G027", "G025"]
		app._show_run_stage(false)
		await _settle()
		var card := app.page.body.get_node("RewardChoices").get_child(0) as RelicRewardChoice
		var rare := app.page.body.get_node("RewardChoices").get_child(1) as RelicRewardChoice
		_check(rare._surface.get_shader_parameter("rarity_color") == ContentDescription.COLORS["rare"], "rare relic uses its own card color")
		_check(int(card._surface.get_shader_parameter("school")) == ["frost", "flame", "storm", "spirit"].find(str(book)), "awakening chooses " + str(book) + " effect")
		await _capture("relic-" + str(book))
		card.reduced_motion = false
		await create_timer(0.4).timeout
		await _capture("relic-" + str(book) + "-motion")
	app.run.selection.book_id = &"frost"
	app.run.offer.candidates = ["G001", "G002", "G025"]
	app._show_run_stage(false)
	await _settle()
	first = app.page.body.get_node("RewardChoices").get_child(0)
	await _click(first.content.get_child(first.content.get_child_count() - 1))
	_check(app.run.compiler.compile(app.run.selection).build.asset_stacks(&"G001") == 1, "real reward button commits the selected relic")
	_check(app.run.rewards.spent == 1 and app.run.offer.id != "ui-relic", "reward transaction spends once and advances offer")
	app._relics_page()
	await create_timer(0.6).timeout
	_check(app.commands.has("relic196"), "codex includes all 196 relics")
	await _capture("relic-codex")
	app._guide()
	await create_timer(0.5).timeout
	_check(app.commands.has("note-04"), "guide builds dynamic relic examples")
	app.commands["note-04"].call()
	await _settle()
	var example_matches := false
	for label: Label in app.page.body.find_children("*", "Label", true, false):
		if label.text == ContentDescription.summary(catalog.get_definition(&"R041")): example_matches = true
	_check(example_matches, "guide example reads relic data instead of duplicated copy")
	app.page.scroll.scroll_vertical = 0
	await _settle()
	for label: Label in app.page.body.find_children("*", "Label", true, false):
		if not label.text.contains("起手迎击"): continue
		var bounds := label.get_character_bounds(label.text.find("完美御术"))
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_screen_transform() * label.get_global_transform() * bounds.get_center()
		Input.parse_input_event(motion)
		await create_timer(0.4).timeout
		_check(app.term_tooltips._bubble.visible and app.term_tooltips._title.text == "完美御术", "global glossary also handles guide prose")
		break
	app._run_records()
	app._record_detail({"book": "frost", "reason": "victory", "rooms": 9, "characters": 321, "build": app.run.selection.to_dict()})
	await _settle()
	var recorded := false
	for label: Label in app._history_detail.find_children("*", "Label", true, false):
		if label.text == ContentDescription.summary(catalog.get_definition(&"G001")): recorded = true
	_check(recorded, "record descriptions read the recorded relic layers")
	app._home(false)
	await _settle()
	_check(not app.term_tooltips._bubble.visible, "closing source page dismisses tooltip")
	app.run = null
	app.profile.run_checkpoint.clear()
	app.archive.set_prepared(true)
	await _settle()
	await _capture("relic-preparation")
	var report := FileAccess.open(evidence.path_join("relic-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method()}, "\t"))
	report.close()
	print("Relic UI checks: %d passed, %d failed | %s" % [checks.size() - failures, failures, evidence])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _alt(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ALT
	event.physical_keycode = KEY_ALT
	event.pressed = down
	event.alt_pressed = down
	Input.parse_input_event(event)
	await _settle()


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


func _review_vsync() -> void:
	app._settings_page("home")
	app._select_settings_tab("display", false)
	await _settle()
	var toggle := app.settings_controls["vsync"] as CheckButton
	_check(app.settings.vsync and toggle.button_pressed, "new and existing settings default to synchronized display")
	await _click(toggle)
	_check(not app.settings.vsync and DisplayServer.window_get_vsync_mode(root.get_window_id()) == DisplayServer.VSYNC_DISABLED, "real pointer disables vertical synchronization")
	_check(Engine.max_fps == roundi(DisplayServer.screen_get_refresh_rate(root.current_screen)), "unsynchronized rendering is capped at the current monitor refresh")
	var restored := AppSettings.new(app.settings.path)
	restored.load_settings()
	_check(not restored.vsync, "synchronization choice survives saved settings reload")
	await _capture("settings-vsync-off")
	var original_screen := root.current_screen
	if DisplayServer.get_screen_count() > 1:
		root.current_screen = (original_screen + 1) % DisplayServer.get_screen_count()
		await create_timer(0.3).timeout
		_check(app.root._frame_limit_screen == root.current_screen and Engine.max_fps == roundi(DisplayServer.screen_get_refresh_rate(root.current_screen)), "moving between monitors refreshes the unsynchronized ceiling")
		print("Monitor switch: screen=%d | refresh=%.2f Hz | cap=%d" % [root.current_screen, DisplayServer.screen_get_refresh_rate(root.current_screen), Engine.max_fps])
		root.current_screen = original_screen
		await create_timer(0.3).timeout
	paused = true
	await _type("vsync")
	_check(app.settings.vsync and toggle.button_pressed and Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode(root.get_window_id()) == DisplayServer.VSYNC_ENABLED, "settings command reenables synchronization while the game is paused")
	paused = false
	await _click(toggle)
	app._defaults()
	_check(app.settings.vsync and toggle.button_pressed and Engine.max_fps == 0, "restore defaults reenables vertical synchronization")
	print("VSync review: %d checks, %d failed | %s" % [checks.size(), failures, evidence])
	app._quit_game()
	if failures > 0: quit(1)


func _review_setup_feedback() -> void:
	Engine.max_fps = 60
	app.settings.apply(root)
	_check(Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode(root.get_window_id()) == DisplayServer.VSYNC_ENABLED, "display settings remove a fixed cap and synchronize to the current monitor")
	print("Display pacing: refresh=%.2f Hz | software_cap=%d | vsync=%d | screens=%d" % [DisplayServer.screen_get_refresh_rate(root.current_screen), Engine.max_fps, DisplayServer.window_get_vsync_mode(root.get_window_id()), DisplayServer.get_screen_count()])
	await _key(KEY_A, 97)
	await create_timer(0.25).timeout
	_check(app.route == "calibration" and app.settings.intro_complete and not app.settings.first_setup_complete, "first native entry opens calibration after the welcome")
	app.settings.reduce_motion = false
	app._apply_calibration_settings()
	await create_timer(2.0).timeout
	var setup := app.page as FirstVisitSetup
	for frame in 180:
		if setup.fps.sample_ready: break
		await process_frame
	_check(app.route == "calibration" and setup != null and not app.archive.visible, "first-visit calibration owns the page and stops the hidden archive")
	_check(setup.preview.stage.viewport.size == root.content_scale_size, "pressure preview uses full output pixels")
	_check(setup.preview.session.world_time > 0.0 and not setup.preview.session.enemies.is_empty(), "pressure preview runs real combat")
	_check(app.settings.show_meaning, "Chinese meanings start enabled")
	_check(setup.fps.sample_ready and setup.fps.frames_per_second > 0.0, "calibration reports measured FPS after initial preparation")
	print("Calibration sample: %.1f FPS | enemies=%d | threats=%d | effects=%d | output=%s" % [setup.fps.frames_per_second, setup.preview.session.enemies.size(), setup.preview.session.threats.size(), setup.preview.session.effects.size(), str(setup.preview.stage.viewport.size)])
	await _capture("setup-high")
	if "--setup-layout" in OS.get_cmdline_user_args():
		_check(setup.panel.get_rect().get_center().distance_to(setup.size * 0.5) < 1.0, "calibration controls form a centered group")
		app.settings.resolution = Vector2i(1440, 900)
		app.settings.apply(root)
		app._apply_visual_settings()
		await create_timer(0.5).timeout
		_check(Vector2i(root.get_texture().get_size()) == Vector2i(1440, 900) and setup.preview.stage.viewport.size == Vector2i(1440, 900), "16:10 capture and pressure viewport use the actual selected output")
		var caption := setup.get_node("ContentLayer/PreviewCaption") as Control
		_check(Rect2(Vector2.ZERO, setup.size).encloses(setup.panel.get_rect()) and not setup.panel.get_rect().intersects(caption.get_rect()), "centered calibration and FPS remain separate at 16:10 output")
		await _capture("setup-centered-16x10")
		await _click(setup.controls["show_meaning"])
		_check(not app.settings.show_meaning, "centered meaning control responds to its real pointer location")
		await _click(setup.controls["volume"])
		_check(app.settings.volume > 0.35 and app.settings.volume < 0.65, "centered volume slider responds after resizing")
		var centered_pressure: WeakRef = weakref(setup.preview)
		await _click(setup.confirm_button)
		await create_timer(0.35).timeout
		_check(app.route == "home" and app.settings.first_setup_complete and centered_pressure.get_ref() == null, "centered save action closes calibration and frees its pressure scene")
		print("Setup layout: %d checks, %d failed | %s" % [checks.size(), failures, evidence])
		app._quit_game()
		if failures > 0: quit(1)
		return
	var first_pressure: WeakRef = weakref(setup.preview)
	await create_timer(FirstVisitSetup.LOOP_SECONDS + 0.2).timeout
	_check(first_pressure.get_ref() == null and setup.preview != null and setup.preview.session.enemies.size() == 18, "pressure loop frees its previous encounter and keeps a bounded enemy count")
	await _click(setup.controls["show_meaning"])
	_check(not app.settings.show_meaning, "real pointer toggles meanings in calibration")
	await _click(setup.controls["volume"])
	_check(app.settings.volume > 0.35 and app.settings.volume < 0.65, "real pointer adjusts live master volume")
	var quality_control := setup.controls["quality"] as OptionButton
	quality_control.selected = 0
	quality_control.item_selected.emit(0)
	var fluid_control := setup.controls["fluid_quality"] as OptionButton
	fluid_control.selected = 0
	fluid_control.item_selected.emit(0)
	await process_frame
	_check(setup.preview.visuals.fluid.quality == FluidField2D.Quality.OFF, "fluid can be disabled in the actual preview")
	fluid_control.selected = 4
	fluid_control.item_selected.emit(4)
	await create_timer(0.3).timeout
	_check(setup.preview.visuals.fluid.quality == FluidField2D.Quality.ULTRA, "highest fluid precision configures the actual preview")
	fluid_control.selected = 1
	fluid_control.item_selected.emit(1)
	await create_timer(1.2).timeout
	for frame in 180:
		if setup.fps.sample_ready: break
		await process_frame
	_check(app.settings.quality == 0 and app.settings.fluid_quality == 1, "quality and fluid choices update the real preview")
	_check(Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode(root.get_window_id()) == DisplayServer.VSYNC_ENABLED, "changing quality preserves monitor-paced rendering")
	await _capture("setup-low")
	var pressure_ref: WeakRef = weakref(setup.preview)
	await _click(setup.confirm_button)
	await create_timer(0.35).timeout
	_check(app.route == "home" and app.settings.first_setup_complete and pressure_ref.get_ref() == null, "confirm saves calibration, returns home and frees the pressure scene")
	var frame_started := Time.get_ticks_usec()
	var frame_count := 0
	while Time.get_ticks_usec() - frame_started < 1000000:
		await process_frame
		frame_count += 1
	print("Archive display sample: %.1f FPS | refresh=%.2f Hz" % [frame_count * 1000000.0 / (Time.get_ticks_usec() - frame_started), DisplayServer.screen_get_refresh_rate(root.current_screen)])
	var restored := AppSettings.new(app.settings.path)
	restored.load_settings()
	_check(restored.first_setup_complete and not restored.show_meaning and restored.quality == 0 and restored.fluid_quality == 1 and is_equal_approx(restored.volume, app.settings.volume), "calibration choices persist for next launch")
	app.queue_free()
	await process_frame
	await process_frame
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = restored
	app.settings_prepared = true
	app.profile_base_path = evidence.path_join("profiles")
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	root.add_child(app)
	await _settle()
	await _key(KEY_A, 97)
	await create_timer(0.4).timeout
	await _key(KEY_ENTER)
	await create_timer(0.8).timeout
	_check(app.route == "home" and not is_instance_valid(app.welcome_gate) and app.settings.first_setup_complete, "next launch enters the archive without repeating calibration")
	app._settings_page("home")
	await _settle()
	await _click(app.settings_controls["show_fps"])
	await create_timer(0.6).timeout
	_check(app.settings.show_fps and app.fps_display.visible, "FPS setting shows its live overlay")
	await _capture("settings-fps")
	await _click(app.page.footer.get_node("About"))
	await create_timer(0.5).timeout
	_check(app.route == "about", "settings opens the About page")
	await _capture("about")
	await _key(KEY_ESCAPE)
	_check(app.route == "settings" and app.settings_return == "home", "About returns to settings")
	paused = true
	await _type("calibrate")
	await create_timer(0.4).timeout
	_check(app.route == "calibration" and app.page.close_button.visible, "calibration can be revisited from settings")
	var paused_setup := app.page as FirstVisitSetup
	var preview_time := paused_setup.preview.session.world_time
	await create_timer(0.4, true).timeout
	_check(paused and paused_setup.preview.session.world_time > preview_time, "pressure preview advances while the underlying game stays paused")
	await _key(KEY_ESCAPE)
	await create_timer(0.2).timeout
	_check(app.route == "settings", "revisited calibration returns to settings")
	var previous_fps_time := app.fps_display._started_usec
	paused = true
	await create_timer(0.6, true).timeout
	_check(app.fps_display.visible and app.fps_display._started_usec > previous_fps_time, "FPS continues measuring during pause")
	paused = false
	app._back()
	print("Setup feedback: %d checks, %d failed | %s" % [checks.size(), failures, evidence])
	app._quit_game()
	if failures > 0: quit(1)


func _review_cleanup(exit_route: String) -> void:
	app.settings.reduce_motion = false
	app._apply_visual_settings()
	if exit_route == "calibration":
		app._first_setup_page()
	elif exit_route == "battle":
		app.settings.reduce_motion = true
		app._start_battle()
		await create_timer(0.8).timeout
		app.settings.reduce_motion = false
		app.battle.apply_options()
		app._pause()
		app._settings_page("pause")
		app._first_setup_page("settings")
		await create_timer(0.4, true).timeout
		app._complete_first_setup()
		_check(paused and not app.archive.visible and app.route == "settings", "returning from paused calibration keeps the archive hidden and battle paused")
		app._settings_back()
		app._resume()
	await create_timer(2.0).timeout
	_check(app.route == exit_route, "cleanup fixture reaches " + exit_route)
	print("Exit lifecycle: %s | %d failed | %s" % [app.route, failures, evidence])
	app._quit_game()
	if failures > 0: quit(1)


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
