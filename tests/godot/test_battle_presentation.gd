extends SceneTree
## Window-only M2 timeline: each book is captured in flight, at impact and in its ultimate.

var evidence: String
var reduced: bool = false
var quality: int = 2
var audio_only: bool = false
var recording: bool = false
var peak_db: float = -100.0
var max_voices: int = 0
var current_audio: BattleAudio


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Battle presentation requires the actual HDR renderer")
	_check_motion_tools()
	evidence = "res://.temp/godot-m2/presentation-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	if "--words-only" in OS.get_cmdline_user_args():
		await _check_headwords()
		print("Headword presentation: " + evidence)
		quit()
		return
	var selected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--book="):
			selected = argument.trim_prefix("--book=")
		if argument == "--reduce-motion":
			reduced = true
		if argument == "--low":
			quality = 0
		if argument == "--medium":
			quality = 1
		if argument == "--audio-only":
			audio_only = true
		if argument == "--movie":
			recording = true
	process_frame.connect(_sample_audio)
	for book: BookPresentation in ArchiveHome.BOOKS:
		if not selected.is_empty() and str(book.id) != selected:
			continue
		var session := BattleSession.new()
		var words: Array[VocabularyEntry] = [VocabularyEntry.new("lumen", "光"), VocabularyEntry.new("ember", "余烬"), VocabularyEntry.new("quill", "羽笔")]
		session.start_baseline(book.id, words, "normal", "presentation", false)
		for index in session.enemies.size():
			var enemy := session.enemies[index]
			enemy.position = [Vector2(0.70, 0.50), Vector2(0.76, 0.52), Vector2(0.80, 0.43)][index]
			enemy.previous_position = enemy.position
			enemy.hp_q = 120 * BattleSession.Q
			enemy.max_hp_q = enemy.hp_q
			enemy.attack_clock = 8.0
		var settings := AppSettings.new(evidence.path_join("settings.cfg"))
		settings.sound = audio_only or recording
		AudioServer.set_bus_volume_db(0, linear_to_db(settings.volume))
		settings.reduce_motion = reduced
		settings.quality = quality
		var page := BattlePage.create(session, settings, book)
		page.theme = ArchiveTheme.create(book.color)
		root.add_child(page)
		current_audio = page.audio
		var router := InputRouter.new()
		router.typing = session.typing
		router.configure(InputRouter.Context.TYPING)
		router.action_requested.connect(session.queue_action)
		page.add_child(router)
		await _advance(0.15)
		if "--ultimates-only" in OS.get_cmdline_user_args():
			session.resonance_q = BattleSession.ULTIMATE_COST_Q
			session.queue_action(&"ultimate")
			await _advance(0.4)
			await _capture(str(book.id) + "-ultimate")
			await _advance(1.0)
			await _capture(str(book.id) + "-ultimate-sustain")
			assert(not page.visuals._ultimate_nodes.is_empty())
			page.queue_free()
			current_audio = null
			await process_frame
			continue
		assert(page.visuals.size == Vector2(1920, 1080))
		assert(page.stage.viewport.size == root.size)
		if reduced:
			assert(page.visuals.camera_offset == Vector2.ZERO)
		var actors := page.visuals._actors.values()
		assert(actors[0].surface != actors[1].surface and actors[0].surface != page.visuals._player.surface, "Hit, freeze and dissolve materials must belong to individual actors")
		await _capture(str(book.id) + "-ready")
		session.typing.select_target(session.enemies[0].id)
		for character in session.typing.word:
			var key := InputEventKey.new()
			key.keycode = character.to_upper().unicode_at(0) as Key
			key.unicode = character.unicode_at(0)
			key.pressed = true
			Input.parse_input_event(key)
			await _advance(0.05)
			if session.typing.progress == 2:
				await _capture(str(book.id) + "-typing")
		await _advance(0.1 if book.id != &"storm" else 0.03)
		if book.id != &"storm":
			assert(session.enemies[0].word_pending and not page.enemy_words[session.enemies[0].id].visible, "In-flight primary hides its consumed word")
		await _capture(str(book.id) + "-flight")
		await _advance(0.35)
		await _capture(str(book.id) + "-impact")
		if book.id != &"spirit":
			await _advance(0.3)
			session.completed_words = int(BattleSession.MAIN_SPELL_CYCLES[book.id]) - 1
			session.typing.select_target(session.enemies[0].id)
			for character in session.typing.word:
				session.typing.feed(character)
			await _advance(0.08)
			await _capture(str(book.id) + "-empowered-flight")
			await _advance(0.32)
			await _capture(str(book.id) + "-empowered-impact")
		if book.id == &"spirit":
			session.completed_words = 2
			session.typing.select_target(session.enemies[0].id)
			for character in session.typing.word:
				session.typing.feed(character)
			await _advance(0.65)
			await _capture("spirit-cross")
			session.typing.select_target(session.enemies[0].id)
			for character in session.typing.word:
				session.typing.feed(character)
			await _advance(0.4)
			assert(session.spirit_blade_count() == 3)
			await _capture("spirit-three-summons")
			await _advance(0.65)
			await _capture("spirit-dive-return")
			for enemy in session.enemies:
				enemy.attack_clock = 100.0
				enemy.frozen_time = 30.0
			await _advance(3.0)
			await _capture("spirit-returned")
			await _advance(session.spirit_time - 0.4)
			await _capture("spirit-silence-fade")
			await _advance(0.8)
			assert(session.spirit_blade_count() == 0)
			await _capture("spirit-silence-empty")
		if book.id == &"frost":
			var shooter := session.enemies[1]
			shooter.position = Vector2(0.62, 0.5)
			shooter.previous_position = shooter.position
			shooter.impulse = Vector2.ZERO
			shooter.frozen_time = 0.0
			shooter.aimed_position = session.player_position
			shooter.aiming = true
			shooter.attack_clock = 0.65
			await _advance(0.15)
			await _capture("defense-warning")
			await _advance(0.62)
			await _capture("defense-projectiles")
			await _advance(0.2)
			session.queue_action(&"parry")
			await _advance(0.12)
			await _capture("defense-parry")
			assert(session.threats.any(func(threat: BattleThreat) -> bool: return threat.reflected), "Defense timeline must show a real reflected projectile")
			await _advance(0.9)
			var melee := session.enemies[0]
			melee.position = session.player_position + Vector2(80.0, 0) / BattleSession.ARENA_SIZE
			melee.previous_position = melee.position
			melee.impulse = Vector2.ZERO
			melee.frozen_time = 0.0
			melee.hp_q = 100 * BattleSession.Q
			melee.max_hp_q = melee.hp_q
			melee.attack_clock = 0.0
			melee.aiming = false
			melee.stagger_time = 0.0
			melee.melee_strike = 0.0
			melee.melee_recovery = 0.0
			await _advance(0.55)
			assert(melee.aiming, "Melee must expose its committed warning before a parry")
			await _capture("defense-melee-warning")
			session.queue_action(&"parry")
			await _advance(0.23)
			assert(melee.counter_push_time > 0.0 and melee.hp_q == 68 * BattleSession.Q)
			for first in page._feedback_labels.size():
				assert(page._feedback_labels[first].get_line_count() == 1, "Damage and defense feedback must remain on one line")
				for second in range(first + 1, page._feedback_labels.size()):
					assert(not page._feedback_labels[first].get_rect().intersects(page._feedback_labels[second].get_rect()), "Rapid reflected hits retain separate readable values")
			await _capture("defense-contact")
			await _advance(0.28)
			assert(((melee.position - session.player_position) * BattleSession.ARENA_SIZE).length() > 200.0, "Contact counter must visibly push the attacker away")
			await _capture("defense-push")
			session.queue_action(&"dodge_up")
			await _advance(0.08)
			await _capture("defense-dodge")
			await _advance(0.12)
			await _capture("defense-landing")
		session.resonance_q = BattleSession.ULTIMATE_COST_Q
		session.queue_action(&"ultimate")
		await _advance(0.4)
		await _capture(str(book.id) + "-ultimate")
		assert(not page.visuals._ultimate_nodes.is_empty(), "Ultimate field reads the committed timeline")
		assert(page.ultimate_indicator.get_node("Value").text.ends_with("s"), "Active ultimate displays remaining time instead of a misleading empty charge")
		await _advance(1.0)
		await _capture(str(book.id) + "-ultimate-sustain")
		if reduced or quality == 0:
			assert(not page.visuals._wave_plane.visible, "Reduced motion and low quality omit refraction")
		if reduced:
			assert(page.visuals.camera_offset == Vector2.ZERO and page.visuals._player._hit_motion.position == Vector2.ZERO, "Reduced motion suppresses impact and camera displacement")
		if book.id == &"frost":
			paused = true
			var before := session.elapsed
			root.size = Vector2i(1440, 900)
			await process_frame
			await process_frame
			assert(session.elapsed == before, "Resize while paused cannot advance combat")
			assert(page.stage.viewport.size == root.size, "World renders at the same resolution as HUD")
			assert(is_equal_approx(page.visuals.scale.x, page.visuals.scale.y))
			await _capture("frost-paused-16x10")
			paused = true
			root.size = Vector2i(1440, 810)
			await process_frame
			await process_frame
			assert(page.stage.viewport.size == root.size)
			await _capture("frost-paused-16x9")
			root.size = Vector2i(1920, 1080)
			paused = false
			var edge_enemy := session.enemies[2]
			edge_enemy.position = Vector2(0.97, 0.5)
			edge_enemy.previous_position = edge_enemy.position
			edge_enemy.impulse = Vector2.ZERO
			await _advance(0.1)
			assert(not page.enemy_words[edge_enemy.id].visible, "Cold edge has no readable target word")
			await _capture("frost-cold-edge")
		settings.quality = 0
		settings.reduce_motion = true
		page.apply_options()
		assert(not page.stage.environment.glow_enabled and not page.visuals._wave_plane.visible)
		page.queue_free()
		current_audio = null
		await process_frame
	if audio_only:
		assert(peak_db > -100.0 and peak_db < 0.0, "Battle audio must be audible without clipping at its default mix")
		assert(max_voices <= BattleAudio.MAX_VOICES)
		print("Battle mix: peak %.2f dBFS; max %d concurrent voices" % [peak_db, max_voices])
	print("Battle presentation timeline: " + evidence)
	quit()


func _check_headwords() -> void:
	var session := BattleSession.new()
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("transparent", "透明的；清澈的；显而易见的；易于识破的；可以看穿的；没有隐藏条件的；光线可以穿透的"), VocabularyEntry.new("ember", "余烬"), VocabularyEntry.new("quill", "")]
	session.start_baseline(&"frost", words, "normal", "headwords", false)
	for i in session.enemies.size():
		var enemy := session.enemies[i]
		enemy.position = Vector2(0.58+i*0.10, 0.48)
		enemy.previous_position = enemy.position
		enemy.word = words[i].word
		enemy.word_age = 0.4
		enemy.attack_clock = 20.0
	session.step(1.0/60.0)
	for enemy in session.enemies:
		enemy.word_age = 0.4
	var settings := AppSettings.new(evidence.path_join("settings.cfg"))
	settings.sound = false
	settings.show_meaning = true
	var page := BattlePage.create(session, settings, ArchiveHome.BOOKS[0])
	page.theme = ArchiveTheme.create(ArchiveHome.BOOKS[0].color)
	root.add_child(page)
	session.set_physics_process(false)
	session.typing.select_target(session.enemies[0].id)
	session.typing.feed("t")
	session.step(1.0/60.0)
	await _advance(0.2)
	var label := page.enemy_words[session.enemies[0].id]
	assert(label.meaning_lines.size() == 2 and label.meaning_lines[-1].ends_with("…"), "Long meaning is two measured lines with ellipsis")
	assert(page.enemy_words[session.enemies[2].id].meaning_lines.is_empty(), "Missing meaning has no empty row")
	assert(label.size.y > page.enemy_words[session.enemies[2].id].size.y and label.z_index == 1, "Meaning participates in label bounds; selection paints above neighbours")
	await _capture("headwords-on")
	settings.show_meaning = false
	page.apply_options()
	assert(not label.meaning_label.visible and page.hint_label.visible, "Headword option does not toggle the bottom cast meaning")
	await _capture("headwords-off")
	settings.show_meaning = true
	page.apply_options()
	for at: Vector2 in [Vector2(0.98,0.5), Vector2(0.02,0.04), Vector2(0.98,0.04), Vector2(0.02,0.96), Vector2(0.98,0.96)]:
		session.enemies[0].position = at
		session.enemies[0].previous_position = at
		session.step(1.0/60.0)
		await _advance(0.1)
		assert(label.visible and label.modulate.a > 0.9 and session.typing.progress == 1, "Locked edge retains the complete readable label and typing progress")
		assert(Rect2(Vector2.ZERO,page.size).encloses(label.get_rect()), "Word and meaning remain together within the visible arena")
		# Check occupied controls, not a rectangle spanning their intentional empty space.
		for hud_path in ["BattleHeading", "PlayerHealth", "HealthValue", "HealthTrack", "PlayerShield", "ShieldTrack", "Dodge", "BattleProgress", "BookCadence", "BattleChapter", "BattleWave", "BattleTimer", "Pause"]:
			var control := page.get_node("HUD/" + hud_path) as Control
			assert(not label.get_global_rect().intersects(control.get_global_rect()), "Edge label overlaps HUD: " + hud_path)
		await _capture("headwords-edge-%d-%d" % [roundi(at.x*100), roundi(at.y*100)])
	await _capture("headwords-locked-edge")
	page.queue_free()
	await process_frame


func _check_motion_tools() -> void:
	var tail := MotionTrail.build(PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(40, 0)]), Vector2(40, 0), Vector2(30, 0), 100.0, false, 12)
	assert(tail[-1] == Vector2(30, 0), "Tail ends at the displayed head")
	for point in tail:
		assert(point.x <= 30.0, "Interpolation cannot leave a future tail point ahead of the head")
	var curve := MotionTrail.build(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(12, 0), Vector2(13, 24), Vector2(40, 24)]), Vector2(40, 24), Vector2(35, 24), 30.0, true, 64)
	var length := 0.0
	for index in curve.size():
		assert(curve[index].is_finite())
		if index > 0:
			length += curve[index - 1].distance_to(curve[index])
	assert(length <= 30.01 and curve.size() <= 64 and curve[-1] == Vector2(35, 24))
	var single := DampedMotion.new()
	var stepped := DampedMotion.new()
	single.kick(Vector2(3, 4), 3.0)
	stepped.kick(Vector2(3, 4), 3.0)
	assert(is_equal_approx(single.position.length(), 3.0))
	single.advance(0.2, 6.0)
	for frame in 12:
		stepped.advance(1.0 / 60.0, 6.0)
	assert(single.position.distance_to(stepped.position) < 0.0001 and single.velocity.distance_to(stepped.velocity) < 0.0001, "Analytic damping is independent of render frame subdivision")
	stepped.reset()
	assert(stepped.position == Vector2.ZERO and stepped.velocity == Vector2.ZERO)


func _sample_audio() -> void:
	if audio_only and current_audio != null:
		peak_db = maxf(peak_db, maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0)))
		max_voices = maxi(max_voices, current_audio._voices.size())


func _advance(seconds: float) -> void:
	for frame in ceili(seconds * 60.0):
		await physics_frame
	await process_frame


func _capture(label: String) -> void:
	if audio_only or recording:
		paused = false
		return
	paused = true
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			image.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	image.save_png(evidence.path_join(label + ".png"))
	print("Captured " + label)
	await process_frame
	paused = false
