extends "res://tests/godot/test_ui_refinement.gd"
## Focused native-window coverage for the reading material and its input boundary.


func _run() -> void:
	evidence = "res://.temp/open-crystal/run-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.sound = false
	app.settings.ambience = false
	app.settings.reduce_motion = true
	app.profile_base_path = evidence.path_join("profiles")
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	await _type("settings")
	await create_timer(0.5).timeout
	if "--optics-proof" in OS.get_cmdline_user_args():
		await _review_optics()
		return
	if "--relic-only" in OS.get_cmdline_user_args():
		await _open_relic_fixture()
		await _review_relic_ornaments()
		await _capture("reward")
		await _finish_review()
		return
	_check(app.page.reading_style == "settings", "settings opens the authored reading material")
	_check(not app.page.get_node("CrystalSheets").visible, "reading material replaces the old decoration")
	var optical := app.page.wash.material as ShaderMaterial
	var heading_position := app.page.heading.global_position
	var initial_clock := float(optical.get_shader_parameter("clock"))
	await create_timer(0.2).timeout
	_check(is_equal_approx(initial_clock, float(optical.get_shader_parameter("clock"))), "reduced motion keeps the material stationary")
	await _capture("settings")
	await _click(app.settings_controls["show_fps"])
	_check(app.settings.show_fps, "material does not intercept native setting clicks")
	await _type("visuals")
	await _click(app.settings_controls["reduce_motion"])
	await create_timer(0.6).timeout
	_check(float(optical.get_shader_parameter("clock")) > initial_clock, "live settings resume material flow")
	await _capture("settings-flow")
	await _click(app.settings_controls["reduce_motion"])
	var frozen_clock := float(optical.get_shader_parameter("clock"))
	await create_timer(0.2).timeout
	_check(is_equal_approx(frozen_clock, float(optical.get_shader_parameter("clock"))), "reducing motion freezes the current phase without a jump")
	_check(app.page.heading.global_position == heading_position, "settings tabs and material animation leave the heading fixed")
	var quality_select := app.settings_controls["quality"] as OptionButton
	quality_select.select(0)
	quality_select.item_selected.emit(0)
	await _settle()
	_check(int(optical.get_shader_parameter("quality")) == 0, "low quality reaches the existing material")
	await _capture("settings-low")
	quality_select.select(2)
	quality_select.item_selected.emit(2)
	app.settings.show_fps = false
	app._apply_visual_settings()
	app._guide()
	await create_timer(0.7).timeout
	_check(app.page.reading_style == "guide", "guide uses its own crystal composition")
	await _capture("guide")
	var title_y := app.page.heading.global_position.y
	var scroll_before := app.page.scroll.scroll_vertical
	await _wheel(app.page.scroll, MOUSE_BUTTON_WHEEL_DOWN)
	await create_timer(0.3).timeout
	_check(app.page.scroll.scroll_vertical > scroll_before and app.page.heading.global_position.y == title_y, "guide scrolls internally under a fixed heading")
	app._vocabulary_page()
	await create_timer(0.4).timeout
	_check(app.page.reading_style == "words", "vocabulary uses its own crystal composition")
	await _capture("words")
	var vocabulary_choices := app.page.body.find_children("V*", "OpenButton", true, false)
	if vocabulary_choices.size() > 1:
		var detail_position := app.vocab_detail.global_position
		await _click(vocabulary_choices[1] as Control)
		_check(app.vocab_detail.global_position == detail_position, "vocabulary selection preserves the detail anchor")
	app.settings.resolution = Vector2i(1440, 900)
	app.settings.ui_scale = 1.15
	app._apply_visual_settings()
	await create_timer(0.5).timeout
	optical = app.page.wash.material as ShaderMaterial
	_check((optical.get_shader_parameter("canvas_size") as Vector2).is_equal_approx(app.page.size), "material tracks the scaled logical canvas")
	await _capture("words-1440-115")
	app._about_page()
	await create_timer(0.4).timeout
	_check((app.page.wash.material as ShaderMaterial).shader.resource_path.ends_with("open_crystal.gdshader"), "about shares the common optical shader")
	app._tutorial_menu()
	await _settle()
	_check(app.page.reading_style == "guide", "tutorial menu shares the open crystal composition")
	await _capture("tutorial-menu")
	app.settings.resolution = Vector2i(1920, 1080)
	app.settings.ui_scale = 1.0
	app._apply_visual_settings()
	await _review_shared_surfaces()
	await _finish_review()


func _finish_review() -> void:
	var report := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("Open crystal: %d checks, %d failures | %s" % [checks.size(), failures, evidence])
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)


func _review_shared_surfaces() -> void:
	app._home(false)
	await create_timer(0.4).timeout
	await _capture("home")
	var edges := app.archive.stage.get_node("CrystalEdges") as CrystalEdges
	_check(edges.visible and edges.reduced_motion, "home edges respect reduced motion")
	await _key(KEY_SPACE)
	await create_timer(0.4).timeout
	await _capture("preparation")
	app._relics_page()
	await create_timer(0.5).timeout
	_check(app.page.reading_style == "guide" and not edges.visible, "codex replaces the home edge pass")
	await _capture("codex")
	await _open_relic_fixture()
	await _capture("reward")
	await _review_relic_ornaments()
	app._show_reward_detail(app.run.compiler.catalog.get_definition(&"G001"))
	await create_timer(0.4).timeout
	var detail := app.page.get_node("RewardDetail") as PageShell
	_check(not detail.reading_style.is_empty(), "nested detail uses the same optical material")
	_check(not app.page.wash.visible and not app.page.content_layer.visible,
		"nested detail replaces the parent veil instead of stacking blur")
	await _capture("reward-detail")
	app._close_reward_detail()
	await _settle()
	_check(app.page.wash.visible and app.page.content_layer.visible, "closing detail restores the original reward page")
	app.run = null
	app.profile.run_checkpoint.clear()
	app._home(false)
	app._start_practice()
	await create_timer(0.5).timeout
	await _capture("practice")
	app._enter_tutorial(&"basics")
	await create_timer(0.4).timeout
	edges = app.battle.stage.get_node("CrystalEdges") as CrystalEdges
	_check(edges.battle and edges.reduced_motion, "battle keeps decorative flow outside the central arena")
	await _capture("battle")
	await _review_battle_boundary(edges)
	app._pause()
	await create_timer(0.4).timeout
	await _capture("pause")
	app._resume()
	app._home(false)
	app._first_setup_page()
	await create_timer(0.6).timeout
	_check((app.page.wash.material as ShaderMaterial).shader.resource_path.ends_with("open_crystal.gdshader"), "calibration retains the common optical shader")
	await _capture("calibration")
	app._complete_first_setup()
	await _settle()
	app._home(false)
	app.run = null
	app.profile.run_checkpoint.clear()
	app._start_battle()
	await create_timer(0.6).timeout
	if is_instance_valid(app.departure):
		await app.departure.completed
	if paused:
		app._resume()
	app.battle.session.set_physics_process(false)
	app.battle.session.result = -1
	app._battle_finished(false)
	await create_timer(0.6).timeout
	_check(app.page.reading_style == "words", "result inherits the continuous river composition")
	await _capture("result")


func _open_relic_fixture() -> void:
	app._home(false)
	app.run = RunSession.new(app.saves, app.profile)
	_check(app.run.begin(&"flame", app.settings), "isolated visual fixture starts")
	app.profile = app.run.profile
	app.run.phase = "REWARD"
	app.run.rewards.earned = 5
	app.run.offer = {"id": "crystal-review", "candidates": ["G001", "G002", "R012"]}
	app._show_run_stage(false)
	await create_timer(0.4).timeout


func _review_relic_ornaments() -> void:
	var choices := app.page.body.get_node("RewardChoices").get_children()
	var assigned := RelicOrnaments.for_offer(app.run.offer.candidates)
	var unique := {}
	for choice: RelicRewardChoice in choices:
		unique[choice.ornament_index] = true
	_check(unique.size() == choices.size(), "offered relics have distinct authored silhouettes")
	_check(assigned == RelicOrnaments.for_offer(app.run.offer.candidates), "reopening an offer keeps the same ornaments")
	var actions: Array[Vector2] = []
	for choice: RelicRewardChoice in choices:
		actions.append(choice.content.get_child(-1).global_position)
	for group in 4:
		for index in choices.size():
			var texture := RelicOrnaments.texture(group * 3 + index)
			var fields := RelicOrnaments.optics(group * 3 + index).get_image()
			_check(texture.get_image().has_mipmaps() and fields.get_format() == Image.FORMAT_RGBAH,
				"ornament %d retains mipmaps and half-float optical data" % (group * 3 + index))
			choices[index].set_ornament(group * 3 + index)
		await _settle()
		await _capture("relic-ornaments-%d" % group)
	for index in choices.size():
		choices[index].set_ornament(assigned[index])
	for choice: RelicRewardChoice in choices:
		var mask := (choice.get_node("GlyphMask") as SubViewport).get_texture().get_image()
		var ink := 0.0
		for y in range(0, mask.get_height(), 4):
			for x in range(0, mask.get_width(), 4):
				ink += mask.get_pixel(x, y).a
		choice.get_node("GlyphMask/Glyph").hide()
		await _settle()
		var after := (choice.get_node("GlyphMask") as SubViewport).get_texture().get_image()
		_check(ink > 1.0 and mask.get_data() == after.get_data(),
			"relic engraving is rendered once from the original identity")
		choice.get_node("GlyphMask/Glyph").show()
	await _review_relic_optics(choices)
	if "--record-relics" in OS.get_cmdline_user_args():
		paused = true
		app.page.set_process(false)
		for choice: RelicRewardChoice in choices:
			choice.set_process(false)
		for frame in 144:
			var phase := float(frame) / 24.0
			(app.page.wash.material as ShaderMaterial).set_shader_parameter("clock", phase)
			for choice: RelicRewardChoice in choices:
				choice._surface.set_shader_parameter("clock", phase)
				choice._surface.set_shader_parameter("backdrop_clock", phase)
			await _settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_exr(evidence.path_join("relic-motion-%03d.exr" % frame))
		for choice: RelicRewardChoice in choices:
			choice.set_process(true)
		app.page.set_process(true)
		paused = false
	await _alt(true)
	await _settle()
	for index in choices.size():
		_check(choices[index].detail_mode and choices[index].content.get_child(-1).global_position.is_equal_approx(actions[index]),
			"Alt detail keeps reward action %d anchored" % index)
	await _capture("reward-alt")
	await _alt(false)
	var choice := choices[0] as RelicRewardChoice
	choice.reduced_motion = false
	await create_timer(0.15).timeout
	choice.reduced_motion = true
	var frozen := choice._clock
	await create_timer(0.15).timeout
	_check(is_equal_approx(frozen, choice._clock), "reduced motion freezes the ornament's current phase")


func _review_relic_optics(choices: Array[Node]) -> void:
	paused = true
	app.page.set_process(false)
	for choice: RelicRewardChoice in choices:
		choice.set_process(false)
		choice._surface.set_shader_parameter("clock", 1.8)
	await _settle()
	await _capture("relic-optical")
	var original := Image.load_from_file(evidence.path_join("relic-optical.png"))
	for channel: String in ["show_reflection", "show_refraction"]:
		for choice: RelicRewardChoice in choices:
			choice._surface.set_shader_parameter(channel, false)
		await _settle()
		await _capture("relic-without-" + channel)
		var compared := Image.load_from_file(evidence.path_join("relic-without-" + channel + ".png"))
		var changed := 0
		for choice: RelicRewardChoice in choices:
			var wash := choice.get_node("Wash") as Control
			var region := Rect2i(wash.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, wash.size))
			region = region.intersection(Rect2i(Vector2i.ZERO, original.get_size()))
			for y in range(region.position.y, region.end.y, 2):
				for x in range(region.position.x, region.end.x, 2):
					var a := original.get_pixel(x, y)
					var b := compared.get_pixel(x, y)
					changed += int(maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 2.0 / 255.0)
		_check(changed > 30, "relic %s changes rendered optical pixels (%d)" % [channel, changed])
		for choice: RelicRewardChoice in choices:
			choice._surface.set_shader_parameter(channel, true)
	for choice: RelicRewardChoice in choices:
		choice.set_process(true)
	app.page.set_process(true)
	paused = false


func _review_battle_boundary(edges: CrystalEdges) -> void:
	paused = true
	app.battle.stage.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await _settle()
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	edges.hide()
	await _settle()
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var changed_center := 0
	var changed_edge := 0
	for y in range(0, before.get_height(), 8):
		for x in range(0, before.get_width(), 8):
			var first := before.get_pixel(x, y)
			var second := after.get_pixel(x, y)
			var difference := maxf(absf(first.r-second.r), maxf(absf(first.g-second.g), absf(first.b-second.b)))
			if difference <= 0.002:
				continue
			var central := x > before.get_width()*0.12 and x < before.get_width()*0.88 and y > before.get_height()*0.12 and y < before.get_height()*0.88
			if central:
				changed_center += 1
			else:
				changed_edge += 1
	_check(changed_center == 0 and changed_edge > 10, "GPU edge pass leaves the central battle pixels unchanged")
	edges.show()
	app.battle.stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	paused = false


func _review_optics() -> void:
	# Freeze the actual background and controls: only the tested material changes.
	paused = true
	app.page.set_process(false)
	var optical := app.page.wash.material as ShaderMaterial
	var switches := ["show_flow", "show_highlights", "show_refraction", "show_blur_flow", "show_reflection", "show_blur"]
	for field: String in ["structure_a", "gradient_a", "flow_a"]:
		var texture := optical.get_shader_parameter(field) as Texture2D
		_check(texture.get_image().get_format() == Image.FORMAT_RGBAH,
			field + " retains half-float linear data after import")
	var comparisons := [
		{"name": "stationary", "enabled": switches},
		{"name": "travelling-light", "enabled": ["show_flow", "show_highlights"]},
		{"name": "moving-reflection", "enabled": ["show_flow", "show_reflection"]},
		{"name": "flowing-blur", "enabled": ["show_blur", "show_blur_flow"]},
		{"name": "refraction", "enabled": ["show_refraction"]},
	]
	var metrics: Array[Dictionary] = []
	for comparison: Dictionary in comparisons:
		for setting: String in switches:
			optical.set_shader_parameter(setting, setting in comparison.enabled)
		optical.set_shader_parameter("clock", 0.0)
		await _settle()
		await _capture(comparison.name + "-a")
		if comparison.name == "refraction":
			optical.set_shader_parameter("show_refraction", false)
		elif comparison.name != "stationary":
			optical.set_shader_parameter("clock", 3.4)
		await _settle()
		await _capture(comparison.name + "-b")
		var before := Image.load_from_file(evidence.path_join(comparison.name + "-a.png"))
		var after := Image.load_from_file(evidence.path_join(comparison.name + "-b.png"))
		var changed := 0
		var total := 0
		var peak := 0.0
		for y in range(0, before.get_height(), 4):
			for x in range(0, before.get_width(), 4):
				var first := before.get_pixel(x, y)
				var second := after.get_pixel(x, y)
				var difference := maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))
				peak = maxf(peak, difference)
				changed += int(difference > 2.0 / 255.0)
				total += 1
		metrics.append({"effect": comparison.name, "changed_fraction": float(changed) / total, "peak": peak})
		if comparison.name == "stationary":
			_check(float(changed) / total < 0.0005, "fixed phase and background produce the same rendered image")
		else:
			_check(float(changed) / total > 0.005, comparison.name + " changes actual rendered pixels")
	for setting: String in switches:
		optical.set_shader_parameter(setting, true)
	for frame in 144:
		optical.set_shader_parameter("clock", float(frame) / 24.0)
		await _settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_exr(evidence.path_join("motion-%03d.exr" % frame))
	optical.set_shader_parameter("clock", 3.4)
	await _capture("settings-optical")
	root.size = Vector2i(2560, 1440)
	app.settings.resolution = Vector2i(2560, 1440)
	app._apply_visual_settings()
	await _settle()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_size() == Vector2(2560, 1440), "detail capture renders at native 2560 by 1440")
	await _capture("settings-2560")
	var report := FileAccess.open(evidence.path_join("optics.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "metrics": metrics}, "\t"))
	report.close()
	print("Crystal optics: %s | %s" % [JSON.stringify(metrics), evidence])
	paused = false
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
