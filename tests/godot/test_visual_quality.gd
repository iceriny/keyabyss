extends SceneTree
## Exactly two workloads, each visiting the same three tiers and four paid books.
## Durable targets and replenished threats are controlled stress, not a campaign replay.

var workload := "baseline"
var label := "sample"
var output_root := "res://.temp/visual-quality-20261018"
var capture := false
var combat_only := false
var geometry_only := false
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
const GPU_TIMING = preload("res://ui/effects/gpu_effect_timing.gd")
var _gpu_profile := false
var _gpu_batches: Array[Dictionary] = []
var _gpu_file: FileAccess


class ReferenceLightningArc extends LightningArc:
	# Frozen GDScript generator and HEAD triangle stream, independent of C#.
	func advance(progress: float) -> void:
		(material as ShaderMaterial).set_shader_parameter("progress", progress)
		(material as ShaderMaterial).set_shader_parameter("reduced_motion", reduced)
		if is_instance_valid(illumination):
			var age := progress * .24
			illumination.modulate.a = 0.0 if reduced else exp(-age*24.0) + .8*exp(-pow((age-.065)/.02,2.0)) + .4*exp(-pow((age-.13)/.018,2.0))
		var phase := 0 if reduced else mini(2, int(progress * 4.0))
		if phase == _phase: return
		_phase = phase
		_rng.seed = random_seed + phase * 7919
		_vertices.clear()
		_uvs.clear()
		_colors.clear()
		if burst_radius > 0.0:
			var tips := PackedVector2Array()
			var rotation_offset := _rng.randf_range(0.0, TAU)
			for index in 7:
				var angle := rotation_offset + index * TAU / 7.0
				var tip := Vector2.from_angle(angle) * burst_radius * _rng.randf_range(.78, 1.0)
				tips.append(tip)
				_append_path(_path(Vector2.ZERO, tip, burst_radius * .16), .8)
			if quality > 0:
				for index in 7:
					_append_path(_path(tips[index], tips[(index + 1) % 7], burst_radius * .1), .28)
			_publish_mesh()
			return
		var trunk := _path(Vector2(-reach * .5, 0), Vector2(reach * .5, 0), reach * .085)
		_append_path(trunk, 1.0)
		var branches := 0 if quality == 0 else ceili(clampi(int(reach / 95.0), 3, 9) * (0.5 if quality == 1 else 1.0))
		for index in branches:
			var root_index := _rng.randi_range(2, trunk.size() - 3)
			var origin := trunk[root_index]
			var direction := (trunk[root_index + 1] - trunk[root_index - 1]).normalized()
			var side := -1.0 if _rng.randf() < .5 else 1.0
			var branch_length := minf(reach * .3, 130)
			var tip := origin + direction.rotated(side * _rng.randf_range(.55, 1.4)) * _rng.randf_range(branch_length * .4, branch_length)
			var branch := _path(origin, tip, origin.distance_to(tip) * .18)
			_append_path(branch, _rng.randf_range(.18, .42))
			if quality == 2 and index % 2 == 0:
				var fork := branch[floori(branch.size() * .5)]
				_append_path(_path(fork, fork + direction.rotated(-side * .9) * _rng.randf_range(15, 40), 5.0), .12)
		_publish_mesh()

	func _path(start: Vector2, end: Vector2, displacement: float) -> PackedVector2Array:
		var points := PackedVector2Array([start, end])
		for level in clampi(ceili(log(start.distance_to(end) / 9.0) / log(2.0)), 2, 6):
			var divided := PackedVector2Array([points[0]])
			for index in points.size() - 1:
				var a := points[index]
				var b := points[index + 1]
				var normal := (b - a).normalized().orthogonal()
				var middle := a.lerp(b, _rng.randf_range(.35, .65)) + normal * _rng.randf_range(-displacement, displacement)
				divided.append(middle)
				divided.append(b)
			points = divided
			displacement *= .48
		return points

	func _append_path(points: PackedVector2Array, power: float) -> void:
		for index in points.size() - 1:
			var a := points[index]
			var b := points[index + 1]
			var axis := (b - a).normalized()
			var side := axis.orthogonal()
			var half := a.distance_to(b) * .5
			var center := (a + b) * .5
			var pad := 13.0 if power > .5 else 7.0
			var corners := PackedVector2Array([Vector2(-half-pad,-pad),Vector2(half+pad,-pad),Vector2(half+pad,pad),Vector2(-half-pad,pad)])
			for corner in [0, 1, 2, 0, 2, 3]:
				var local := corners[corner]
				_vertices.append(center + axis * local.x + side * local.y)
				_uvs.append(local)
				# Alpha is linear geometry data; RGB passes through Godot's sRGB decode.
				_colors.append(Color(power, float(index) / (points.size()-1), 0.0, half / 64.0).linear_to_srgb())

	func _publish_mesh() -> void:
		pass


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--workload="): workload = argument.trim_prefix("--workload=")
		elif argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		elif argument.begins_with("--output-root="): output_root = argument.trim_prefix("--output-root=")
		elif argument == "--capture": capture = true
		elif argument == "--combat": combat_only = true
		elif argument == "--geometry-only": geometry_only = true
	if workload not in ["baseline", "extreme"]:
		push_error("Unknown workload: " + workload)
		quit(1)
		return
	directory = output_root.path_join(label.validate_filename() + "-" + workload)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		push_error("Cannot create evidence directory: %s (%s)" % [directory, error_string(error)])
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if geometry_only:
		book_id = &"storm"
		_verify_lightning_geometry()
		reports.append({"book": book_id, "checks": checks, "rows": []})
		_save()
		print("QUALITY_GEOMETRY ", workload, " checks=", checks.size(), " failures=", failures)
		quit(0 if failures == 0 else 1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Visual quality measurement requires the actual renderer")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.theme = ArchiveTheme.create(ArchiveHome.BOOKS[0].color)
	var fps_layer := CanvasLayer.new()
	fps_layer.layer = 100
	root.add_child(fps_layer)
	fps_layer.add_child(FpsDisplay.create())
	_gpu_profile = GPU_TIMING.start(_record_gpu_timing)
	if _gpu_profile:
		_gpu_file = FileAccess.open(directory.path_join("gpu-effects.jsonl"), FileAccess.WRITE)
		if _gpu_file == null:
			push_error("Cannot open GPU evidence: " + error_string(FileAccess.get_open_error()))
			quit(1)
			return
	GPU_TIMING.set_context({"workload": workload, "phase": "preparation"})
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
	if _gpu_profile:
		# Drain already queued queries through ordinary frames, never rd.sync().
		for _frame in RenderingServer.get_rendering_device().get_frame_delay() + 2:
			await process_frame
		GPU_TIMING.stop()
		await process_frame
		_save()
		_gpu_file.close()
	print("QUALITY_REPORT ", directory, " segments=", reports.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)


func _segment() -> void:
	_gpu_context("creation")
	DebugLog._spans = {}
	var creation_started := DebugLog.begin()
	session = BattleSession.new()
	DebugLog.end(&"battle.create.node", creation_started)
	var session_started := DebugLog.begin()
	var words: Array[VocabularyEntry] = []
	for word: String in FirstVisitSetup.WORDS: words.append(VocabularyEntry.new(word, "视效测试"))
	session.start_baseline(book_id, words, "hard", "quality-" + workload + "-" + str(book_id), false)
	DebugLog.end(&"battle.create.baseline", session_started)
	session.activate_god_mode()
	var selection := BuildSelection.new()
	selection.book_id = book_id
	if book_id == &"frost": selection.assets[&"R032"] = 1
	if book_id == &"spirit" and workload == "extreme":
		selection.assets[&"R005"] = 3
		for relic: StringName in [&"R035", &"R048", &"P007", &"P011"]: selection.assets[relic] = 1
	var compiled := BuildCompiler.new().compile(selection)
	if not compiled.diagnostics.is_empty():
		push_error(str(compiled.diagnostics))
		quit(1)
		return
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
	if presentation.id != book_id:
		push_error("Presentation does not match book: " + str(book_id))
		quit(1)
		return
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
	_gpu_context("sample")
	await create_timer(SECONDS).timeout
	active = false
	_gpu_context("validation")
	var counters := events.filter(func(event: Dictionary) -> bool: return event.kind == &"pickup_trigger").size()
	var ultimates := events.filter(func(event: Dictionary) -> bool: return event.kind == &"ultimate").size()
	if counters != 1 or ultimates != 1:
		failures += 1
		push_error("Missing paid counter/ultimate: %s tier %d" % [book_id, tier])
	if book_id == &"storm":
		_verify_lightning_geometry()
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
		if pickup == null:
			push_error("Counter pickup allocation failed")
			quit(1)
			return false
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
		"process_frame": Engine.get_process_frames(),
		"ribbon_index_uploaded": page.visuals.threat_glow.index_uploaded,
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


func _verify_lightning_geometry() -> void:
	# Outside frame sampling, also exercised by --combat's high-tier-only run.
	for detail in 3:
		for less_motion: bool in [false, true]:
			for burst: bool in [false, true]:
				for seed_value: int in [1, 7919]:
					_verify_lightning_case(300.0 if workload == "baseline" else 900.0, (96.0 if workload == "baseline" else 240.0) if burst else 0.0, detail, less_motion, seed_value)
	# Probe level/branch thresholds without multiplying all quality/seed cases.
	var boundaries := [35.99, 36.01, 379.99, 380.01] if workload == "baseline" else [287.99, 288.01, 854.99, 855.01, 949.99, 950.01]
	for boundary: float in boundaries:
		_verify_lightning_case(boundary, 0.0, 2, false, 1)


func _verify_lightning_case(length: float, radius: float, detail: int, less_motion: bool, seed_value: int) -> void:
	var current := LightningArc.new()
	var reference := ReferenceLightningArc.new()
	for arc: LightningArc in [current, reference]:
		arc.reach = length
		arc.burst_radius = radius
		arc.random_seed = seed_value
		arc.quality = detail
		arc.reduced = less_motion
		arc.material = preload("res://ui/materials/lightning_arc.tres").duplicate()
	for progress: float in [0.0, 0.3, 0.6]:
		current.advance(progress)
		reference.advance(progress)
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		for vertex_index in current._indices:
			vertices.append(current._vertices[vertex_index])
			uvs.append(current._uvs[vertex_index])
			colors.append(current._colors[vertex_index])
		var context := "lightning reach=%.2f radius=%.2f quality=%d reduced=%s seed=%d progress=%.1f" % [length, radius, detail, less_motion, seed_value, progress]
		_check_lightning_bytes(vertices.to_byte_array(), reference._vertices.to_byte_array(), context + " vertex bytes", 8)
		_check_lightning_bytes(uvs.to_byte_array(), reference._uvs.to_byte_array(), context + " UV bytes", 8)
		_check_lightning_bytes(colors.to_byte_array(), reference._colors.to_byte_array(), context + " color bytes", 16)
		_check(current._rng.state == reference._rng.state, context + " RNG state")
		var mesh_rid := current.mesh.get_rid()
		var current_state := current._rng.state
		var reference_state := reference._rng.state
		current.advance(progress)
		reference.advance(progress)
		_check(current.mesh.get_rid() == mesh_rid and current._rng.state == current_state and reference._rng.state == reference_state, context + " same phase retains mesh and RNG")
	current.free()
	reference.free()


func _check_lightning_bytes(actual: PackedByteArray, expected: PackedByteArray, context: String, stride: int) -> void:
	var same := actual == expected
	if not same:
		var offset := 0
		while offset < mini(actual.size(), expected.size()) and actual[offset] == expected[offset]:
			offset += 1
		print("LIGHTNING_BYTE_DIFF ", context, " byte_offset=", offset, " attribute_index=", floori(float(offset) / stride), " actual_bytes=", actual.size(), " expected_bytes=", expected.size())
	_check(same, context)


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
	var error := picture.save_png(directory.path_join(stem + ".png"))
	if error != OK:
		push_error("Cannot save capture: " + error_string(error))
		quit(1)
		return
	await RenderingServer.frame_post_draw
	paused = false


func _gpu_context(phase: String) -> void:
	GPU_TIMING.set_context({"workload": workload, "book": book_id, "quality": tier, "phase": phase})


func _record_gpu_timing(batch: Dictionary) -> void:
	_gpu_batches.append(batch)


func _save() -> void:
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot open frame report: " + error_string(FileAccess.get_open_error()))
		quit(1)
		return
	file.store_string(JSON.stringify({"workload": workload, "seconds": SECONDS, "discard_seconds": 2.0,
		"mode": "geometry" if geometry_only else "frames",
		"qualities": [2] if combat_only else [0, 1, 2],
		"cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(),
		"debug": OS.is_debug_build(), "size": str(root.size), "reports": reports, "failures": failures, "gpu_profile": _gpu_profile,
		"template": OS.has_feature("template"), "release": OS.has_feature("release"),
		"executable": OS.get_executable_path(), "user_data": OS.get_user_data_dir(),
		"note": "Four books, selected qualities, two workloads. Durable targets, injected charge, replenished threats, real paid casts/counter/ultimate."}))
	# Persist after each segment, outside its timing window. Delayed rows retain
	# their recorded context rather than inheriting the next book/quality.
	if _gpu_profile:
		for batch in _gpu_batches:
			_gpu_file.store_line(JSON.stringify(batch))
		_gpu_batches.clear()
		_gpu_file.flush()
