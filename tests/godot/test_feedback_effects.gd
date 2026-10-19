extends "res://tests/godot/test_s1_application.gd"
## Presentation fixtures use real casts and pickup completions, with a controlled battlefield.
var _gpu_frame := -1
var _ice_samples: Array[Dictionary] = []

class OriginalGrowth extends FrostGrowth:
	func step(count: int, delta: float) -> void:
		if iteration >= max_steps and surface_age >= 10.0: return
		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _pipeline)
		for i in mini(count, max_steps - iteration):
			_dispatch(list, 0, 0)
			_dispatch(list, 1, 1)
			iteration += 1
		_rd.compute_list_bind_compute_pipeline(list, _surface_pipeline)
		var pairs := maxi(1, ceili(delta * maxf(1.0, pow(float(grid) / GRID, 2.0)) / .05))
		for part in pairs:
			_surface_dispatch(list, 0, delta / (pairs * 2.0), false, part == 0)
			_surface_dispatch(list, 1, delta / (pairs * 2.0), false, false)
		surface_age += delta
		_rd.compute_list_end()

class CountedGrowth extends FrostGrowth:
	var dispatches := 0
	var enclosure_updates := 0
	func _surface_dispatch(list: int, side: int, delta: float, resetting: bool, refresh_enclosure: bool = true) -> void:
		dispatches += 1
		if refresh_enclosure and not resetting: enclosure_updates += 1
		super._surface_dispatch(list, side, delta, resetting, refresh_enclosure)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	if "--growth-reuse" in OS.get_cmdline_user_args():
		await _check_growth_reuse()
		quit(0 if failures == 0 else 1)
		return
	if "--measure" in OS.get_cmdline_user_args():
		await _measure_ice_only()
		return
	if "--defense-slow" in OS.get_cmdline_user_args():
		await _defense_slow()
		return
	evidence = "res://.temp/element-vfx-20261008/effects-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	for book_id: StringName in [&"frost", &"flame", &"storm", &"spirit"]:
		if "--fire" in OS.get_cmdline_user_args() and book_id != &"flame": continue
		var filter := ""
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--book="): filter = argument.trim_prefix("--book=")
		if not filter.is_empty() and str(book_id) != filter: continue
		var session := BattleSession.new()
		var words: Array[VocabularyEntry] = []
		for word: String in FirstVisitSetup.WORDS:
			words.append(VocabularyEntry.new(word, "表现测试"))
		session.start_baseline(book_id, words, "normal", "feedback-effects", false)
		if book_id == &"frost":
			var selection := BuildSelection.new()
			selection.book_id = book_id
			selection.assets[&"R032"] = 1
			var compiled := BuildCompiler.new().compile(selection)
			assert(compiled.diagnostics.is_empty(), str(compiled.diagnostics))
			session.install_prepared_build(compiled.build)
		for index in session.enemies.size():
			var enemy := session.enemies[index]
			enemy.position = Vector2(0.65 + index * 0.07, 0.5)
			enemy.previous_position = enemy.position
			enemy.hp_q = 2000 * BattleSession.Q
			enemy.max_hp_q = enemy.hp_q
			enemy.attack_clock = 100.0
		var options := AppSettings.new(evidence.path_join("settings.cfg"))
		options.sound = false
		options.quality = 0 if "--low" in OS.get_cmdline_user_args() else 2
		options.reduce_motion = "--reduce-motion" in OS.get_cmdline_user_args()
		var book: BookPresentation
		for candidate in ArchiveHome.BOOKS:
			if candidate.id == book_id: book = candidate
		var page := BattlePage.create(session, options, book)
		page.theme = ArchiveTheme.create(book.color)
		root.add_child(page)
		await create_timer(0.2).timeout
		for cast_index in int(BattleSession.MAIN_SPELL_CYCLES[book_id]):
			session.typing.select_target(session.enemies[0].id)
			for character in session.typing.word: session.typing.feed(character)
			if cast_index == int(BattleSession.MAIN_SPELL_CYCLES[book_id]) - 1:
				await create_timer(0.14).timeout
				await _capture(str(book_id) + "-impact")
				if book_id == &"frost":
					await create_timer(.28).timeout
					await _capture("frost-growing")
					await create_timer(.58).timeout
				else:
					await create_timer(0.86).timeout
			else:
				await create_timer(1.0).timeout
		if book_id in [&"frost", &"flame"]:
			_check(not session.runtime.fields.is_empty(), "empowered cast creates its actual field: " + str(book_id))
		for visual: SpellFieldVisual in page.visuals.rule_visuals.field_nodes.values():
			_check(bool(visual.surface.get_shader_parameter("cold")) == (book_id == &"frost"), "field material follows effect kind: " + str(book_id))
			var particle_motion := visual.particles.process_material as ParticleProcessMaterial
			if particle_motion == null:
				for binding in page.visuals.fluid._particle_bindings:
					if binding.node.get_ref() == visual.particles: particle_motion = binding.motion
			_check(particle_motion.gravity == Vector3.ZERO, "field particles have no vertical gravity")
			if visual.particles.process_material is FluidParticleFlow:
				var flow := visual.particles.process_material as FluidParticleFlow
				_check(is_equal_approx(float(flow.get_shader_parameter("sphere_radius")), particle_motion.emission_sphere_radius) and particle_motion.emission_sphere_radius > 20.0, "live fire radius reaches the fluid particle emitter after binding")
			if book_id == &"frost":
				_check(visual.ice != null and visual.ice.growth.iteration > 0, "paid frost field owns a growing lattice")
				var steps := visual.ice._steps
				paused = true
				await create_timer(.1).timeout
				_check(visual.ice._steps == steps, "pause freezes crystal growth with combat")
				paused = false
		await _capture(str(book_id) + "-field")
		_check(page.visuals.fluid.buoyancy == 0.0 and page.visuals.fluid.settling == 0.0, "battle medium has no vertical gravity: " + str(book_id))
		if book_id == &"flame" and not options.reduce_motion and options.fluid_quality > 0:
			_check(not page.visuals.fluid._spell_smoke.is_empty(), "paid fire field owns sustained fluid emission")
			var gas := page.visuals.fluid.combustion.texture.get_image()
			var peak := 0.0
			for y in gas.get_height():
				for x in gas.get_width(): peak = maxf(peak, gas.get_pixel(x,y).g)
			_check(peak > .2 and gas.get_pixel(0,0).g < .001, "fuel generates local heat with a cold exterior")
		if book_id == &"frost":
			for index in 5:
				session._emit_enemy_threat(session.enemies[0], 0.0, index, 120.0, 5.0)
				var threat: BattleThreat = session.threats.back()
				threat.position = Vector2(0.6 + index * 0.035, 0.2 + index * 0.08)
				threat.previous_position = threat.position
				threat.velocity = Vector2(-120, 60)
				threat.damage_q = 1
			await create_timer(0.4).timeout
			await _capture("hostile-light-tracers")
			for kind: StringName in [&"rune", &"ink"]:
				var pickup := session.spawn_pickup(kind)
				pickup.position = Vector2(0.6, 0.6)
				session.typing.select_target(pickup.id)
				for character in session.typing.word: session.typing.feed(character)
				await create_timer(0.05).timeout
				_check(pickup.consumed and page.visuals._pulses.any(func(pulse: Dictionary) -> bool: return pulse.kind == &"item_burst"), "pickup completion emits a visual pulse: " + str(kind))
				await _capture("pickup-" + str(kind))
				await create_timer(0.22).timeout
				await _capture("pickup-" + str(kind) + "-spread")
				await create_timer(0.36).timeout
				await _capture("pickup-" + str(kind) + "-fade")
				await create_timer(0.5).timeout
		session.resonance_q = 100 * BattleSession.Q
		session.queue_action(&"ultimate")
		await create_timer(0.32).timeout
		await _capture(str(book_id) + "-ultimate-arrival")
		await create_timer(0.8).timeout
		await _capture(str(book_id) + "-ultimate-held")
		if book_id == &"frost":
			await create_timer(1.2).timeout
			await _capture("frost-ultimate-film")
			var ice: IcePatch = page.visuals._ultimate_nodes.values()[0].ice
			var grown := ice.growth.surface_texture.get_image()
			var tips := 0
			var film := 0
			for y in grown.get_height():
				for x in grown.get_width():
					var cell := grown.get_pixel(x,y)
					if cell.a > .5 and cell.g < .1: tips += 1
					if cell.a < .5 and cell.g > .5: film += 1
			_check(tips > 0 and film > 0, "battle ice retains exposed tips and film between branches")
			await create_timer(4.2).timeout
			_check(page.visuals._ultimate_nodes.is_empty() and page.visuals.rule_visuals.field_nodes.is_empty(), "expired cold regions release their simulations")
		if book_id == &"flame" and not options.reduce_motion:
			var fluid := page.visuals.fluid
			var sampler := fluid.combustion.texture.get_rid()
			for level in [0,1,3,2]:
				fluid.set_options(level,false)
				await create_timer(.12).timeout
				_check(fluid.combustion.texture.get_rid() == sampler, "fire sampler survives flow quality switch: %d" % level)
			fluid.set_options(2,true)
			await create_timer(.1).timeout
			_check(not fluid._fire_surface.visible, "reduced motion suppresses moving combustion")
			fluid.set_options(2,false)
			await create_timer(.5).timeout
			await _capture("flame-after-options")
			await create_timer(5.5).timeout
			_check(page.visuals.fluid._spell_smoke.is_empty(), "expired paid fire regions unregister their emitters")
			await create_timer(3.5).timeout
			_check(not fluid._fire_surface.visible and fluid._fire_bursts.is_empty(), "cooled fire stops drawing and dispatching")
		page.queue_free()
		await _settle()
	print("Feedback effects: %d checks, %d failures; evidence %s" % [checks.size(), failures, evidence])
	quit(0 if failures == 0 else 1)


func _check_growth_reuse() -> void:
	for resolution in [128, 384]:
		var original := OriginalGrowth.new()
		var current := CountedGrowth.new()
		root.add_child(original)
		root.add_child(current)
		for growth: FrostGrowth in [original, current]:
			RenderingServer.call_on_render_thread(growth.configure.bind(resolution, 31415, resolution == 384))
		await RenderingServer.frame_post_draw
		for phase in 5:
			var count := 32 if phase in [0, 3] else 0
			var delta := 0.0 if phase == 2 else 1.0 / 60.0
			if phase == 4:
				for growth: FrostGrowth in [original, current]: RenderingServer.call_on_render_thread(growth.reset.bind(false))
			var previous_dispatches := current.dispatches
			var previous_enclosures := current.enclosure_updates
			for tick in 20:
				for growth: FrostGrowth in [original, current]: RenderingServer.call_on_render_thread(growth.step.bind(count, delta))
			await RenderingServer.frame_post_draw
			_check(original.texture.get_image().get_data() == current.texture.get_image().get_data(), "crystal lattice unchanged at %d phase %d" % [resolution, phase])
			_check(original.surface_texture.get_image().get_data() == current.surface_texture.get_image().get_data(), "film pixels unchanged at %d phase %d" % [resolution, phase])
			if phase == 1: _check(current.enclosure_updates == previous_enclosures, "unchanged lattice reuses enclosure")
			if phase == 2: _check(current.dispatches == previous_dispatches, "paused crystal dispatches nothing")
		original.queue_free()
		current.queue_free()
		await _settle()
	print("Growth reuse: %d checks, %d failures" % [checks.size(), failures])


func _capture(label: String) -> void:
	# Freeze at the requested effect age; the UI capture helper waits through short impacts.
	var was_paused := paused
	paused = true
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var picture := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			picture.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	picture.save_png(evidence.path_join(label + ".png"))
	pictures.append(label)
	# Consume synchronous readback/conversion time while combat remains paused.
	await RenderingServer.frame_post_draw
	paused = was_paused


func _measure_ice_only() -> void:
	evidence = "res://.temp/performance-research-20261016/ice-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var session := BattleSession.new()
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("lumen", "光")]
	session.start_baseline(&"frost", words, "normal", "ice-cost", false)
	var options := AppSettings.new(evidence.path_join("unused-settings.cfg"))
	options.sound = false
	var page := BattlePage.create(session, options, ArchiveHome.BOOKS[0])
	root.add_child(page)
	await process_frame
	await _measure_field_cost(page)
	page.queue_free()
	await process_frame
	await process_frame
	print("Ice cost measurement complete: ", evidence)
	quit()


func _measure_field_cost(page: BattlePage) -> void:
	# GPU timestamps, with frozen gameplay and no capture/readback in the sample window.
	paused = true
	var viewport := page.stage.viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var probes: Array[IcePatch] = []
	var cases: Array[Dictionary] = []
	for detail in [2, 0, 1]:
		for count in ([0, 1, 4, 14] if detail == 2 else [4]):
			cases.append({"count": count, "radius": 114.0, "quality": detail})
		for count in ([1, 4] if detail == 2 else [1]):
			cases.append({"count": count, "radius": 420.0, "quality": detail})
	var frames: Array[Dictionary] = []
	for repetition in 2:
		for case_index in cases.size():
			var config := cases[case_index]
			for index in int(config.count):
				var patch := IcePatch.new()
				page.visuals.rule_visuals.add_child(patch)
				probes.append(patch)
			for frame in 100:
				var label := "%d/%d/%d" % [repetition, case_index, frame]
				var start := Time.get_ticks_usec()
				RenderingServer.call_on_render_thread(_mark_ice.bind("ice_start/" + label))
				for index in probes.size():
					probes[index].sync_patch(Vector2(600+(index%5)*185,300+floori(index/5.0)*190),config.radius,frame/60.0,1.0,config.quality,false,index)
				RenderingServer.call_on_render_thread(_mark_ice.bind("ice_end/" + label))
				var submit_us := Time.get_ticks_usec() - start
				await RenderingServer.frame_post_draw
				frames.append({"label": label, "submit_us": submit_us, "world_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport), "world_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport)})
				RenderingServer.call_on_render_thread(_read_ice_time)
			for patch in probes: patch.queue_free()
			probes.clear()
			for drain in 6:
				await RenderingServer.frame_post_draw
				RenderingServer.call_on_render_thread(_read_ice_time)
	await process_frame
	var report := {"device": RenderingServer.get_video_adapter_name(), "viewport": str(root.size), "engine": Engine.get_version_info(), "cases": cases, "frames": frames, "compute": _ice_samples, "note": "Paused world. Each sample advances ice age by 1/60s independently of wall time; not whole-game FPS. GPU timestamp ns / 1e6, CPU timestamp us / 1e3. Labels match asynchronous results; frame ids deduplicated. Frames 10..79 cover active growth, 81..99 mainly film. Synthetic concurrency, not proof of reachable builds."}
	var file := FileAccess.open(evidence.path_join("gpu-cost.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("Frost GPU cost: ", frames.size(), " submitted frames; ", _ice_samples.size(), " timestamp intervals; ", evidence)
	RenderingServer.viewport_set_measure_render_time(viewport, false)
	paused = false


func _mark_ice(label: String) -> void:
	RenderingServer.get_rendering_device().capture_timestamp(label)


func _read_ice_time() -> void:
	var rd := RenderingServer.get_rendering_device()
	var frame := rd.get_captured_timestamps_frame()
	if frame == _gpu_frame: return
	_gpu_frame = frame
	var start := -1
	var cpu_start := -1
	var sample_label := ""
	for index in rd.get_captured_timestamps_count():
		var label := rd.get_captured_timestamp_name(index)
		if label.begins_with("ice_start/"):
			start = rd.get_captured_timestamp_gpu_time(index)
			cpu_start = rd.get_captured_timestamp_cpu_time(index)
			sample_label = label.trim_prefix("ice_start/")
		elif label == "ice_end/" + sample_label and start >= 0:
			_record_ice_interval.call_deferred({"label": sample_label, "gpu_frame": frame, "gpu_ms": float(rd.get_captured_timestamp_gpu_time(index)-start)/1000000.0, "render_cpu_ms": float(rd.get_captured_timestamp_cpu_time(index)-cpu_start)/1000.0})


func _record_ice_interval(sample: Dictionary) -> void:
	_ice_samples.append(sample)


func _defense_slow() -> void:
	evidence = "res://.temp/defense-slow-20261009/window-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	var session := BattleSession.new()
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("guard", "防御"), VocabularyEntry.new("light", "光")]
	session.start_baseline(&"flame", words, "normal", "defense-slow", false)
	var options := AppSettings.new(evidence.path_join("settings.cfg"))
	options.sound = false
	var book := ArchiveHome.BOOKS[3]
	for candidate in ArchiveHome.BOOKS:
		if candidate.id == &"flame": book = candidate
	var page := BattlePage.create(session, options, book)
	page.theme = ArchiveTheme.create(book.color)
	root.add_child(page)
	session.set_physics_process(false)
	for index in session.enemies.size():
		session.enemies[index].position = Vector2(.7 + index * .09, .38)
		session.enemies[index].previous_position = session.enemies[index].position
		session.enemies[index].word_pending = false
		session.enemies[index].word_age = 1.0
		session.enemies[index].word = "guard" if index % 2 == 0 else "light"
		session.typing.upsert_target(session.enemies[index].id, session.enemies[index].word)
	page._refresh()
	await create_timer(.3).timeout
	for style in [3, 0, 1]:
		page.visuals._spawn_item_burst(Vector2(.5, .5), style, [195.0, 520.0, 255.0, 125.0][style])
		await create_timer(.055).timeout
		var pulse: Dictionary = page.visuals._pulses.back()
		_check(is_equal_approx(float((pulse.node.material as ShaderMaterial).get_shader_parameter("radius")), [195.0, 520.0, 255.0, 125.0][style]), "burst material receives coverage independently of fixed world detail")
		await _capture(["perfect", "counter", "ink", "success"][style])
		await create_timer(.85).timeout
	await _capture("normal-time")
	session.precision_slow_remaining = 2.0
	page.visuals._spawn_item_burst(Vector2(.5, .5), 0, 195.0)
	await create_timer(.35).timeout
	await _capture("slow-time")
	var clock := BattleVisualClock.find(page.visuals)
	page.visuals._spawn_particles(Vector2(.42, .5), Color("ffe3a2"), .2, true)
	var slow_mote: GPUParticles2D = clock._particles.back()
	_check(clock._particles.size() > 0, "native particle clock includes nested burst layers")
	for particles in clock._particles:
		_check(is_equal_approx(particles.speed_scale, .1), "native particles share 0.1 world rate")
	var before := page.visuals.fluid._clock
	var real_seconds := 0.0
	for frame in 20:
		await process_frame
		real_seconds += page.get_process_delta_time()
	var ratio := (page.visuals.fluid._clock - before) / real_seconds
	_check(ratio > .075 and ratio < .125, "fluid advances at world rate: %.4f" % ratio)
	await create_timer(.8).timeout
	_check(is_instance_valid(slow_mote), "one-shot particles survive their unscaled lifetime during slow motion")
	var maximum_error := 0.0
	for y in 9:
		for x in 15:
			var point := Vector2(x / 14.0, y / 8.0) * page.size
			var warped := page.slow_lens.project(point) / page.size * 2.0 - Vector2.ONE
			var r2 := warped.length_squared() * .5
			var sampled := (warped * (1.0 - page.slow_lens.bend * r2 * r2) + Vector2.ONE) * .5 * page.size
			maximum_error = maxf(maximum_error, sampled.distance_to(point))
	_check(maximum_error < .03, "word anchor inverse lens error below .03px: %.5f" % maximum_error)
	_check(page.get_children().find(page.slow_lens) < page.get_children().find(page.hud), "HUD renders after world lens")
	page.slow_lens.update_effect(session, .3, true, options.quality)
	_check(page.slow_lens.bend == 0.0 and page.slow_lens.visible, "reduced motion keeps cool tint without lens movement")
	session.precision_slow_remaining = 0.0
	await create_timer(.9).timeout
	_check(not page.slow_lens.visible and page.slow_lens.capture.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "normal time releases the screen copy")
	for particles in clock._particles:
		_check(is_equal_approx(particles.speed_scale, 1.0), "particle rate restores after slow time")
	_check(not is_instance_valid(slow_mote), "one-shot particles release after their scaled simulation finishes")
	print("Defense slow presentation: %d checks, %d failures; %s" % [checks.size(), failures, evidence])
	page.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
