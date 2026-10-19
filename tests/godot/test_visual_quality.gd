extends SceneTree
## Exactly two workloads, each visiting the same three tiers and four paid books.
## Durable targets and replenished threats are controlled stress, not a campaign replay.

var workload := "baseline"
var label := "sample"
var capture := false
var combat_only := false
var page: BattlePage
var session: BattleSession
var active := false
var started := 0
var previous := 0
var input_clock := 0.0
var target_index := 0
var serial := 0
var counter_sent := false
var ultimate_sent := false
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var reports: Array[Dictionary] = []
var directory: String
var failures := 0
var checks: Array[Dictionary] = []
var book_id: StringName
var tier := 0
const SECONDS := 12.0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--workload="): workload = argument.trim_prefix("--workload=")
		elif argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		elif argument == "--capture": capture = true
		elif argument == "--combat": combat_only = true
	assert(workload in ["baseline", "extreme"])
	directory = "res://.temp/visual-quality-20261018/" + label.validate_filename() + "-" + workload
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.theme = ArchiveTheme.create(ArchiveHome.BOOKS[0].color)
	var fps_layer := CanvasLayer.new()
	fps_layer.layer = 100
	root.add_child(fps_layer)
	fps_layer.add_child(FpsDisplay.create())
	var preparation := load("res://ui/scenes/render_preparation.tscn").instantiate() as RenderPreparation
	var feedback := load("res://ui/scenes/loading_feedback.tscn").instantiate() as LoadingFeedback
	root.add_child(feedback)
	root.add_child(preparation)
	await preparation.prepare(feedback)
	feedback.hide()
	DebugLog.enabled = true
	for quality in 3:
		if combat_only and quality != 2: continue
		tier = quality
		for book: StringName in [&"frost", &"flame", &"storm", &"spirit"]:
			book_id = book
			await _segment()
	print("QUALITY_REPORT ", directory, " segments=", reports.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)


func _segment() -> void:
	DebugLog._spans = {}
	var creation_started := DebugLog.begin()
	session = BattleSession.new()
	var words: Array[VocabularyEntry] = []
	for word: String in FirstVisitSetup.WORDS: words.append(VocabularyEntry.new(word, "视效测试"))
	session.start_baseline(book_id, words, "hard", "quality-" + workload + "-" + str(book_id), false)
	session.activate_god_mode()
	var selection := BuildSelection.new()
	selection.book_id = book_id
	if book_id == &"frost": selection.assets[&"R032"] = 1
	if book_id == &"spirit" and workload == "extreme":
		selection.assets[&"R005"] = 3
		for relic: StringName in [&"R035", &"R048", &"P007", &"P011"]: selection.assets[relic] = 1
	var compiled := BuildCompiler.new().compile(selection)
	assert(compiled.diagnostics.is_empty(), str(compiled.diagnostics))
	session.install_prepared_build(compiled.build)
	var enemies := 6 if workload == "baseline" else 18
	while session.enemies.size() < enemies:
		session._spawn_enemy(FirstVisitSetup.ENEMY_TYPES[0], Vector2(.5, .5))
	session._spawned = session._room_quota
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.position = Vector2(.5, .5) + Vector2.from_angle(TAU * index / enemies) * 300.0 / BattleSession.ARENA_SIZE
		enemy.previous_position = enemy.position
		enemy.stationary = true
		enemy.combat_locked = true
		enemy.word_age = 1.0
		enemy.hp_q = 100000 * BattleSession.Q
		enemy.max_hp_q = enemy.hp_q
		enemy.attack_clock = 1000.0
	if book_id == &"spirit":
		while session.spirits.size() < session.spirit_capacity(): session._summon_spirit()
		session.spirit_time = 30.0
	var settings := AppSettings.new(directory.path_join("unused-settings.cfg"))
	settings.sound = false
	settings.quality = tier
	settings.fluid_quality = 2
	var presentation: BookPresentation = load("res://game/content/books/%s.tres" % book_id)
	assert(presentation.id == book_id)
	DebugLog.end(&"battle.create.session", creation_started)
	if combat_only:
		await SoundBank.prepare(BattleAudio.CUE_GAIN.keys(), self)
	page = BattlePage.create(session, settings, presentation)
	creation_started = DebugLog.begin()
	root.add_child(page)
	DebugLog.end(&"battle.create.attach", creation_started)
	var creation_scopes := DebugLog._spans.duplicate()
	session.event_committed.connect(_event)
	RenderingServer.viewport_set_measure_render_time(page.stage.viewport.get_viewport_rid(), true)
	rows = []
	events = []
	checks = []
	serial = 0
	target_index = 0
	input_clock = 0.0
	counter_sent = false
	ultimate_sent = false
	DebugLog._spans = {}
	started = Time.get_ticks_usec()
	previous = started
	active = true
	await create_timer(SECONDS).timeout
	active = false
	var counters := events.filter(func(event: Dictionary) -> bool: return event.kind == &"pickup_trigger").size()
	var ultimates := events.filter(func(event: Dictionary) -> bool: return event.kind == &"ultimate").size()
	if counters != 1 or ultimates != 1:
		failures += 1
		push_error("Missing paid counter/ultimate: %s tier %d" % [book_id, tier])
	reports.append({"book": book_id, "presentation": presentation.id, "creation": creation_scopes, "quality": tier, "fluid": 2, "build": selection.to_dict(), "spirit_capacity": session.spirit_capacity(), "events": events, "rows": rows, "checks": checks})
	_save()
	print("QUALITY_SEGMENT ", workload, " ", book_id, " tier=", tier, " frames=", rows.size(), " counter=", counters, " ultimate=", ultimates)
	if capture:
		await _capture("%s-%d" % [book_id, tier])
	if label != "before" and not combat_only:
		await _verify_segment()
		_save()
	page.queue_free()
	await process_frame
	await process_frame


func _physics_process(delta: float) -> bool:
	if not active: return false
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	var count := 96 if workload == "baseline" else 256
	while session.threats.size() < count:
		var source := session.enemies[serial % session.enemies.size()]
		var angle := TAU * float(serial % count) / count
		session._emit_enemy_threat(source, angle + PI, serial, 220.0, 5.0)
		var threat: BattleThreat = session.threats.back()
		threat.position = Vector2(.5, .5) + Vector2.from_angle(angle) * 540.0 / BattleSession.ARENA_SIZE
		threat.previous_position = threat.position
		threat.curvature = .22 if serial % 3 == 0 else 0.0
		threat.life = 8.0
		threat.visual_style = [&"needle", &"quill", &"refrain", &"wisp", &"rune", &"vortex", &"shard", &"heavy", &""][serial % 9]
		serial += 1
	if not counter_sent and elapsed >= 3.0:
		counter_sent = true
		var pickup := session.spawn_pickup(&"rune")
		assert(pickup != null)
		pickup.position = Vector2(.5, .5)
		session.typing.select_target(pickup.id)
		for character in session.typing.word: session.typing.feed(character)
		return false
	if not ultimate_sent and elapsed >= 8.5:
		ultimate_sent = true
		session.resonance_q = BattleSession.ULTIMATE_COST_Q
		session.queue_action(&"ultimate")
	input_clock -= delta
	if input_clock <= 0.0:
		input_clock += 1.0 if workload == "baseline" else .4
		var enemy := session.enemies[target_index % session.enemies.size()]
		target_index += 1
		if not enemy.word_pending:
			session.typing.select_target(enemy.id)
			for character in session.typing.word: session.typing.feed(character)
	return false


func _process(_delta: float) -> bool:
	if not active: return false
	var now := Time.get_ticks_usec()
	var viewport := page.stage.viewport.get_viewport_rid()
	rows.append({"t_s": (now-started)/1000000.0, "wall_ms": (now-previous)/1000.0, "scopes": DebugLog._spans,
		"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport), "render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport),
		"threats": session.threats.size(), "spirits": session.spirits.size(), "fields": session.runtime.fields.size(),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	if label != "before":
		rows[-1]["lights"] = page.visuals.budget.enabled_lights
		rows[-1]["particles"] = page.visuals.budget.particles
	DebugLog._spans = {}
	previous = now
	return false


func _event(event: Dictionary) -> void:
	if active and event.kind in [&"cast", &"pickup_trigger", &"ultimate", &"spirit_intercept", &"action_rejected"]:
		events.append({"t_s": (Time.get_ticks_usec()-started)/1000000.0, "kind": event.kind, "empowered": event.get("empowered", false)})


func _check(ok: bool, description: String) -> void:
	checks.append({"ok": ok, "description": description})
	if not ok:
		failures += 1
		push_error("%s tier %d: %s" % [book_id, tier, description])


func _verify_segment() -> void:
	# Outside timing: freeze rules while exercising the real options entry point.
	session.set_physics_process(false)
	await process_frame
	await process_frame
	var visuals := page.visuals
	var clock_before := session.runtime.clock
	var threats_before := session.threats.size()
	var spirits_before := session.spirits.size()
	var old_projectiles := visuals._projectile_nodes.duplicate()
	var fire_texture := visuals.fluid.combustion.texture
	var heat_before := 0.0
	if book_id == &"flame":
		visuals.fluid.set_process(false)
		heat_before = _average_heat(fire_texture)
	_check(page.warnings._heads.size() == threats_before, "one cached head for every threat")
	_check(page.warnings.low_ribbons.mesh != null if tier == 0 else visuals.threat_glow.ribbons.mesh != null, "continuous ribbon in correct canvas")
	_check(rows.all(func(row: Dictionary) -> bool: return row.lights <= VisualQuality.LIGHTS[tier]), "global light ceiling throughout sample")
	_check(rows.all(func(row: Dictionary) -> bool: return row.particles <= VisualQuality.PARTICLES[tier]), "global particle admission ceiling throughout sample")
	_check(visuals.fluid.combustion.grid.x == VisualQuality.FIRE_LONG_EDGE[tier], "fire resolution follows visual tier")
	var old_ice: Dictionary[IcePatch, int] = {}
	for visual: SpellFieldVisual in visuals.rule_visuals.field_nodes.values():
		if visual.ice != null: old_ice[visual.ice] = visual.ice._resolution
	for visual: UltimateField in visuals._ultimate_nodes.values():
		if visual.ice != null: old_ice[visual.ice] = visual.ice._resolution
	for detail in [0, 2, tier]:
		page.settings.quality = detail
		page.apply_options()
		await process_frame
		await RenderingServer.frame_post_draw
		_check(visuals.budget.enabled_lights <= VisualQuality.LIGHTS[detail], "light ceiling after quality switch")
	for ice in old_ice:
		_check(ice._resolution == old_ice[ice], "existing ice retains birth grid")
	for projectile in old_projectiles:
		_check(visuals._projectile_nodes[projectile] == old_projectiles[projectile], "quality switch retains projectile node")
	_check(visuals.fluid.combustion.texture == fire_texture, "quality switch retains combustion texture identity")
	if book_id == &"flame":
		var heat_after := _average_heat(fire_texture)
		_check(heat_before > 0.0 and absf(heat_after - heat_before) < heat_before * .05, "quality round-trip preserves burning heat within 5 percent")
		visuals.fluid.set_process(true)
	page.settings.fluid_quality = 0
	page.apply_options()
	await process_frame
	await RenderingServer.frame_post_draw
	_check(visuals.rule_visuals.fire_fallback and not visuals.fluid._fire_surface.visible, "fluid off retains analytic fire and stops simulated fire")
	if capture and book_id == &"flame": await _capture("flame-%d-fluid-off" % tier)
	page.settings.reduce_motion = true
	page.apply_options()
	await process_frame
	await process_frame
	for ice in old_ice:
		var steps := ice._steps
		ice.sync_patch(ice.position + ice.size * .5, ice.size.x / 2.5, ice._age + .5, 1.0, tier, true, 1)
		_check(ice._steps == steps, "reduced motion freezes existing ice without catch-up")
	for visual: BattleSpiritVisual in visuals._spirit_nodes.values():
		_check(visual.ribbon.visible == visual.spirit.crossing and not visual.halo.visible and not visual.filament.visible, "reduced spirits retain only required crossing path")
	var ticks := visuals.fluid.tick_count
	await process_frame
	await process_frame
	_check(visuals.fluid.tick_count == ticks, "reduced/off fluid stops solver")
	if capture and book_id in [&"flame", &"frost"]: await _capture("%s-%d-reduced" % [book_id, tier])
	if book_id == &"frost": await _verify_new_static_ice()
	page.settings.fluid_quality = 2
	page.settings.reduce_motion = false
	page.apply_options()
	await process_frame
	await RenderingServer.frame_post_draw
	_check(not visuals.rule_visuals.fire_fallback, "fluid resume restores combustion presentation")
	_check(session.runtime.clock == clock_before and session.threats.size() == threats_before and session.spirits.size() == spirits_before, "option switches do not mutate frozen rules")
	print("QUALITY_CHECKS ", book_id, " tier=", tier, " checks=", checks.size(), " failures=", failures)


func _verify_new_static_ice() -> void:
	var ice := IcePatch.new()
	page.visuals.add_child(ice)
	var birth := Time.get_ticks_usec()
	var age := 0.0
	while age < .65:
		ice.sync_patch(Vector2(1450, 400), 160, age, 1.0, tier, true, 147)
		await process_frame
		age = (Time.get_ticks_usec() - birth) / 1000000.0
	var steps := ice._steps
	ice.sync_patch(Vector2(1450, 400), 160, 1.5, 1.0, tier, true, 147)
	_check(steps > 0 and ice._steps == steps, "new reduced ice finishes a bounded entrance then freezes")
	if capture: await _capture("frost-%d-static-entry" % tier)
	ice.queue_free()


func _average_heat(texture: Texture2DRD) -> float:
	var pixels := texture.get_image()
	var heat := 0.0
	for y in pixels.get_height():
		for x in pixels.get_width(): heat += pixels.get_pixel(x, y).g
	return heat / (pixels.get_width() * pixels.get_height())


func _capture(stem: String) -> void:
	paused = true
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var picture := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width(): picture.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	picture.save_png(directory.path_join(stem + ".png"))
	await RenderingServer.frame_post_draw
	paused = false


func _save() -> void:
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"workload": workload, "seconds": SECONDS, "discard_seconds": 2.0,
		"qualities": [2] if combat_only else [0, 1, 2],
		"cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(),
		"debug": OS.is_debug_build(), "size": str(root.size), "reports": reports, "failures": failures,
		"note": "Four books, selected qualities, two workloads. Durable targets, injected charge, replenished threats, real paid casts/counter/ultimate."}))
