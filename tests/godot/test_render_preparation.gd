extends SceneTree
## Rendering and lifetime regression checks; no player profile or performance comparison.

signal compute_checked
var failures := 0
var checks: Array[String] = []
var _compute_shared := false
var _compute_isolated := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if RenderingServer.get_rendering_device() == null:
		push_error("Render preparation verification requires a graphical RenderingDevice.")
		quit(1)
		return
	var feedback := load("res://ui/scenes/loading_feedback.tscn").instantiate() as LoadingFeedback
	root.add_child(feedback)
	feedback.size = Vector2(400, 90)
	var preparation := load("res://ui/scenes/render_preparation.tscn").instantiate() as RenderPreparation
	root.add_child(preparation)
	await preparation.prepare(feedback)
	_check(preparation._programs.size() == 4, "four retained compute programs")
	_check(preparation.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "preparation viewport stops rendering")
	var shader_paths: Dictionary[String, bool] = {}
	for material in preparation._catalog:
		if material is ShaderMaterial:
			shader_paths[(material as ShaderMaterial).shader.resource_path] = true
	_check(shader_paths.size() == 50 and shader_paths.has("res://ui/materials/crystal_sheet.gdshader") and shader_paths.has("res://ui/materials/battle_slow_lens.gdshader") and shader_paths.has("res://ui/materials/book_seal.gdshader") and shader_paths.has("res://ui/materials/ritual_light.gdshader") and shader_paths.has("res://ui/materials/ritual_atmosphere.gdshader") and shader_paths.has("res://ui/materials/engraved_gold.gdshader"), "all 50 authored canvas and particle shaders, including crystal sheets, are covered (actual: %d)" % shader_paths.size())
	RenderingServer.call_on_render_thread(_check_compute)
	await compute_checked
	_check(_compute_shared, "ice instances reuse retained shader and pipeline")
	_check(_compute_isolated, "ice instances own separate growth images")
	for path: String in ["burst_splinters", "spell_motes", "spell_field_visual"]:
		var scene := load("res://ui/scenes/%s.tscn" % path) as PackedScene
		var first := scene.instantiate()
		var second := scene.instantiate()
		var a := first as GPUParticles2D if first is GPUParticles2D else first.get_node("Motes") as GPUParticles2D
		var b := second as GPUParticles2D if second is GPUParticles2D else second.get_node("Motes") as GPUParticles2D
		_check(a.process_material != b.process_material, path + " isolates particle parameters")
		if a.material is ShaderMaterial:
			_check(a.material != b.material, path + " isolates shader uniforms")
		first.free()
		second.free()
	for reduced: bool in [false, true]:
		var startup := load("res://ui/scenes/departure_ritual.tscn").instantiate() as DepartureRitual
		startup.startup = true
		startup.reduced_motion = reduced
		root.add_child(startup)
		startup.feedback.update_stage("画面准备完成", 69, 69)
		startup.feedback.update_stage("正在载入书库", 0, 0)
		_check(is_equal_approx(startup.get_node("LoadingRunes/RingLight/Rotor/Progress").value, 100.0), "unknown-length loading preserves completed rune ring (reduced=%s)" % reduced)
		startup.queue_free()
		await process_frame
		var ritual := load("res://ui/scenes/departure_ritual.tscn").instantiate() as DepartureRitual
		ritual.book = load("res://game/content/books/frost.tres")
		ritual.reduced_motion = reduced
		var events := {"covered": 0, "completed": 0}
		ritual.covered.connect(func() -> void: events.covered += 1)
		ritual.completed.connect(func() -> void: events.completed += 1)
		root.add_child(ritual)
		await create_timer(0.6 if reduced else 2.6).timeout
		_check(events.covered == 1 and events.completed == 0, "departure waits beyond animation duration (reduced=%s)" % reduced)
		_check(ritual.feedback.visible, "waiting feedback remains visible")
		ritual.release()
		await ritual.completed
		await process_frame
		_check(events.completed == 1, "departure completes exactly once")
	await _check_effects()
	feedback.queue_free()
	preparation.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://.temp/render-preparation"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var report := FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures": failures, "checks": checks}, "\t"))
	report.close()
	print("Render preparation checks: %d passed, %d failed" % [checks.size() - failures, failures])
	quit(0 if failures == 0 else 1)


func _check_effects() -> void:
	var choice := load("res://ui/scenes/relic_reward_choice.tscn").instantiate() as RelicRewardChoice
	choice.definition = load("res://game/content/build/R001.tres")
	root.add_child(choice)
	_check(choice.get_node("Content/Title").text == choice.definition.title, "native reward binds its definition")
	choice.queue_free()
	for book_id: StringName in [&"frost", &"flame", &"storm", &"spirit"]:
		var session := BattleSession.new()
		var words: Array[VocabularyEntry] = [VocabularyEntry.new("lumen", "光"), VocabularyEntry.new("ember", "余烬"), VocabularyEntry.new("quill", "羽笔")]
		session.start_baseline(book_id, words, "normal", "render-preparation", false)
		for index in session.enemies.size():
			var enemy := session.enemies[index]
			enemy.position = Vector2(0.65 + index * 0.07, 0.5)
			enemy.previous_position = enemy.position
			enemy.hp_q = 2000 * BattleSession.Q
			enemy.max_hp_q = enemy.hp_q
			enemy.attack_clock = 100.0
		var options := AppSettings.new("res://.temp/render-preparation/settings.cfg")
		options.sound = false
		var book: BookPresentation
		for candidate in ArchiveHome.BOOKS:
			if candidate.id == book_id: book = candidate
		var page := BattlePage.create(session, options, book)
		root.add_child(page)
		await create_timer(0.2).timeout
		for cast_index in int(BattleSession.MAIN_SPELL_CYCLES[book_id]):
			session.typing.select_target(session.enemies[0].id)
			for character in session.typing.word: session.typing.feed(character)
			await create_timer(1.0).timeout
		if book_id in [&"frost", &"flame"]:
			_check(not page.visuals.rule_visuals.field_nodes.is_empty(), "native paid field renders: " + str(book_id))
		session.resonance_q = 100 * BattleSession.Q
		session.queue_action(&"ultimate")
		await create_timer(0.5).timeout
		_check(not page.visuals._ultimate_nodes.is_empty(), "ultimate renders: " + str(book_id))
		if book_id == &"frost":
			for style in 3:
				page.visuals._spawn_item_burst(Vector2(0.5, 0.5), style, 140.0)
				await create_timer(0.05).timeout
				_check(page.visuals._pulses.any(func(pulse: Dictionary) -> bool: return pulse.kind == &"item_burst"), "native burst renders: %d" % style)
				await create_timer(0.7).timeout
			_check(not page.visuals._pulses.any(func(pulse: Dictionary) -> bool: return pulse.kind == &"item_burst"), "burst particles expire")
		page.queue_free()
		await process_frame
		await RenderingServer.frame_post_draw


func _check_compute() -> void:
	var first := FrostGrowth.new()
	var second := FrostGrowth.new()
	first.configure(16, 1)
	second.configure(16, 2)
	_compute_shared = first._program == second._program and first._surface_program == second._surface_program
	_compute_isolated = first.texture.texture_rd_rid != second.texture.texture_rd_rid and first.surface_texture.texture_rd_rid != second.surface_texture.texture_rd_rid
	first.step(2, 0.016)
	second.step(2, 0.016)
	first.dispose()
	second.dispose()
	first.free()
	second.free()
	compute_checked.emit.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks.append(message)
	if not condition:
		failures += 1
		push_error(message)
