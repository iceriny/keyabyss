extends SceneTree
## Native GUI events for control commands, key hints and smooth scrolling.

var app: KeyabyssApp
var evidence: String
var failures := 0
var checks: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--screen-capture" in OS.get_cmdline_user_args():
		root.always_on_top = true
		root.grab_focus()
	evidence = "res://.temp/ui-refinement/run-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.sound = false
	app.settings.ambience = false
	app.settings.reduce_motion = true
	if not "--archive-tutorial" in OS.get_cmdline_user_args() and not "--setup-feedback" in OS.get_cmdline_user_args():
		# Existing feature reviews start with explicitly completed onboarding.
		app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.profile_base_path = evidence.path_join("profiles")
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = "--setup-feedback" in OS.get_cmdline_user_args()
	root.add_child(app)
	await _settle()
	if "--archive-tutorial" in OS.get_cmdline_user_args():
		await _review_archive_tutorial()
		return
	if "--combat-revision" in OS.get_cmdline_user_args():
		await _review_combat_revision()
		print("Combat revision UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
		var revision_report := FileAccess.open(evidence.path_join("combat-revision-checks.json"), FileAccess.WRITE)
		revision_report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
		revision_report.close()
		app.queue_free()
		await process_frame
		quit(1 if failures else 0)
		return
	if "--screen-capture" in OS.get_cmdline_user_args():
		root.grab_focus()
		await process_frame
	if "--tutorial-mechanics" in OS.get_cmdline_user_args():
		await _review_tutorial_mechanics()
		return
	if "--tutorial-shortcuts" in OS.get_cmdline_user_args():
		await _review_tutorial_shortcuts()
		return
	if "--tutorial-navigation" in OS.get_cmdline_user_args():
		await _review_tutorial_navigation()
		return
	if "--teaching-copy" in OS.get_cmdline_user_args():
		await _review_teaching_copy()
		return
	if "--curved-trajectory" in OS.get_cmdline_user_args():
		await _review_curved_frames()
		var output := FileAccess.open(evidence.path_join("curved-trajectory-checks.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
		output.close()
		print("Curved trajectory UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
		quit(1 if failures else 0)
		return
	if "--tutorial-arc" in OS.get_cmdline_user_args():
		await _review_tutorial_arc()
		return
	if "--crystal-sheets" in OS.get_cmdline_user_args():
		await _review_crystal_sheets()
		return
	if "--menu-layout" in OS.get_cmdline_user_args():
		await _review_menu_layout()
		return
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
	if "--m2-pages-only" in OS.get_cmdline_user_args() or "--popup-style" in OS.get_cmdline_user_args():
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


func _review_crystal_sheets() -> void:
	await _type("settings")
	await create_timer(0.5).timeout
	var sheets := app.page.get_node("CrystalSheets") as MeshInstance2D
	var optical := sheets.material as ShaderMaterial
	var original_mesh := sheets.mesh
	var heading_position := app.page.heading.global_position
	var arrays := sheets.mesh.surface_get_arrays(0)
	var outside_reading := true
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		if Rect2(app.page.panel.position, app.page.panel.size).has_point(Vector2(vertex.x, vertex.y)):
			outside_reading = false
	_check(outside_reading, "crystal geometry stays outside the reading and control area")
	_check(is_zero_approx(float(optical.get_shader_parameter("clock"))), "reduced motion retains stationary crystal faces")
	await _capture("crystal-settings-still")
	app.settings.reduce_motion = false
	app._apply_visual_settings()
	await create_timer(1.0).timeout
	var first_clock := float(optical.get_shader_parameter("clock"))
	await _capture("crystal-settings-flow-a")
	await create_timer(3.0).timeout
	_check(float(optical.get_shader_parameter("clock")) > first_clock, "flow clock advances on the live settings page")
	_check(sheets.mesh == original_mesh and app.page.heading.global_position == heading_position, "flow leaves geometry and page layout stationary")
	await _capture("crystal-settings-flow-b")
	app.settings.reduce_motion = true
	app._apply_visual_settings()
	await _settle()
	_check(is_zero_approx(float(optical.get_shader_parameter("clock"))), "changing reduce motion stops the existing material")
	await _type("about")
	await create_timer(0.5).timeout
	await _capture("crystal-about")
	app._relics_page()
	await create_timer(0.5).timeout
	await _capture("crystal-codex")
	app._home(false)
	app._start_practice()
	await _settle()
	await _key(KEY_ESCAPE)
	_check(app.route == "pause" and paused, "compact paused page remains interactive with crystal decoration")
	await _capture("crystal-pause")
	await _key(KEY_ESCAPE)
	_check(app.route == "practice" and not paused, "decorated pause page closes and resumes normally")
	app._home(false)
	var report := FileAccess.open(evidence.path_join("crystal-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("Crystal sheet checks: %d passed, %d failed | %s" % [checks.size() - failures, failures, evidence])
	app.queue_free()
	await _settle()
	quit(0 if failures == 0 else 1)


func _review_menu_layout() -> void:
	await create_timer(0.4).timeout
	var selected_book := app.archive.selected
	await _key(KEY_RIGHT)
	_check(app.archive.selected == posmod(selected_book + 1, 4), "home arrow changes book")
	await _key(KEY_1)
	_check(app.archive.selected == 0, "physical number selects home book through its word action")
	await _capture("menu-home")
	await _key(KEY_SPACE)
	_check(app.route == "prepare", "Space opens preparation")
	await _key(KEY_RIGHT)
	_check(app.settings.difficulty == "hard", "preparation arrow changes difficulty")
	await _key(KEY_2)
	_check(app.settings.difficulty == "normal", "preparation number selects difficulty")
	await _type("seed")
	await _key(KEY_SPACE, 32)
	await _key(KEY_3, 51)
	await _key(KEY_ENTER)
	_check(app.route == "prepare" and app.archive.seed_edit.text == " 3" and app.settings.difficulty == "normal", "editing owns space, number and Enter")
	await _key(KEY_ESCAPE)
	await _capture("menu-preparation")
	await _type("settings")
	await _key(KEY_3)
	_check(app.settings_tab == "audio", "settings number opens its named section")
	await _type("volume")
	await _key(KEY_SPACE)
	_check(app.route == "settings" and root.gui_get_focus_owner() == null, "Space leaves slider editing without confirming the page")
	await _type("effects")
	var popup := (app.settings_controls["quality"] as OptionButton).get_popup()
	_check(popup.visible, "word opens native options")
	await _key(KEY_DOWN, 0, popup.get_window_id())
	await _key(KEY_ENTER, 0, popup.get_window_id())
	_check(not popup.visible and app.route == "settings", "native popup arrows and confirmation never reach page navigation")
	await _capture("menu-settings")
	app._home(false)
	app.run = RunSession.new(app.saves, app.profile)
	_check(await app.run.begin(&"flame", app.settings), "isolated shortcut run starts")
	app.run.phase = "REWARD"
	app.run.rewards.earned = 5
	app.run.offer = {"id": "ui-menu-reward", "candidates": ["G001", "G002", "R012"]}
	app._show_run_stage(false)
	await _settle()
	var choices := app.page.body.get_node("RewardChoices")
	var first := choices.get_child(0) as RelicRewardChoice
	_check(app.menu_navigation.selected_word() == "take1" and first.keyboard_selected, "reward starts with a visible first choice")
	_check(not app.page.scroll.get_v_scroll_bar().visible, "reward page has no outer scrolling")
	for choice: RelicRewardChoice in choices.get_children():
		var take := choice.find_child("Take*", true, false) as OpenButton
		var title := choice.get_node("Content/Title") as Label
		_check(absf(take.get_global_rect().get_center().x - title.get_global_rect().get_center().x) < 1.0, "relic title and take action share their center")
		var caption_width := take.get_theme_font("font").get_string_size(take.text, HORIZONTAL_ALIGNMENT_LEFT, -1, take.get_theme_font_size("font_size")).x
		var caption_center := take.global_position.x + take.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) + caption_width * 0.5
		_check(absf(caption_center - title.get_global_rect().get_center().x) < 1.0, "take caption is centered independently of its word command")
		_check(not (choice.get_node("Content/ReadingArea/Reading") as ScrollContainer).get_v_scroll_bar().visible, "ordinary relic summary fits without scrolling")
	var footer_children := app.page.footer.get_children()
	var footer_center := ((footer_children[0] as Control).get_global_rect().position.x + (footer_children[-1] as Control).get_global_rect().end.x) * 0.5
	_check(absf(footer_center - app.page.heading.get_global_rect().get_center().x) < 1.0, "reward heading and footer actions share the page center")
	var companion := app.page.body.get_node("CurrentBuild") as Control
	_check(companion.size.x >= choices.size.x - 1.0 and companion.size.y < 90.0, "build status uses a compact full-width row")
	await _capture("reward-centered")
	await _key(KEY_RIGHT)
	_check(app.menu_navigation.selected_word() == "take2" and (choices.get_child(1) as RelicRewardChoice).keyboard_selected and not first.keyboard_selected, "reward arrow moves the entire card highlight")
	await _type("ta")
	await _key(KEY_SPACE)
	_check(app.run.rewards.spent == 0 and app.router.buffer == "ta", "partial word blocks shortcut confirmation")
	await _key(KEY_ESCAPE)
	await _key(KEY_RIGHT)
	var take_rect := (choices.get_child(1).find_child("Take*", true, false) as Control).get_global_rect()
	await _alt(true)
	_check((choices.get_child(1).find_child("Take*", true, false) as Control).get_global_rect() == take_rect, "Alt detail keeps take positions fixed")
	await create_timer(0.3).timeout
	await _capture("reward-centered-alt")
	await _alt(false)
	app._show_reward_detail(app.run.compiler.catalog.get_definition(&"G001"))
	await _key(KEY_1)
	_check(app.run.rewards.spent == 0, "detail modal blocks underlying numeric reward")
	await _key(KEY_ENTER)
	_check(not app.page.has_node("RewardDetail") and app.run.rewards.spent == 0, "Enter closes details without taking a relic")
	await _key(KEY_ENTER)
	_check(app.run.rewards.spent == 1 and app.run.compiler.compile(app.run.selection).build.asset_stacks(&"G002") == 1, "Enter commits the selected reward once")
	var next_id := StringName(app.run.offer.candidates[0])
	var previous_count := app.run.compiler.compile(app.run.selection).build.asset_stacks(next_id)
	await _key(KEY_KP_1)
	_check(app.run.rewards.spent == 2 and app.run.compiler.compile(app.run.selection).build.asset_stacks(next_id) == previous_count + 1, "keypad number commits the same reward transaction")
	app.run.offer = {"id": "ui-layout-long", "candidates": ["F026", "F007", "G027"]}
	app.run.selection.instances.clear()
	app.run.selection.book_id = &"frost"
	app.run.selection.assets = {&"F003": 1, &"F007": 1}
	app._show_run_stage(false)
	await _settle()
	await _alt(true)
	await create_timer(0.3).timeout
	await _capture("reward-detailed-awakening")
	await _alt(false)
	# A dense inventory stays bounded; its full contents are one named action away.
	for id in app.run.compiler.catalog.relic_ids():
		var definition := app.run.compiler.catalog.get_definition(StringName(id)) as RelicDefinition
		if definition.allowed_books.is_empty() and definition.requires_all.is_empty() and definition.required_stacks.is_empty() and definition.requires_capabilities.is_empty() and definition.exclusive_group == &"":
			app.run.selection.assets[StringName(id)] = 1
	app._show_run_stage(false)
	await _settle()
	_check((app.page.body.get_node("CurrentBuild") as Control).size.y < 90.0, "large relic inventory does not stretch the page or add its own scrolling")
	await _capture("reward-many-owned")
	app._relics_page()
	await create_timer(0.6).timeout
	await _type("relic010")
	var selected_glyph := app.page.body.find_children("*", "RelicGlyph", true, false)[0] as RelicGlyph
	_check(app.router.buffer.is_empty() and selected_glyph.definition.id == StringName(app.run.compiler.catalog.relic_ids()[9]), "long-list word reaches its exact entry without early prefix submission")
	await _type("search")
	var search := root.gui_get_focus_owner() as LineEdit
	_check(search != null, "codex search has its own word command")
	search.text = "练字"
	search.text_changed.emit(search.text)
	await _key(KEY_ESCAPE)
	await _key(KEY_DOWN)
	_check(not app.menu_navigation.selected_word().is_empty() and app.menu_navigation.selected.is_visible_in_tree(), "filtered catalog navigation selects a visible target")
	await _capture("menu-codex")
	app.run = null
	app.profile.run_checkpoint.clear()
	app._home(false)
	app._start_practice()
	await _settle()
	await _key(KEY_ESCAPE)
	_check(app.route == "pause" and paused, "practice Escape opens paused menu")
	await _capture("menu-pause")
	await _type("help")
	await create_timer(0.5, true).timeout
	_check(app.route == "guide" and app.menu_navigation.selected_word() == "back", "paused asynchronous guide selects a usable return action")
	await _key(KEY_ENTER)
	_check(app.route == "pause", "guide confirmation returns to the paused page")
	await _key(KEY_SPACE)
	_check(app.route == "practice" and not paused and app.router.context == InputRouter.Context.TYPING, "Space resumes and restores combat key ownership")
	app._home(false)
	app._first_setup_page()
	await create_timer(0.5).timeout
	_check(app.commands.has("translation") and app.commands.has("effects") and app.commands.has("volume"), "calibration controls retain their own commands")
	await _capture("menu-calibration")
	await _key(KEY_SPACE)
	_check(app.route == "tutorial" and app.settings.first_setup_complete, "calibration primary saves before entering tutorial selection")
	var report := FileAccess.open(evidence.path_join("menu-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("Menu layout checks: %d passed, %d failed | %s" % [checks.size() - failures, failures, evidence])
	app.queue_free()
	await process_frame
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
	_check(await app.run.begin(&"frost", app.settings), "isolated UI run starts")
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
	var button := first.find_child("Take*", true, false) as Button
	var button_rect := button.get_global_rect()
	await _capture("relic-summary")
	await _alt(true)
	_check(first.detail_mode and second.detail_mode and third.detail_mode, "physical Alt opens all card details")
	_check((second.get_node("Content/ReadingArea/Reading/Description") as Label).text.contains("取得后 · 2层"), "owned relic preview shows actual next layer")
	_check(first.get_global_rect() == original_rect and button.get_global_rect() == button_rect, "Alt keeps card and action positions fixed")
	await _capture("relic-alt")
	await _alt(false)
	_check(not first.detail_mode and not third.detail_mode, "releasing Alt restores summaries")
	var prose := second.get_node("Content/ReadingArea/Reading/Description") as Label
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
	await _click(first.find_child("Take*", true, false))
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
	if "--popup-style" in OS.get_cmdline_user_args():
		for index in menu.item_count - 1:
			await _key(KEY_DOWN)
		_check(menu.get_focused_item() == menu.item_count - 1, "long native menu reaches its final entry")
		await _capture("resolution-options-end")
	await _key(KEY_ESCAPE)
	if "--popup-style" in OS.get_cmdline_user_args():
		await _review_popup_style()
		return
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


func _review_popup_style() -> void:
	await _type("visuals")
	await _settle()
	await _type("effects")
	await create_timer(0.25).timeout
	var menu := (app.settings_controls["quality"] as OptionButton).get_popup()
	_check(menu.visible, "short native menu opens")
	_check(menu.use_hdr_2d == root.use_hdr_2d, "popup and glossary use the same color space")
	await _capture("quality-options")
	var hover := InputEventMouseMotion.new()
	var row_height := menu.get_theme_font("font").get_height(menu.get_theme_font_size("font_size")) + menu.get_theme_constant("v_separation")
	hover.position = Vector2(menu.position) + Vector2(menu.size.x * 0.6, menu.get_theme_stylebox("panel").get_margin(SIDE_TOP) + row_height * 1.5)
	# PopupMenu ignores synthetic stationary motion, unlike ordinary Controls.
	hover.relative = Vector2(2, 2)
	hover.velocity = Vector2(120, 120)
	Input.parse_input_event(hover)
	await _settle()
	_check(menu.get_focused_item() == 1, "pointer highlights the native middle row")
	await _capture("quality-hover")
	await _key(KEY_ENTER)
	_check(not menu.visible and app.settings.quality == 1, "native selection commits and closes")
	app._guide()
	await _settle()
	app.commands["note-04"].call()
	await _settle()
	app.page.scroll.scroll_vertical = 0
	await _settle()
	var prose: Label
	for label: Label in app.page.body.find_children("*", "Label", true, false):
		if label.text.contains("起手迎击"):
			prose = label
			break
	_check(prose != null, "guide supplies a real glossary term")
	if prose != null:
		var bounds := prose.get_character_bounds(prose.text.find("完美御术"))
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_screen_transform() * prose.get_global_transform() * bounds.get_center()
		Input.parse_input_event(motion)
		await create_timer(0.4).timeout
		var bubble := app.term_tooltips._bubble
		_check(bubble.visible and app.term_tooltips._title.text == "完美御术", "pointer opens the styled glossary")
		_check(bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE, "glossary does not intercept input")
		_check(Rect2(Vector2.ZERO, app.term_tooltips.size).encloses(bubble.get_rect()), "glossary stays within the reading viewport")
		await _capture("term-tooltip")
		await _move_to(app.page.heading)
		_check(not bubble.visible, "leaving the term dismisses the glossary")
	var report := FileAccess.open(evidence.path_join("popup-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("Popup style review: %d passed, %d failed | %s" % [checks.size() - failures, failures, evidence])
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
	if "--setup-invitation" in OS.get_cmdline_user_args():
		await _review_setup_invitation(setup)
		return
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
		_check(app.route == "tutorial" and app.settings.first_setup_complete and centered_pressure.get_ref() == null, "centered save action opens tutorial selection and frees its pressure scene")
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
	_check(app.route == "tutorial" and app.settings.first_setup_complete and pressure_ref.get_ref() == null, "confirm saves calibration, opens tutorial selection and frees the pressure scene")
	await _click(app.page.footer.get_node("Back"))
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


func _review_setup_invitation(setup: FirstVisitSetup) -> void:
	var pressure_ref: WeakRef = weakref(setup.preview)
	await _click(setup.confirm_button)
	await _settle()
	_check(app.route == "tutorial" and app.settings.first_setup_complete and pressure_ref.get_ref() == null, "first save enters tutorial selection and releases the pressure encounter")
	_check(app.menu_navigation.selected_word() == "basics" and app.router.context == InputRouter.Context.MENU, "basics is the first tutorial primary action")
	var menu := app.page as TutorialMenu
	_check(menu.lesson_buttons[&"frost"].disabled and not app.commands.has("frost"), "book practice requires completing basics")
	_check(Rect2(Vector2.ZERO, app.page.size).encloses(app.page.panel.get_rect()), "tutorial selection stays inside the desktop output")
	await _capture("first-tutorial-selection")
	var restored := AppSettings.new(app.settings.path)
	restored.load_settings()
	_check(restored.first_setup_complete, "setup completion is persisted before tutorial selection")
	await _click((app.page as TutorialMenu).lesson_buttons[&"basics"])
	await create_timer(1.0).timeout
	_check(app.route == "battle" and app.tutorial.lesson_id == &"basics", "new player enters the real basic practice through its entrance")
	await _click(app.tutorial_overlay.exit_button)
	await _settle()
	app._home(false)
	app.settings.first_setup_complete = false
	app._first_setup_page()
	await _settle()
	await _click((app.page as FirstVisitSetup).confirm_button)
	await _settle()
	await _click(app.page.footer.get_node("Back"))
	await _settle()
	_check(app.route == "home" and app.commands.has("tutorial"), "leaving tutorial selection retains its archive entry and book locks")
	app._first_setup_page()
	await _settle()
	await _click((app.page as FirstVisitSetup).confirm_button)
	await _settle()
	_check(app.route == "home", "repeated calibration does not force tutorial selection again")
	app._settings_page("home")
	app._first_setup_page("settings")
	await _settle()
	await _click((app.page as FirstVisitSetup).confirm_button)
	await _settle()
	_check(app.route == "settings", "recalibration returns to settings")
	var output := FileAccess.open(evidence.path_join("setup-invitation-checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Setup invitation: %d checks, %d failed | %s" % [checks.size(), failures, evidence])
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


func _review_tutorial_arc() -> void:
	var saved_characters := app.profile.manual_characters
	var saved_checkpoint := app.profile.run_checkpoint.duplicate(true)
	await _click(app.archive.right_menu.get_node("Tutorial"))
	_check(app.route == "tutorial" and app.page is TutorialMenu, "home tutorial button opens five lessons")
	var menu := app.page as TutorialMenu
	_check(menu.lesson_buttons.size() == 5, "basic and four book lessons have visible entrances")
	await _capture("tutorial-menu")
	await _click(menu.lesson_buttons[&"basics"])
	_check(app.route == "battle" and app.tutorial != null and not app.tutorial.session.god_mode, "native lesson button starts a real isolated combat session")
	_check(app.router.typing == app.tutorial.session.typing and app.battle.word_exclusions.size() == 1, "lesson uses combat input and reserves its guidance area")
	await _capture("tutorial-basics")
	await _click(app.battle.pause_button)
	_check(paused and app.route == "pause" and app.page.footer.get_child_count() == 2, "tutorial pause offers resume and return without expedition settlement")
	await _type("resume")
	_check(not paused and app.route == "battle", "resume restores tutorial input")
	var old_session := app.tutorial.session
	await _click(app.tutorial_overlay.retry_button)
	_check(app.tutorial.session != old_session and app.tutorial.step_index == 0, "retry creates fresh tutorial state")
	await _click(app.tutorial_overlay.exit_button)
	_check(app.route == "tutorial" and app.tutorial == null, "exit returns to lesson selection")
	for id: StringName in [&"frost", &"flame", &"storm", &"spirit"]:
		menu = app.page as TutorialMenu
		await _click(menu.lesson_buttons[id])
		_check(app.tutorial.book_id == id and app.battle.school_color == app.tutorial_overlay._accent, "book lesson uses its real rules and matching appearance: %s" % id)
		await _capture("tutorial-" + str(id))
		if id == &"flame":
			await _exercise_flame_mechanisms()
		await _click(app.tutorial_overlay.exit_button)
	_check(app.profile.manual_characters == saved_characters and app.profile.run_checkpoint == saved_checkpoint, "tutorial navigation never changes profile growth or expedition checkpoint")
	app._relics_page()
	await create_timer(0.3).timeout
	var sample := PageShell.label(app.page.body, "寒气增加 25%，冻结持续 1.25 秒。", 21)
	await _settle()
	var decorated := sample.get_node("ProseDecoration") as ProseDecoration
	_check(decorated._rich.visible and decorated._rich.get_parsed_text() == sample.text, "number coloring preserves the original plain text")
	_check(decorated._rich.get_line_count() == sample.get_line_count(), "color spans preserve label wrapping")
	_check(decorated._terms.size() == 2 and sample.self_modulate.a == 0.0, "hoverable terms carry dashed markings and only one text layer draws")
	app.page.scroll.scroll_vertical = int(app.page.scroll.get_v_scroll_bar().max_value)
	await _settle()
	var term_rect := sample.get_character_bounds(0)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_screen_transform() * sample.get_global_transform() * term_rect.get_center()
	Input.parse_input_event(motion)
	await _settle()
	await create_timer(0.4).timeout
	_check(app.term_tooltips._bubble.visible and app.term_tooltips._title.text == "寒气", "dashed term still opens its explanation using shaped glyph bounds")
	await _capture("prose-values-and-terms")
	await _review_curved_frames()
	app._home(false)
	await _settle()
	var output := FileAccess.open(evidence.path_join("tutorial-arc-checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Tutorial/arc UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
	quit(1 if failures else 0)


func _review_tutorial_mechanics() -> void:
	var saved := app.profile.to_dict()
	app._tutorial_menu()
	await _settle()
	await _capture("mechanism-menu")
	# Observe the actual short handover, with game input held until reveal.
	app.settings.reduce_motion = false
	app._start_tutorial(&"spirit")
	var entrance := app.practice_entrance
	_check(app.route == "practice_entry" and app.router.typing == null, "entrance holds typing before room handover")
	await entrance.covered
	await RenderingServer.frame_post_draw
	var rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	DisplayServer.screen_get_image_rect(rect).save_png(evidence.path_join("practice-covered.png"))
	_check(is_instance_valid(app.tutorial) and not app.tutorial.session.is_physics_processing(), "covered room remains paused until reveal")
	await entrance.completed
	await _settle()
	_check(app.route == "battle" and app.router.typing == app.tutorial.session.typing, "short reveal restores combat input")
	app._tutorial_menu()
	app.settings.reduce_motion = true
	for id: StringName in TutorialLesson.LESSON_IDS:
		app._start_tutorial(id)
		await _settle()
		app.tutorial.session.set_physics_process(false)
		var action_position := app.tutorial_overlay.next_button.global_position
		for index in app.tutorial.step_count():
			# Layout/wording review only. Actual progression is separately covered by rule tests.
			app.tutorial.step_index = index
			app.tutorial.refresh()
			await _settle()
			var overlay := app.tutorial_overlay
			var text := overlay._instruction
			_check(text.position.y + text.get_minimum_size().y < overlay._progress.position.y and overlay._progress.get_rect().end.y < overlay.get_node("Content/Actions").position.y, "%s/%s copy stays clear of goal and controls" % [id, app.tutorial.current_step()])
			_check(overlay.get_reserved_rect().end.y < app.battle.size.y - 130 and app.battle.word_exclusions[0] == overlay.get_reserved_rect(), "%s/%s reserves the full current guidance and stays above footer" % [id, app.tutorial.current_step()])
			_check(text.text.length() <= 140 and not text.text.contains("悬浮虚线术语") and not text.text.contains("未输入时 Tab"), "%s/%s stays concise without repeated global instructions" % [id, app.tutorial.current_step()])
			_check(overlay.next_button.global_position.is_equal_approx(action_position) and overlay.get_reserved_rect().end.y < BattleStage.arena_point(app.tutorial.session.player_position, app.battle.size).y - 70, "%s/%s keeps the primary control fixed and guidance above the demonstration" % [id, app.tutorial.current_step()])
			_check(not app.battle.wave_label.visible and not app.battle.timer_label.visible and not app.battle.get_node("BattleCompass").visible, "%s/%s omits expedition-only HUD from practice" % [id, app.tutorial.current_step()])
			if (id == &"frost" and app.tutorial.current_step() == &"freeze") or (id == &"flame" and app.tutorial.current_step() == &"burn") or (id == &"storm" and app.tutorial.current_step() == &"charge") or (id == &"spirit" and app.tutorial.current_step() == &"crane"):
				await _capture("mechanism-" + str(id))
			if id == &"spirit" and app.tutorial.current_step() == &"crane":
				var offset := text.text.find("符文纸鹤")
				var motion := InputEventMouseMotion.new()
				motion.position = root.get_screen_transform() * text.get_global_transform() * text.get_character_bounds(offset).get_center()
				Input.parse_input_event(motion)
				await create_timer(0.4).timeout
				_check(app.term_tooltips._bubble.visible and app.term_tooltips._title.text == "符文纸鹤", "native pointer opens paper crane details directly in the lesson")
				await _capture("mechanism-crane-tooltip")
		await _click(app.tutorial_overlay.retry_button)
		_check(app.tutorial.current_step() == &"ultimate" and app.route == "battle" and app.practice_entrance == null and not app.tutorial.ready_to_advance, "%s retry restores the current exercise without repeating the lesson or entry transition" % id)
		_check(app.tutorial.session.manual_characters == 0 and app.tutorial.session.resonance_q == BattleSession.ULTIMATE_COST_Q, "%s retry restores usable prerequisites without granting a successful action" % id)
		await _click(app.battle.pause_button)
		await _type("resume")
		_check(app.route == "battle" and not paused, "%s pause and resume restore lesson input" % id)
		var exit_control := app.tutorial_overlay.exit_button
		var exit_events: Array[String] = []
		exit_control.button_down.connect(func() -> void: exit_events.append("down"))
		exit_control.button_up.connect(func() -> void: exit_events.append("up"))
		exit_control.pressed.connect(func() -> void: exit_events.append("pressed"))
		await _click(exit_control)
		if app.route != "tutorial":
			print("Tutorial exit missed: ", id, " route=", app.route, " events=", exit_events, " hovered=", root.gui_get_hovered_control(), " mouse=", root.get_mouse_position(), " rect=", exit_control.get_global_rect())
			await _capture("exit-missed-" + str(id))
		_check(app.route == "tutorial" and app.tutorial == null, "%s exits without expedition settlement" % id)
	app._start_tutorial(&"flame")
	await _settle()
	await _exercise_flame_mechanisms()
	_check((app.page as TutorialMenu).lesson_buttons[&"flame"].text == "再练一次", "completed lesson can immediately be repeated from selection")
	await _click((app.page as TutorialMenu).lesson_buttons[&"flame"])
	_check(app.tutorial.step_index == 0 and not app.tutorial.completed, "repeat from the completion menu starts a fresh lesson")
	await _click(app.tutorial_overlay.exit_button)
	app._enter_tutorial(&"spirit", TutorialLesson.STEPS[&"spirit"].find(&"sleep"))
	await _settle()
	await _click(app.tutorial_overlay.retry_button)
	_check(app.tutorial.current_step() == &"sleep" and app.tutorial_overlay._progress.text.contains("先唤醒"), "native sleep retry starts with an actionable prompt for an empty flock")
	await _click(app.battle.enemy_words[app.tutorial.session.enemies[0].id])
	await _type(app.tutorial.session.typing.word)
	var awake := app.tutorial.session.spirit_blade_count()
	_check(awake > 0 and app.tutorial_overlay._progress.text.contains("停笔等待"), "manual input changes sleep guidance into the actual waiting phase")
	await _capture("mechanism-sleep-wait")
	var sleep_deadline := Time.get_ticks_msec() + 15000
	while app.tutorial.session.spirit_blade_count() >= awake and Time.get_ticks_msec() < sleep_deadline:
		await process_frame
	_check(not app.tutorial.ready_to_advance and app.tutorial_overlay._progress.text == "完成一个词咒，唤醒纸灵", "an actual spirit falling asleep changes the native prompt without an extra click")
	await _click(app.battle.enemy_words[app.tutorial.session.enemies[0].id])
	await _type(app.tutorial.session.typing.word)
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.exit_button)
	app._home(false)
	app._start_practice()
	await _settle()
	_check(app.route == "practice" and app.router.typing == app.practice.typing, "ordinary typing practice also uses the reduced entrance")
	_check(app.profile.to_dict() == saved, "lesson review, retry and typing practice leave the profile unchanged")
	var output := FileAccess.open(evidence.path_join("tutorial-mechanics-checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Tutorial mechanics UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
	quit(1 if failures else 0)


func _review_tutorial_shortcuts() -> void:
	# Readiness is staged here to isolate native button routing from combat rules.
	for id: StringName in TutorialLesson.LESSON_IDS:
		for index in TutorialLesson.STEPS[id].size():
			app._enter_tutorial(id, index)
			await _settle()
			app.tutorial.session.set_physics_process(false)
			await _key(KEY_ENTER)
			_check(app.tutorial.step_index == index and not app.tutorial.ready_to_advance and app.tutorial.session.typing.mistakes == 0, "%s/%d Enter cannot skip an unfinished goal or type a wrong character" % [id, index])
			var overlay := app.tutorial_overlay
			_check([overlay.next_button, overlay.retry_button, overlay.exit_button].all(func(button: OpenButton) -> bool: return button.get_rect().has_area() and button.get_global_rect().encloses((button.get_node("ShortcutHint") as Control).get_global_rect())), "%s/%d all shortcut hints fit inside their buttons" % [id, index])
			_check([overlay.next_button, overlay.retry_button, overlay.exit_button].all(func(button: OpenButton) -> bool: return is_equal_approx((button.get_node("ShortcutHint") as Control).position.x, 12.0) and is_equal_approx(button.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) - ((button.get_node("ShortcutHint/KeyFrame") as Control).get_global_rect().end.x - button.global_position.x), 8.0)), "%s/%d visible key caps lead their captions with an eight-pixel gap" % [id, index])
			app.tutorial.ready_to_advance = true
			app.tutorial.refresh()
			await _key(KEY_ENTER)
			_check(app.route == "tutorial" if index == TutorialLesson.STEPS[id].size() - 1 else app.tutorial.step_index == index + 1, "%s/%d Enter invokes exactly the available next or finish action" % [id, index])
		app._enter_tutorial(id, 1)
		await _settle()
		var previous := app.tutorial.session.get_instance_id()
		await _type(app.tutorial.session.enemies[0].word.left(1))
		await _key(KEY_F1)
		_check(app.tutorial.step_index == 1 and app.tutorial.session.get_instance_id() != previous and app.tutorial.session.manual_characters == 0, "%s F1 retries the current step and clears prior input" % id)
		await _key(KEY_F3)
		_check(app.route == "tutorial" and app.tutorial == null, "%s F3 exits to teaching selection" % id)
	app._enter_tutorial(&"basics")
	await _settle()
	await _type(app.tutorial.session.enemies[0].word)
	await _wait_tutorial_goal()
	await _key(KEY_KP_ENTER)
	_check(app.tutorial.current_step() == &"switch", "keypad Enter advances after a real manually completed goal")
	await _key(KEY_ESCAPE)
	await _key(KEY_F1)
	await _key(KEY_F3)
	_check(app.route == "pause" and app.tutorial.current_step() == &"switch", "paused lesson shortcuts do not activate hidden battle buttons")
	await _type("resume")
	var echo := InputEventKey.new()
	echo.keycode = KEY_F1
	echo.pressed = true
	echo.echo = true
	var session_id := app.tutorial.session.get_instance_id()
	Input.parse_input_event(echo)
	await _settle()
	_check(app.tutorial.session.get_instance_id() == session_id, "holding a shortcut does not repeatedly restart the step")
	app.settings.ui_scale = 1.25
	app.root.refresh()
	await _settle()
	await _capture("tutorial-shortcuts")
	await _key(KEY_F3)
	await _key(KEY_F1)
	await _key(KEY_F3)
	_check(app.route == "tutorial" and app.tutorial == null, "lesson shortcuts stop acting after exit")
	var output := FileAccess.open(evidence.path_join("tutorial-shortcuts-checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Tutorial shortcuts UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
	quit(1 if failures else 0)


func _review_tutorial_navigation() -> void:
	app.settings.completed_lessons.clear()
	app.settings.completed_steps.clear()
	app._start_tutorial(&"basics")
	await _settle()
	await _type(app.tutorial.session.enemies[0].word)
	await _wait_tutorial_goal()
	_check(app.settings.lesson_progress(&"basics") == 1 and not app.tutorial_overlay._step_buttons[1].disabled and app.tutorial_overlay._step_buttons[2].disabled, "a real achieved goal remembers one step and unlocks only the next node")
	await _key(KEY_F3)
	app._start_tutorial(&"basics")
	await _settle()
	_check(app.tutorial.step_index == 1, "reentering an incomplete course resumes at its first unfinished step")
	await _move_to(app.tutorial_overlay._step_buttons[3])
	_check(app.tutorial_overlay._step_name.visible and app.tutorial_overlay._step_name.text == "御术与反弹", "even a locked node reveals its step name on native hover")
	await _capture("tutorial-node-name")
	await _click(app.tutorial_overlay._step_buttons[3])
	app._jump_tutorial(4)
	_check(app.tutorial.step_index == 1, "neither pointer nor controller can skip unfinished steps")
	await _click(app.tutorial_overlay._step_buttons[0])
	_check(app.tutorial.step_index == 0 and app.tutorial.session.manual_characters == 0, "passed node opens a fresh replay of that step")
	await _click(app.tutorial_overlay._step_buttons[1])
	_check(app.tutorial.step_index == 1 and app.settings.lesson_progress(&"basics") == 1, "replaying an earlier step keeps access to the unfinished frontier")
	var restored := AppSettings.new(app.settings.path)
	restored.load_settings()
	_check(restored.lesson_progress(&"basics") == 1 and restored.completed_lessons.is_empty(), "partial tutorial progress survives disk reload without unlocking a book")
	app.queue_free()
	await _settle()
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = restored
	app.profile_base_path = evidence.path_join("profiles")
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	root.grab_focus()
	app._start_tutorial(&"basics")
	await _settle()
	_check(app.tutorial.step_index == 1 and not app.tutorial_overlay._step_buttons[0].disabled, "recreated application restores both resume position and passed-node navigation")
	app.settings.completed_lessons.assign([&"basics"])
	# Stage an already dissolved target, then use the real step transition and dodge.
	for id: StringName in [&"frost", &"flame", &"storm", &"spirit"]:
		var previous_step := 1 if id == &"storm" else 2
		app._enter_tutorial(id, previous_step)
		await _settle()
		var session := app.tutorial.session
		session.set_physics_process(false)
		session.enemies[0].hp_q = 0
		await create_timer(0.7).timeout
		var actor := app.battle.visuals._actors[session.enemies[0].id]
		_check(actor.dead_time > 0.9, "%s fixture reaches a visibly dissolved prior target" % id)
		app.tutorial.ready_to_advance = true
		app.tutorial.refresh()
		await _key(KEY_ENTER)
		await _settle()
		_check(session.enemies[0].alive() and actor.dead_time == 0.0 and actor.modulate.a > 0.9 and is_zero_approx(float(actor.surface.get_shader_parameter("dissolve"))), "%s dodge lesson restores the actual target and clears its death presentation" % id)
		session.set_physics_process(true)
		if id == &"spirit":
			var deadline := Time.get_ticks_msec() + 15000
			while not (session.enemies[0].aiming and session.enemies[0].attack_clock <= 0.3) and Time.get_ticks_msec() < deadline:
				await process_frame
			await _key(KEY_DOWN)
		else:
			await _key(KEY_RIGHT if id == &"storm" else KEY_LEFT)
		await _wait_tutorial_goal()
		_check(app.tutorial.ready_to_advance, "%s restored target supports its real dodge mechanic" % id)
		if id == &"frost": await _capture("frost-dodge-restored-target")
	app._home(false)
	app._select_archive_book(3)
	await create_timer(ArchiveHome.ACCENT_SECONDS + 0.1).timeout
	await _settle()
	var home := app.archive
	_check(home.auras.all(func(aura: ColorRect) -> bool: return not aura.visible) and home.patterns.all(func(pattern: TextureRect) -> bool: return not pattern.visible) and float((home.artworks[3].material as ShaderMaterial).get_shader_parameter("awakening")) == 0.0, "uncompleted books retain their silhouettes with no aura or rune light")
	await _capture("archive-book-locked")
	app.settings.completed_lessons.append(&"flame")
	app._home(false)
	app._select_archive_book(3)
	await create_timer(ArchiveHome.ACCENT_SECONDS + 0.1).timeout
	await _settle()
	_check(home.auras[3].visible and not home.auras[0].visible and float((home.artworks[3].material as ShaderMaterial).get_shader_parameter("awakening")) == 1.0, "only the completed book regains color and light")
	await _capture("archive-book-unlocked")
	var output := FileAccess.open(evidence.path_join("tutorial-navigation-checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Tutorial navigation UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
	quit(1 if failures else 0)


func _wait_tutorial_goal() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while not app.tutorial.ready_to_advance and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(app.tutorial.ready_to_advance and not app.tutorial_overlay.next_button.disabled, "actual %s effect enables the next-step control" % app.tutorial.current_step())


func _exercise_flame_mechanisms() -> void:
	for cast in 3:
		await create_timer(0.7).timeout
		await _click(app.battle.enemy_words[app.tutorial.session.enemies[0].id])
		await _type(app.tutorial.session.typing.word)
	await _wait_tutorial_goal()
	_check(app.tutorial.current_step() == &"intro", "achieved empowerment preserves its explanation until explicit Next")
	await _click(app.tutorial_overlay.next_button)
	_check(app.tutorial.current_step() == &"block", "native Next opens the blocking exercise")
	await _click(app.battle.enemy_words[app.tutorial.session.enemies[2].id])
	await _type(app.tutorial.session.typing.word)
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	await _click(app.tutorial_overlay.retry_button)
	_check(app.tutorial.current_step() == &"burn" and app.tutorial_overlay._progress.text.contains("点燃"), "retrying burn keeps the current step and asks to ignite the fresh target")
	await _click(app.battle.enemy_words[app.tutorial.session.enemies[0].id])
	await _type(app.tutorial.session.typing.word)
	await _wait_tutorial_goal()
	await _capture("mechanism-burn-achieved")
	await _click(app.tutorial_overlay.next_button)
	await _key(KEY_LEFT)
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	await _key(KEY_SHIFT)
	await _wait_tutorial_goal()
	_check(not app.tutorial.completed and app.tutorial_overlay.next_button.text == "完成并返回", "real ultimate results remain readable until one explicit finish action")
	await _capture("mechanism-flame-achieved")
	await _click(app.tutorial_overlay.next_button)
	_check(app.route == "tutorial" and app.tutorial == null and &"flame" in app.settings.completed_lessons, "one native finish returns to selection with the completed course marked")
	await _capture("mechanism-flame-complete")


func _review_teaching_copy() -> void:
	await app._guide()
	await _settle()
	var grid := app.page.body.get_child(0) as GridContainer
	var target_body := grid.get_child(5).get_child(0).get_child(3) as Label
	_check(target_body.get_line_count() > 3 and target_body.get_minimum_size().y <= target_body.size.y, "detailed target guide wraps within its native article")
	app.page.scroll.scroll_vertical = maxi(0, int(grid.get_child(5).position.y) - 120)
	await _settle()
	await _capture("target-switch-guide")
	app._tutorial_menu()
	app._start_tutorial(&"basics")
	await _settle()
	await _click(app.battle.enemy_words[app.tutorial.session.enemies[0].id])
	await _type(app.tutorial.session.typing.word)
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	_check(app.tutorial.current_step() == &"switch" and app.tutorial.session.typing.word == "shade", "basic course stages the actual shade/shard/flame example")
	await _capture("target-switch-before-input")
	await _key(KEY_TAB)
	_check(app.tutorial._switch_phase == 1 and app.tutorial.session.typing.word == "shard", "native Tab reveals the shared-opening instruction without a click or timer")
	await _type("sha")
	_check(app.tutorial_overlay._progress.text == "按 Tab，保留 sha 换目标", "action prompt responds to completed shared letters instead of asking to type them again")
	await _key(KEY_TAB)
	await _wait_tutorial_goal()
	_check(app.tutorial.session.typing.word == "shade" and app.tutorial.session.typing.progress == 3, "native shared-opening switch keeps sha")
	await _capture("target-switch-shared-opening")
	await _click(app.tutorial_overlay.next_button)
	await _key(KEY_TAB)
	_check(not app.tutorial.ready_to_advance and app.tutorial.session.typing.word != "flame", "Tab alone cannot choose the different-opening example")
	await _key(KEY_BACKSPACE)
	await _type("f")
	await _wait_tutorial_goal()
	_check(app.tutorial.session.typing.word == "flame", "native cancellation and new first letter choose flame")
	await _capture("target-switch-new-opening")
	# Stage movement for layout review; the rule suite owns prerequisite progression.
	app.tutorial.step_index = TutorialLesson.STEPS[&"basics"].find(&"dodge")
	app.tutorial.ready_to_advance = false
	app.tutorial._seen.clear()
	app.tutorial._configure_step()
	app.tutorial.refresh()
	await _key(KEY_UP)
	await create_timer(0.3).timeout
	var player_point := BattleStage.arena_point(app.tutorial.session.player_position, app.battle.size)
	_check(app.tutorial_overlay._at_bottom and not app.tutorial_overlay.get_reserved_rect().grow(60).has_point(player_point), "upward dodge moves the reading area away from the player")
	_check(app.battle.word_exclusions[0] == app.tutorial_overlay.get_reserved_rect(), "words immediately reserve the relocated guidance")
	await _capture("tutorial-dodge-clearance")
	await _click(app.tutorial_overlay.next_button)
	_check(app.tutorial.current_step() == &"ultimate" and not app.tutorial_overlay._at_bottom, "next staged mechanic restores the normal reading position")
	app.settings.ui_scale = 1.25
	app.root.refresh()
	await _settle()
	_check(app.tutorial_overlay.get_reserved_rect().end.y < BattleStage.arena_point(app.tutorial.session.player_position, app.battle.size).y - 60, "largest desktop UI scale keeps instructions above the practice scene")
	await _capture("tutorial-large-ui")
	await _key(KEY_UP)
	await create_timer(0.3).timeout
	player_point = BattleStage.arena_point(app.tutorial.session.player_position, app.battle.size)
	_check(app.tutorial_overlay._at_bottom and not app.tutorial_overlay.get_reserved_rect().grow(60).has_point(player_point), "largest UI scale also clears an upward dodge without bouncing the guidance back")
	_check(app.tutorial.session.enemies.all(func(enemy: BattleEnemy) -> bool: return not app.tutorial_overlay.get_reserved_rect().grow(40).has_point(BattleStage.arena_point(enemy.position, app.battle.size))), "relocated guidance also leaves the enemy demonstration clear at the largest UI scale")
	await _capture("tutorial-large-ui-dodge")
	app.settings.ui_scale = 1.0
	app.root.refresh()
	app._tutorial_menu()
	for id: StringName in TutorialLesson.LESSON_IDS:
		root.grab_focus()
		app._start_tutorial(id)
		await _settle()
		var overlay := app.tutorial_overlay
		var instruction := overlay._instruction
		var rendered_bottom := instruction.position.y + instruction.get_minimum_size().y
		_check(rendered_bottom < overlay._progress.position.y and overlay._progress.get_rect().end.y < overlay.get_node("Content/Actions").position.y, "%s short instructions stay clear of progress and buttons" % id)
		_check(not instruction.text.contains("Tab") and instruction.text.length() < 100, "%s opening contains only its immediate mechanism" % id)
		_check(overlay.get_reserved_rect().end.y < app.battle.size.y - 130.0, "%s expanded guidance remains clear of the combat footer" % id)
		if id == &"basics": await _capture("target-switch-tutorial")
		if id == &"frost":
			app.tutorial.step_index = TutorialLesson.STEPS[id].find(&"freeze")
			app.tutorial.refresh()
			await _settle()
			await _capture("frost-retention-tutorial")
		app._tutorial_menu()
	var output := FileAccess.open(evidence.path_join("teaching-copy-checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Teaching copy UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
	quit(1 if failures else 0)


func _review_archive_tutorial() -> void:
	root.grab_focus()
	await _settle()
	var home := app.archive
	_check(home.menu_buttons.size() == 8 and home.menu.get_child_count() == 4 and home.right_menu.get_child_count() == 4, "archive distributes its eight real menu actions between both sides")
	_check(home.menu.get_rect().end.x < home.size.x * 0.3 and home.right_menu.position.x > home.size.x * 0.7, "menu columns leave the book composition clear")
	_check(absf(home.archive_label.get_rect().get_center().x - home.size.x * 0.5) < 1 and home.counter.get_rect().get_center().x == home.archive_label.get_rect().get_center().x, "archive heading and book counter align above the selected book")
	_check(absf(home.size.x - home.bottom_hint.get_rect().end.x - 32) < 1 and absf(home.size.y - home.bottom_hint.get_rect().end.y - 12) < 1 and not home.bottom_hint.get_rect().intersects(home.command_label.get_rect()), "keyboard hints anchor to the actual bottom-right corner with clear word-command space")
	app._select_archive_book(3)
	await create_timer(ArchiveHome.ACCENT_SECONDS + 0.1).timeout
	await _settle()
	_check(home.caption.position.y > home.book_titles[3].get_rect().end.y + 8 and home.caption.get_rect().end.y < home.prepare_button.position.y - 25, "book introduction has clear spacing from title and primary action: title=%s caption=%s action=%s" % [home.book_titles[3].get_rect(), home.caption.get_rect(), home.prepare_button.get_rect()])
	await _capture("archive-flame-locked")
	app.settings.ui_scale = 1.25
	app._apply_visual_settings()
	await _settle()
	_check(home.caption.get_rect().end.y < home.prepare_button.position.y - 25 and home.counter.get_rect().end.y < home.cards[3].position.y, "largest desktop UI scale keeps book copy and heading clear of the artwork and action")
	await _capture("archive-large-ui")
	app.settings.ui_scale = 1.0
	app._apply_visual_settings()
	await _settle()
	await _key(KEY_ENTER)
	_check(app.route == "tutorial" and not app.run.has_pending_run(), "locked book primary enters teaching without creating an expedition")
	await _key(KEY_ESCAPE)
	app._first_setup_page()
	await _settle()
	var preview_ref: WeakRef = weakref((app.page as FirstVisitSetup).preview)
	await _click((app.page as FirstVisitSetup).confirm_button)
	_check(app.route == "tutorial" and app.settings.first_setup_complete and preview_ref.get_ref() == null, "first setup saves directly into tutorial selection and releases the preview")
	var menu := app.page as TutorialMenu
	_check(not menu.lesson_buttons[&"basics"].disabled and menu.lesson_buttons.values().filter(func(button: OpenButton) -> bool: return not button.disabled).size() == 1, "initially only basic controls practice is available")
	_check(not app.commands.has("flame") and not app.commands.has("spirit"), "locked lesson word commands are absent")
	await _click(menu.lesson_buttons[&"flame"])
	app._start_tutorial(&"spirit")
	_check(app.route == "tutorial" and app.tutorial == null, "locked lessons reject both pointer and direct controller requests")
	await _capture("tutorial-basics-only")
	await _click(menu.lesson_buttons[&"basics"])
	app._advance_tutorial()
	_check(app.settings.completed_lessons.is_empty(), "entering or prematurely advancing a lesson grants no unlock")
	await _click(app.tutorial_overlay.exit_button)
	_check(app.settings.completed_lessons.is_empty(), "abandoning practice grants no unlock")
	await _click((app.page as TutorialMenu).lesson_buttons[&"basics"])
	await _click(app.battle.enemy_words[app.tutorial.session.enemies[0].id])
	await _type(app.tutorial.session.typing.word)
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	await _key(KEY_TAB)
	await _type("sha")
	await _key(KEY_TAB)
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	await _key(KEY_BACKSPACE)
	await _type("f")
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	var parry_deadline := Time.get_ticks_msec() + 15000
	while not app.tutorial.ready_to_advance and Time.get_ticks_msec() < parry_deadline:
		var session := app.tutorial.session
		for threat: BattleThreat in session.threats:
			if not threat.reflected and ((threat.position - session.player_position) * BattleSession.ARENA_SIZE).length() < 40 and session.parry_cooldown <= 0:
				await _key(KEY_SPACE)
				break
		await process_frame
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	await _key(KEY_LEFT)
	await _wait_tutorial_goal()
	await _click(app.tutorial_overlay.next_button)
	await _key(KEY_SHIFT)
	await _wait_tutorial_goal()
	# Saving is part of completion; a failed write must remain retryable.
	var settings_path := app.settings.path
	app.settings.path = evidence.path_join("blocked-settings")
	DirAccess.make_dir_absolute(app.settings.path)
	await _click(app.tutorial_overlay.next_button)
	_check(app.tutorial != null and not app.tutorial.completed and app.settings.completed_lessons.is_empty() and not app.tutorial_overlay.next_button.disabled, "failed completion save preserves the achieved goal without granting an unlock")
	app.settings.path = settings_path
	await _click(app.tutorial_overlay.next_button)
	menu = app.page as TutorialMenu
	_check(app.settings.completed_lessons == [&"basics"] and menu.lesson_buttons.values().all(func(button: OpenButton) -> bool: return not button.disabled), "real basic completion opens all four independent book lessons")
	_check(not app.settings.book_unlocked(&"frost") and not app.settings.book_unlocked(&"flame"), "basic completion alone unlocks no official book")
	await _capture("tutorial-choose-any-book")
	# Pick flame first: frost is deliberately incomplete.
	await _click(menu.lesson_buttons[&"flame"])
	await _exercise_flame_mechanisms()
	_check(app.settings.book_unlocked(&"flame") and not app.settings.book_unlocked(&"frost") and not app.settings.book_unlocked(&"spirit"), "finishing flame first unlocks flame alone without requiring the other books")
	var restored := AppSettings.new(settings_path)
	restored.load_settings()
	_check(restored.completed_lessons == app.settings.completed_lessons, "real completed lessons survive a settings reload")
	app.queue_free()
	await _settle()
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = restored
	app.settings_prepared = true
	app.presentation_enabled = false
	app.profile_base_path = evidence.path_join("profiles")
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	root.add_child(app)
	await _settle()
	_check(app.settings.book_unlocked(&"flame") and not app.settings.book_unlocked(&"frost"), "a fresh app instance retains only the completed book unlock")
	app.archive.select_book(0, false)
	app._launch_prepared()
	_check(app.route == "tutorial" and not app.run.has_pending_run(), "official controller launch cannot bypass an uncompleted book")
	app._home(false)
	app._select_archive_book(3)
	await create_timer(ArchiveHome.ACCENT_SECONDS + 0.1).timeout
	await _capture("archive-flame-unlocked")
	await _key(KEY_ENTER)
	_check(app.route == "prepare", "the single completed book can enter official preparation")
	await _capture("archive-preparation")
	await _key(KEY_ENTER)
	while is_instance_valid(app.departure): await process_frame
	_check(app.route == "battle" and app.tutorial == null and app.run.selection.book_id == &"flame", "one completed book enters a real expedition without all-book completion")
	app.battle.session.set_physics_process(false)
	app.settings.completed_lessons.erase(&"flame")
	app._pause()
	var checkpoint := app.profile.run_checkpoint.duplicate(true)
	app._resume_run()
	_check(app.route == "tutorial" and app.profile.run_checkpoint == checkpoint and app.run.has_pending_run(), "a locked resumed book opens teaching while preserving the pending expedition")
	var output := FileAccess.open(evidence.path_join("archive-tutorial-checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	output.close()
	print("Archive and tutorial UI: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _review_combat_revision() -> void:
	root.grab_focus()
	app.settings.reduce_motion = false
	app.settings.run_seed = "combat-revision"
	app.settings.progressive = false
	app._start_battle()
	var entry := app.departure
	await entry.covered
	while not is_instance_valid(app.battle) or not entry.ready_to_reveal:
		await process_frame
	entry.set_process(false)
	_check(entry.chapter_entry and entry.get_node("Book").text == "第 1 章 · 第 1 页", "chapter entrance prominently names its actual chapter and page")
	await _capture("chapter-entrance")
	entry.set_process(true)
	await entry.completed
	app.battle.session.set_physics_process(false)
	var session := app.battle.session
	var styles: Array[StringName] = [&"needle", &"quill", &"refrain", &"wisp", &"rune", &"vortex", &"shard", &"heavy", &"orb"]
	for row in 2:
		for index in styles.size():
			var shot := BattleThreat.new()
			shot.attack_id = "display-%d-%d" % [row, index]
			shot.visual_style = styles[index]
			shot.heavy = styles[index] == &"heavy"
			shot.radius = 9.0
			shot.position = Vector2(0.17 + index * 0.075, 0.34 + row * 0.2)
			shot.previous_position = shot.position
			shot.velocity = Vector2(140, 25)
			shot.reflected = row == 1
			for tail in 20: shot.trail.append(shot.position - Vector2(20 - tail, 0) * 6.0 / BattleSession.ARENA_SIZE)
			session.threats.append(shot)
	for index in 2:
		var kind: StringName = &"frost_spear" if index == 0 else &"flame_burst"
		var lot := session.ledger.earn("display-player-%d" % index, kind, session.compiled_build.identity(), SpellLot.Kind.POWER, BattleSession.Q, &"fixture")
		var effect := session.runtime._effect(lot, kind, session.enemies[0].id, Vector2(0.4 + index * 0.2, 0.7), session.compiled_build)
		var shot := BattleProjectile.new(effect)
		shot.velocity = Vector2.RIGHT * shot.speed
		for tail in 20: shot.trail.append(shot.position - Vector2(20 - tail, 0) * 6.0 / BattleSession.ARENA_SIZE)
		session.projectiles.append(shot)
	await _settle()
	await _capture("projectile-heads-high")
	app.settings.quality = 0
	app.settings.reduce_motion = true
	app.battle.apply_options()
	await _capture("projectile-heads-low-reduced")
	session.threats.clear()
	app.run.rewards.current = app.run.rewards.next_threshold - 1
	var target := session.enemies[0]
	target.position = Vector2(0.5, 0.4)
	target.previous_position = target.position
	target.combat_locked = true
	session.commit_damage(target, target.hp_q, target.hp_q, &"fixture", session.player_position)
	var reward_started := Time.get_ticks_usec()
	app._progression_changed()
	_check(app.route == "reward_wait" and app.run.phase == "BATTLE_REWARD" and not session.is_physics_processing(), "earned reward stops combat before its presentation delay")
	while app.route == "reward_wait":
		await process_frame
	_check(Time.get_ticks_usec() - reward_started >= 200000, "reward waits at least 0.2 real seconds, including frames with expensive work")
	_check(app.route == "reward" and app.battle.visuals._actors[target.id].dead_time > 0.3, "reward appears after 0.2 seconds while the defeated actor dissolves")
	await _capture("delayed-reward")
	app._home()
	app.archive.set_prepared(true, false)
	app._pending_run_page(false)
	await _key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	_check(app.route == "home" and not app.archive.prepared, "Escape from unfinished expedition stays in the library without reopening preparation")
	await _capture("pending-escape-home")
	var page_entry := preload("res://ui/scenes/departure_ritual.tscn").instantiate() as DepartureRitual
	page_entry.book = app._run_book()
	page_entry.chapter_entry = false
	page_entry.stage_text = "第 1 章 · 第 2 页"
	app.root.add_child(page_entry)
	await page_entry.covered
	page_entry.set_process(false)
	_check(page_entry.get_node("Book").text == "第 1 章 · 第 2 页" and page_entry.get_node("Seal").size.x == 104, "page entrance uses the actual position and a smaller seal")
	await _capture("page-entrance")
	page_entry.release()
	page_entry.set_process(true)
	await page_entry.completed


func _review_curved_frames() -> void:
	app._tutorial_menu()
	app._start_tutorial(&"basics")
	await _settle()
	var session := app.battle.session
	session.set_physics_process(false)
	var source := session.enemies[0]
	source.position = session.player_position + Vector2(-540, -150) / BattleSession.ARENA_SIZE
	source.previous_position = source.position
	source.aimed_position = session.player_position
	session._emit_pattern(source, &"single", 0.32)
	var threat := session.threats[-1]
	var origin := threat.position
	var target := session.player_position
	var arrival := threat.aim_curve((target - origin) * BattleSession.ARENA_SIZE)
	_check(threat.position == source.position and threat.curvature != 0.0, "real enemy emitter launches a turning projectile at its origin")
	await _capture("curved-launch")
	var advanced := 0.0
	for fraction: float in [0.5, 0.9]:
		var destination := arrival * fraction
		while advanced < destination:
			var delta := minf(1.0 / 60.0, destination - advanced)
			session._advance_threats(delta)
			advanced += delta
		await _settle()
		_check(session.threats.has(threat) and threat.trail.size() > 12, "curved projectile retains spaced actual history for a legible tail")
		var tail := MotionTrail.build(threat.trail, threat.position, threat.position, 1.0, false, 32)
		_check(tail[-1] == threat.position, "display trail terminates at the actual projectile head")
		await _capture("curved-%d" % roundi(fraction * 100.0))
	var travel := (threat.position - origin) * BattleSession.ARENA_SIZE
	_check(absf(travel.cross(((target - origin) * BattleSession.ARENA_SIZE).normalized())) > 10.0, "visible mid-flight position deviates from the straight enemy-to-PC line")
	app.battle.warnings.quality = 0
	app.battle.warnings.reduced_motion = true
	await _capture("curved-low-reduced")
	var hp := session.player_hp_q
	while advanced < arrival and session.threats.has(threat):
		session._advance_threats(1.0 / 60.0)
		advanced += 1.0 / 60.0
	_check(session.player_hp_q < hp and not session.threats.has(threat), "real displayed curved flight reaches stationary PC and settles one hit")
	await _settle()
	await _capture("curved-contact")


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
	await _move_to(control)
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


func _key(code: Key, unicode_value: int = 0, window_id: int = 0) -> void:
	var event := InputEventKey.new()
	event.window_id = window_id
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
	while is_instance_valid(app) and is_instance_valid(app.practice_entrance):
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks.append(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1
		push_error(label)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if "--screen-capture" in OS.get_cmdline_user_args():
		await create_timer(0.8).timeout
		var capture_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		DisplayServer.screen_get_image_rect(capture_rect).save_png(evidence.path_join(label + ".png"))
		return
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			image.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	image.save_png(evidence.path_join(label + ".png"))
	await process_frame


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
