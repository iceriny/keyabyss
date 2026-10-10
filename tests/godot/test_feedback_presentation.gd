extends "res://tests/godot/test_s1_application.gd"
## Real-window review of Arcana masks, compact HUD and archived result projection.


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	evidence = "res://.temp/feedback-20261009/presentation-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	if "--startup-handoff" in OS.get_cmdline_user_args():
		await _review_startup_handoff()
		return
	if "--ritual-boundary" in OS.get_cmdline_user_args():
		await _review_ritual_boundary()
		return
	if "--ritual-light" in OS.get_cmdline_user_args():
		await _review_ritual_light()
		return
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.book_id = "flame"
	app.settings.run_seed = "feedback-presentation"
	app.settings.progressive = false
	app.settings.fullscreen = false
	app.settings.sound = false
	app.settings.ambience = false
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.settings.vocabulary_id = app.vocabulary.save_import(app.vocabulary.parse_import("word,meaning\nash,灰\nink,墨\nfrost,霜\nspirit,灵\narchive,档案\nthunder,雷", "review.csv"))
	app.profile_base_path = evidence.path_join("profiles")
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	if "--result-layout" in OS.get_cmdline_user_args():
		await _review_result()
		return
	await _capture("home")
	app.archive.select_book(0)
	await create_timer(1.4).timeout
	await _capture("home-frost")
	app.archive.select_book(3)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var sheet := Control.new()
	sheet.theme = ArchiveTheme.create(Color("dfc58b"))
	overlay.add_child(sheet)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(root.size)
	backdrop.color = Color("0b1418")
	sheet.add_child(backdrop)
	var large_only := "--sigils-only" in OS.get_cmdline_user_args()
	for row in ArchiveHome.BOOKS.size():
		var book := ArchiveHome.BOOKS[row]
		var title := PageShell.label(sheet, book.title, 21, book.color)
		title.size = Vector2(220, 34)
		var origin := Vector2(350 + (row % 2) * 900, 40 + floori(row / 2.0) * 520)
		title.position = origin + Vector2(135, 468) if large_only else Vector2(80, 110 + row * 220)
		for column in 3:
			if large_only and column != 2: continue
			var diameter: float = 460.0 if large_only else [100.0, 190.0, 350.0][column]
			var texture := ArcanaRunes.seal(book.id, [100.0, 320.0, 800.0][column])
			_check(texture.get_width() == [128, 384, 1024][column], "%s uses its authored resolution tier %d" % [book.id, column])
			var art := TextureRect.new()
			art.texture = texture
			art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.size = Vector2(diameter, diameter if large_only else minf(diameter, 210))
			art.position = origin if large_only else Vector2(400 + column * 300, 22 + row * 230)
			art.modulate = book.color
			sheet.add_child(art)
	await _capture("arcana-tiers")
	overlay.queue_free()
	if large_only:
		print("Large sigil review: ", evidence)
		app.queue_free()
		await _settle()
		quit(0 if failures == 0 else 1)
		return
	app._relics_page()
	await create_timer(.8).timeout
	await _capture("codex")
	_check(app.commands.has("relic58"), "all codex entries remain reachable after deferred construction")
	await _review_result()


func _review_result() -> void:
	app._home()
	app._start_battle()
	for frame in 600:
		await process_frame
		if app.route == "pause": app._resume()
		if app.route == "battle": break
	_check(app.route == "battle", "real departure reaches battle")
	var session := app.battle.session
	session.god_mode = true
	var selection := app.run.selection.copy()
	selection.assets[&"R028"] = 1
	selection.assets[&"R017"] = 1
	session.install_prepared_build(app.run.compiler.compile(selection).build)
	app.run.selection = selection
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.position = Vector2(.67 + index * .08, .46)
		enemy.previous_position = enemy.position
		enemy.attack_clock = 100.0
		enemy.hp_q = 3000 * BattleSession.Q
		enemy.max_hp_q = enemy.hp_q
		enemy.word_pending = false
		enemy.word = "archive"
		session.typing.upsert_target(enemy.id, enemy.word)
	session.typing.select_target(session.enemies[0].id)
	session.typing.feed("z")
	for character in "archive": session.typing.feed(character)
	await create_timer(1.3).timeout
	_check(not app.battle.visuals.rule_visuals._corrosion.is_empty(), "paid direct hit creates attached corrosion projection")
	session.runtime._assist_tokens = 1
	await _capture("battle-hud-corrosion")
	_check(app.battle.cast_word.text.is_empty() and not _labels(app.battle).contains("补全准备中"), "idle input has no filler or Ctrl helper paragraph")
	app.battle.session.finished.disconnect(app._battle_finished)
	session._end(false)
	app._battle_finished(false)
	await _settle()
	var result := app.page.body.get_child(0) as BattleResult
	_check(result.report.stats.manual_characters == 7 and result.report.stats.mistakes == 1, "result shows observed input counts")
	_check(result.report.wrong_words.size() == 1 and result.report.wrong_words[0].meaning == "档案", "result exports wrong word and vocabulary meaning")
	_check(_labels(result).contains("腐蚀墨迹") and _labels(result).contains("通灵羽毛笔"), "result reads archived relics after closing the run")
	_check(result.report.stats.max_combo == 1 and result.report.stats.best_correct_streak == 7, "highest gameplay combo is distinct from correct character streak")
	await _capture("defeat-result")
	_check(result.get_global_rect().end.y < app.page.footer.get_global_rect().position.y, "result content and fixed footer do not overlap")
	_check(result.selected_detail == -1 and not app.page.scroll.get_v_scroll_bar().visible, "result summary has no expanded details or outer scrollbar")
	var footer_position := app.page.footer.global_position
	for detail_index in 3:
		var button := result.detail_buttons[detail_index]
		for is_pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = button.get_global_rect().get_center()
			event.pressed = is_pressed
			Input.parse_input_event(event)
			await _settle()
		_check(result.selected_detail == detail_index, "mouse opens result detail %d" % detail_index)
		_check(app.page.footer.global_position.is_equal_approx(footer_position) and not app.page.scroll.get_v_scroll_bar().visible, "detail %d keeps footer fixed without nested scrolling" % detail_index)
		await _capture("result-detail-%d" % detail_index)
	# A long wrong-word list must scroll only inside the fixed detail region.
	var wrong_label := result.get_node("DetailSlot/Mistakes/Scroll/Words") as Label
	wrong_label.text = (wrong_label.text + "\n\n").repeat(18)
	await _settle()
	var wrong_scroll := result.get_node("DetailSlot/Mistakes/Scroll") as ScrollContainer
	_check(wrong_scroll.get_v_scroll_bar().visible and not app.page.scroll.get_v_scroll_bar().visible, "long wrong-word content stays in its own scroll region")
	await _capture("result-long-words")
	var output := FileAccess.open(evidence.path_join("checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "checks": checks, "screenshots": pictures, "scope": "Controlled real-window presentation and archived result; not a full campaign/balance run."}, "\t"))
	output.close()
	print("Feedback presentation: %d checks, %d failures; %s" % [checks.size(), failures, evidence])
	app.queue_free()
	await _settle()
	quit(0 if failures == 0 else 1)


func _review_startup_handoff() -> void:
	for config: Array in [[1920, 1080, 1.0, false], [2560, 1440, 1.0, false], [2560, 1440, 1.0, true], [2560, 1440, 1.25, false], [2560, 1440, 1.25, true]]:
		root.size = Vector2i(config[0], config[1])
		root.content_scale_size = root.size
		var reduced: bool = config[3]
		var mode := ("still" if reduced else "moving") + "-%dx%d-ui%.2f" % [config[0], config[1], config[2]]
		var overlay := CanvasLayer.new()
		overlay.layer = 120
		root.add_child(overlay)
		var loading := load("res://ui/scenes/departure_ritual.tscn").instantiate() as DepartureRitual
		loading.startup = true
		loading.reduced_motion = reduced
		overlay.add_child(loading)
		loading.feedback.update_stage("画面准备完成", 69, 69)
		await _capture("handoff-loading-" + mode)
		var backdrop := loading.get_node("Backdrop") as RitualBackdrop
		var previous_clock := backdrop.clock
		var source_ring := loading.get_node("LoadingRunes") as Node2D
		var ring_before := source_ring.get_global_transform_with_canvas()
		var feedback_before := loading.feedback.get_global_transform_with_canvas()
		var host := Node.new()
		host.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(host)
		var display := GameDisplay.new()
		display.settings = AppSettings.new()
		display.settings.ui_scale = config[2]
		host.add_child(display)
		var gate := ArchiveGate.create()
		gate.reduced_motion = reduced
		display.add_child(gate)
		gate.reveal_from_loading(loading)
		_check(source_ring.get_global_transform_with_canvas().is_equal_approx(ring_before), "ring preserves output position and scale " + mode)
		_check(gate._loading_feedback.get_global_transform_with_canvas().is_equal_approx(feedback_before), "progress text preserves output position and scale " + mode)
		_check(gate.stage.get_node("Backdrop") == backdrop and backdrop.clock == previous_clock, "handoff keeps the actual backdrop and its clock " + mode)
		_check(gate.prompt.modulate.a == 0.0 and gate.mark.modulate.a == 0.0, "welcome starts with hidden prompt and central seal " + mode)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		gate._input(click)
		_check(not gate.started, "loading completion cannot also trigger entry " + mode)
		if not reduced and config[0] == 2560 and config[2] == 1.0 and "--handoff-frames" in OS.get_cmdline_user_args():
			var frames := evidence.path_join("handoff-motion")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames))
			# Use --fixed-fps 30. Convert HDR before 8-bit encoding; the engine's
			# built-in movie path quantizes this dark scene before conversion.
			for frame in 66:
				await RenderingServer.frame_post_draw
				var source := root.get_texture().get_image()
				source.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
				var picture := Image.create(1280, 720, false, Image.FORMAT_RGB8)
				for y in 720:
					for x in 1280:
						picture.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
				picture.save_png(frames.path_join("handoff-%03d.png" % frame))
		elif not reduced:
			await _capture("handoff-forming")
		while gate._forming: await process_frame
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		await _settle()
		_check(not is_instance_valid(loading), "handoff releases only the loading shell " + mode)
		_check(is_equal_approx(backdrop.formation, 1.0) and gate.prompt.modulate.a > 0.5, "welcome fully forms before accepting continuation " + mode)
		_check(backdrop.clock == 0.0 if reduced else backdrop.clock > previous_clock, "dust clock respects motion setting across handoff " + mode)
		await _capture("handoff-welcome-" + mode)
		gate._input(click)
		_check(gate.started, "continuation works after handoff " + mode)
		host.queue_free()
		overlay.queue_free()
		await _settle()
	var output := FileAccess.open(evidence.path_join("checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "checks": checks, "screenshots": pictures}, "\t"))
	output.close()
	print("Startup handoff: %d checks, %d failures; %s" % [checks.size(), failures, evidence])
	quit(0 if failures == 0 else 1)


func _review_ritual_boundary() -> void:
	root.size = Vector2i(2560, 1440)
	var gate := ArchiveGate.create()
	gate.reduced_motion = true
	root.add_child(gate)
	gate.set_process_input(false)
	await create_timer(0.6).timeout
	await _capture("welcome-boundary-still")
	gate._clock = 27.0
	gate._rotation_clock = 27.0
	gate.stage.get_node("Backdrop").clock = 27.0
	await _capture("welcome-boundary-flow")
	if "--dust-motion" in OS.get_cmdline_user_args():
		var frames := evidence.path_join("dust-motion")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames))
		# Fixed-time shader samples, native pixels, normal brightness; only the
		# backdrop moves so its density transport can be judged independently.
		for frame in 120:
			gate.stage.get_node("Backdrop").clock = 12.0 + float(frame) / 15.0
			await _settle()
			await RenderingServer.frame_post_draw
			var crop := root.get_texture().get_image().get_region(Rect2i(320, 280, 640, 640))
			var picture := Image.create(640, 640, false, Image.FORMAT_RGB8)
			for y in 640:
				for x in 640:
					picture.set_pixel(x, y, crop.get_pixel(x, y).linear_to_srgb())
			picture.save_png(frames.path_join("dust-%03d.png" % frame))
	# Evaluate the production noise on both sides of every lattice boundary.
	# HDR readback catches seams that normal dark screenshots can conceal.
	var source: String = load("res://ui/materials/ritual_atmosphere.gdshader").code
	var probe := SubViewport.new()
	probe.size = Vector2i(64, 64)
	probe.use_hdr_2d = true
	probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(probe)
	var surface := ColorRect.new()
	surface.size = Vector2(probe.size)
	var material := ShaderMaterial.new()
	surface.material = material
	probe.add_child(surface)
	for axis in ["vec2(1, 0)", "vec2(0, 1)"]:
		var shader := Shader.new()
		shader.code = source.left(source.find("void fragment()")) + """
void fragment() {
	vec2 axis = %s;
	vec2 p = floor(FRAGCOORD.xy) - vec2(32) + (vec2(1) - axis) * 0.37;
	COLOR = vec4(noise(p - axis * 0.0001), noise(p), noise(p + axis * 0.0001), 1);
}
""" % axis
		material.shader = shader
		await _settle()
		await RenderingServer.frame_post_draw
		var sample := probe.get_texture().get_image()
		var max_jump := 0.0
		for y in sample.get_height():
			for x in sample.get_width():
				var value := sample.get_pixel(x, y)
				max_jump = maxf(max_jump, maxf(absf(value.r - value.g), absf(value.b - value.g)))
		_check(max_jump < 0.001, "GPU noise is continuous across 4096 lattice edges " + axis + "; max jump=" + str(max_jump))
	probe.queue_free()
	gate.queue_free()
	await _settle()
	var output := FileAccess.open(evidence.path_join("checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "checks": checks, "screenshots": pictures}, "\t"))
	output.close()
	print("Ritual boundary: %d checks, %d failures; %s" % [checks.size(), failures, evidence])
	quit(0 if failures == 0 else 1)


func _review_ritual_light() -> void:
	for reduced in [false, true]:
		var mode := "still" if reduced else "moving"
		var loading := load("res://ui/scenes/departure_ritual.tscn").instantiate() as DepartureRitual
		loading.startup = true
		loading.reduced_motion = reduced
		root.add_child(loading)
		loading.feedback.update_stage("正在准备画面与光效", 2, 8)
		await create_timer(0.6).timeout
		_check(loading.get_node("LoadingRunes/RingLight/Rotor/Progress").value == 25.0, "light preserves measured loading progress " + mode)
		_check(loading._light_clock == 0.0 if reduced else loading._light_clock > 0.0, "loading flow respects reduced motion " + mode)
		_check((loading.get_node("LoadingRunes/Rotation") as AnimationPlayer).is_playing() != reduced, "loading rotation respects reduced motion " + mode)
		await _capture("loading-light-" + mode)
		loading.feedback.update_stage("画面准备完成", 8, 8)
		_check(loading.get_node("LoadingRunes/RingLight/Rotor/Progress").value == 100.0, "completed progress reaches full circle " + mode)
		loading.release()
		await loading.completed
		await _settle()
		_check(not is_instance_valid(loading), "loading releases its light layer " + mode)
		var gate := ArchiveGate.create()
		gate.reduced_motion = reduced
		root.add_child(gate)
		await create_timer(0.6).timeout
		_check(gate._clock == 0.0 if reduced else gate._clock > 0.0, "welcome flow respects reduced motion " + mode)
		_check(gate.title.material == null and gate.prompt.material == null, "welcome text remains outside the light material " + mode)
		_check(gate.prompt.text == "任意键继续" and not gate.stage.has_node("PromptHint"), "welcome has one concise continuation prompt " + mode)
		_check(gate.orbit.get("progress") == 0.0 and gate.outer_runes.modulate.a > gate.orbit.modulate.a, "outer runes are lit independently without a partial progress arc " + mode)
		await _capture("welcome-light-" + mode)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(root.size) * 0.5
		Input.parse_input_event(click)
		await _settle()
		_check(gate.started, "mouse starts the welcome transition " + mode)
		click = click.duplicate()
		click.pressed = false
		Input.parse_input_event(click)
		if not reduced:
			await create_timer(0.4).timeout
			_check(gate.rotation_speed > 0.0 and gate.rotation_speed < 0.8 and gate.wave_energy == 0.0, "entry decelerates before emitting the wave")
			while gate.elapsed < 0.95: await process_frame
			var stopped_clock := gate._rotation_clock
			await create_timer(0.15).timeout
			_check(is_equal_approx(gate._rotation_clock, stopped_clock) and gate.wave_progress == 0.0, "entry holds a stationary seal before reversal")
			while gate.elapsed < 1.9: await process_frame
			_check(gate.rotation_speed < -10.0 and gate._rotation_clock < stopped_clock and gate.wave_progress > 0.0 and gate.wave_energy > 0.0, "fast reverse rotation and expanding shockwave share the release phase")
			await _capture("welcome-light-awakening")
		await gate.entered
		await _settle()
		_check(not is_instance_valid(gate), "welcome transition releases its light layer " + mode)
	var preparation := load("res://ui/scenes/render_preparation.tscn").instantiate() as RenderPreparation
	for scene in preparation.scenes: preparation._collect_scene(scene)
	var has_light := false
	for material in preparation._catalog:
		if material is ShaderMaterial and material.shader.resource_path == "res://ui/materials/ritual_light.gdshader": has_light = true
	_check(has_light, "authored ritual light is discovered by render preparation")
	preparation.free()
	var output := FileAccess.open(evidence.path_join("checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "checks": checks, "screenshots": pictures, "scope": "Loading and welcome light, measured progress, mouse continuation and reduced motion in a real window; no performance or balance claim."}, "\t"))
	output.close()
	print("Ritual light: %d checks, %d failures; %s" % [checks.size(), failures, evidence])
	quit(0 if failures == 0 else 1)
