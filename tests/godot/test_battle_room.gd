extends SceneTree
## Entire normal room through the application and physical-key router; no injected combat income.

var app: KeyabyssApp
var evidence: String
var failures: int = 0
var events: Dictionary[StringName, int] = {}
var selected_book: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	evidence = "res://.temp/godot-m2/room-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--book="):
			selected_book = argument.trim_prefix("--book=")
	root.size = Vector2i(1920, 1080)
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.sound = DisplayServer.get_name() != "headless"
	app.settings.ambience = DisplayServer.get_name() != "headless"
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	for index in ArchiveHome.BOOKS.size():
		var book: BookPresentation = ArchiveHome.BOOKS[index]
		if not selected_book.is_empty() and selected_book != str(book.id):
			continue
		app.archive.select_book(index)
		app.settings.difficulty = "normal"
		app.settings.run_seed = "m2-room"
		app._start_battle()
		if DisplayServer.get_name() != "headless":
			await create_timer(0.65).timeout
			await _capture(str(book.id) + "-departure-cover")
		await app.departure.completed
		var session := app.battle.session
		events.clear()
		session.event_committed.connect(_record)
		var seen_wave := 0
		var did_pause := false
		var captured_ultimate := false
		for frame in 10800:
			await physics_frame
			await process_frame
			if session.result != 0:
				break
			if session.wave != seen_wave:
				seen_wave = session.wave
				await _capture("%s-wave-%d" % [book.id, seen_wave])
			if session.elapsed > 1.0 and not did_pause:
				did_pause = true
				_key(KEY_ESCAPE)
				await process_frame
				var before := session.elapsed
				_check(app.route == "pause" and paused, "Escape pauses the room")
				app._settings_page("pause")
				await process_frame
				app.settings.quality = 1
				app.settings.reduce_motion = true
				app._pause()
				await process_frame
				_check(session.elapsed == before, "Settings preserve fixed-step pause")
				app._resume()
				_check(app.battle.visuals.reduced_motion and app.battle.visuals.quality == 1, "Resume applies live options")
				app.settings.quality = 2
				app.settings.reduce_motion = false
				app.battle.apply_options()
			if session.elapsed < 7.0:
				_defend(session)
				continue
			_defend(session)
			if session.resonance_q >= BattleSession.ULTIMATE_COST_Q:
				_key(KEY_SHIFT)
				_key(KEY_SHIFT, 0, false)
			if not captured_ultimate and events.get(&"ultimate", 0) > 0:
				captured_ultimate = true
				for tick in 12:
					await physics_frame
				await _capture(str(book.id) + "-earned-ultimate")
			if frame % 9 == 0:
				if session.typing.target_id == &"":
					_key(KEY_TAB)
				if session.typing.target_id != &"":
					var word := session.typing.word.replace(" ", "")
					var character := word[session.typing.progress]
					_key(character.to_upper().unicode_at(0), character.unicode_at(0))
		if session.result == 0:
			print("INCOMPLETE ROOM: route=%s context=%s input=%s progress=%s targets=%s" % [app.route, app.router.context, session.typing.word, session.typing.progress, session.typing._targets])
			for enemy in session.enemies:
				if enemy.alive(): print("LIVING: %s HP=%s position=%s locked=%s pending=%s frozen=%s stagger=%s" % [enemy.id, enemy.hp_q, enemy.position, enemy.combat_locked, enemy.word_pending, enemy.frozen_time, enemy.stagger_time])
		_check(session.result == 1 and session.wave == 3 and session.enemies.size() == 9, "%s completes all three normal waves" % book.id)
		_check(events.get(&"ultimate", 0) > 0 and session.manual_characters >= 20, "%s earns its ultimate from routed input" % book.id)
		_check(events.get(&"empowered", 0) > 0, "%s reaches its main-spell cadence" % book.id)
		_check(app.route == "result" and app.battle.visible, "Result overlays the finished arena")
		_check(root.gui_get_focus_owner() == null, "Combat and result do not acquire implicit keyboard focus")
		print("ROOM %s: result=%d time=%.2f characters=%d words=%d HP=%d events=%s" % [book.id, session.result, session.elapsed, session.manual_characters, session.completed_words, ceili(float(session.player_hp_q) / BattleSession.Q), events])
		for tick in 45:
			await process_frame
		await _capture(str(book.id) + "-victory")
		app._start_battle()
		await app.departure.completed
		await process_frame
		_check(app.battle.session.wave == 1 and app.battle.session.manual_characters == 0, "Retry starts a fresh room")
		app._home()
		await process_frame
		_check(app.route == "home" and app.battle == null and not paused, "Return restores the archive")
	# Observe natural incoming attacks, without reducing player health or changing enemies.
	app._start_battle()
	await app.departure.completed
	for frame in 14400:
		await physics_frame
		await process_frame
		if app.battle.session.result != 0:
			break
	_check(app.battle.session.result == -1 and app.route == "result", "Unanswered attacks reach defeat exactly through the room owner")
	await _capture("defeat")
	print("Battle room: %d failure(s); evidence %s" % [failures, evidence])
	app._home()
	app.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit", 0 if failures == 0 else 1)


func _defend(session: BattleSession) -> void:
	if session.dodge_window > 0.0:
		return
	var imminent := false
	for threat in session.threats:
		var nearest := Geometry2D.get_closest_point_to_segment(session.player_position * BattleSession.ARENA_SIZE, threat.position * BattleSession.ARENA_SIZE, threat.position * BattleSession.ARENA_SIZE + threat.velocity * 0.12)
		if nearest.distance_to(session.player_position * BattleSession.ARENA_SIZE) < 58.0:
			imminent = true
	for enemy in session.enemies:
		if enemy.alive() and enemy.kind == &"nib" and enemy.aiming and enemy.attack_clock < 0.15:
			imminent = true
	if imminent:
		if session.parry_cooldown <= 0.0:
			_key(KEY_SPACE)
		elif session.dodge_charges >= 1.0 and session.parry_window <= 0.0:
			_key(KEY_ALT)


func _record(event: Dictionary) -> void:
	events[event.kind] = events.get(event.kind, 0) + 1
	if event.kind == &"cast" and event.get("empowered", false):
		events[&"empowered"] = events.get(&"empowered", 0) + 1
	if event.kind == &"enemy_attack":
		events[event.outcome] = events.get(event.outcome, 0) + 1


func _key(code: int, unicode: int = 0, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = pressed
	Input.parse_input_event(event)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var was_paused := paused
	paused = true
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var picture := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			picture.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	picture.save_png(evidence.path_join(label + ".png"))
	paused = was_paused


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
