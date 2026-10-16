extends SceneTree
## Real application window, Unicode keyboard events and isolated persisted services.

var app: KeyabyssApp
var evidence: String
var failures := 0
var checks: Array[String] = []
var rooms: Array[Dictionary] = []
var pictures: PackedStringArray = []
var seen_rewards: Dictionary = {}
var seen_routes: Dictionary = {}
var seen_boss := false
var reported_rooms: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var evidence_base := "user://verification" if "--package-check" in OS.get_cmdline_user_args() else "res://.temp/shrink/flow"
	evidence = evidence_base.path_join("application-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.settings.book_id = "frost"
	app.settings.difficulty = "normal"
	app.settings.run_seed = "s1-application"
	app.settings.progressive = false
	app.settings.reduce_motion = "--reduce-motion" in OS.get_cmdline_user_args()
	if "--low" in OS.get_cmdline_user_args():
		app.settings.quality = 0
		app.settings.fluid_quality = 0
	app.settings.fullscreen = false
	app.settings.sound = false
	app.settings.ambience = false
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	var words := app.vocabulary.parse_import("word,meaning\nash,灰\nink,墨\nfrost,霜\nspirit,灵\narchive,档案\nthunder,雷", "flow.csv")
	app.settings.vocabulary_id = app.vocabulary.save_import(words)
	_check(not app.settings.vocabulary_id.is_empty(), "isolated vocabulary is saved through the real import service")
	_check(app.settings.save_settings(), "isolated settings persist before application startup")
	app.profile_base_path = evidence.path_join("profiles")
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	if "--package-check" in OS.get_cmdline_user_args():
		print("Packaged resources loaded with external test runner; debug engine: ", OS.is_debug_build())
		_check(root.get_node_or_null("McpInteractionServer") == null, "standalone runtime has no MCP bridge")
		_check(not ResourceLoader.exists("res://tests/godot/test_s2_run.gd") and not ResourceLoader.exists("res://development/build_lab.tscn"), "development scenes and tests are excluded from the package")
		_check(BuildCatalog.new().definitions.size() == 62, "all four books and 58 dynamic relic resources load from the package")
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vocabulary/index.json"))
		for book in index.books:
			_check(FileAccess.file_exists("res://assets/vocabulary/%s.json" % book.id), "packaged vocabulary: " + str(book.id))
	await create_timer(0.7).timeout
	_check(app.route == "home" and app.profile.manual_characters == 0 and app.profile.records.is_empty(), "application starts on the archive with an isolated fresh normal profile")
	await _capture("01-home")
	if "--feedback" in OS.get_cmdline_user_args():
		await _type("profile")
		_check(not app.commands.has("mode"), "growth has no visible God toggle")
		await _capture("10-growth")
		await _type("back")
		await _type("vocab")
		await _capture("11-vocabulary")
		await _key(KEY_ESCAPE)
	await _type("guide")
	_check(app.route == "guide", "guide opens through a Unicode menu command")
	var guide_text := _labels(app.page)
	_check(not _contains_retired(guide_text), "guide contains no retired talent, secondary-book or contract entry")
	await _capture("02-guide")
	await _type("back")
	_check(app.route == "home", "guide back command returns to archive")
	await _type("relics")
	_check(app.route == "relics", "relic codex opens through its formal command")
	_check(not _contains_retired(_labels(app.page)), "codex contains no retired configuration or contract entry")
	await _capture("03-relics")
	await _type("back")
	_check(app.route == "home", "codex back command returns to archive")
	await _type("start")
	_check(app.route == "prepare", "start opens preparation without a talent page")
	await _type("normal")
	await _type("start")
	_check(app.route in ["departure", "battle"], "main book preparation directly departs")
	var original_run := app.run.run_id
	if "--ui-only" in OS.get_cmdline_user_args():
		for iteration in 1800:
			await physics_frame
			if app.route == "battle" and app.battle.session.elapsed >= 8.0: break
		await _capture("09-battle-words")
		app._home()
		await _settle()
		await _type("profile")
		await _capture("10-growth")
		app.queue_free()
		await _settle()
		print("S2 settled UI: %d checks, %d failures; evidence %s" % [checks.size(), failures, evidence])
		quit(0 if failures == 0 else 1)
		return
	var previous_room := 0
	var frame := 0
	var last_battle: BattleSession = null
	for iteration in 60000:
		await physics_frame
		await process_frame
		if app.route == "pause":
			await _type("resume")
			continue
		if app.route in ["departure", "prepare"]: continue
		if app.route == "reward":
			if is_instance_valid(app.battle) and app.battle.session.result != 0: _report(app.battle.session, app.run.room_serial)
			var id: String = app.run.offer.id
			if not seen_rewards.has(id):
				seen_rewards[id] = true
				if pictures.find("04-reward") < 0: await _capture("04-reward")
				_check(app.run.offer.candidates.size() > 0 and app.commands.has("take1"), "formal reward offers a keyboard-selectable actual relic")
				if "--feedback" in OS.get_cmdline_user_args() and seen_rewards.size() == 1:
					app._show_reward_detail(app.run.compiler.catalog.get_definition(StringName(app.run.offer.candidates[0])))
					await _type("1")
					_check(app.run.offer.id == id, "number key cannot choose underneath reward detail")
					await _key(KEY_ESCAPE)
			var choice := 0
			for relic in ["R001", "R016", "R012", "R019", "R039", "R024"]:
				if relic in app.run.offer.candidates:
					choice = app.run.offer.candidates.find(relic)
					break
			await _type(str(choice + 1) if "--feedback" in OS.get_cmdline_user_args() else "take%d" % (choice + 1))
			if "--feedback" in OS.get_cmdline_user_args(): _check(app.run.offer.get("id", "") != id or app.route != "reward", "number key immediately claims the offered relic")
			continue
		if app.route == "route":
			if is_instance_valid(app.battle) and app.battle.session.result != 0: _report(app.battle.session, app.run.room_serial)
			var serial := app.run.room_serial
			if not seen_routes.has(serial):
				seen_routes[serial] = true
				await _capture("05-route-%d" % serial)
				_check(app.commands.has("rest") and app.commands.has("offering") and app.commands.has("next"), "simple route exposes rest, offering and onward without contract actions")
			if "--feedback" in OS.get_cmdline_user_args():
				await _feedback_finish(original_run)
				return
			await _type("rest" if serial == 1 else "offering")
			continue
		if app.route == "result":
			if is_instance_valid(last_battle): _report(last_battle, previous_room)
			break
		if app.route != "battle":
			_check(false, "unexpected application route during expedition: " + app.route)
			break
		var session := app.battle.session
		if app.run.room_serial != previous_room:
			if is_instance_valid(last_battle): _report(last_battle, previous_room)
			previous_room = app.run.room_serial
			last_battle = session
			frame = 0
		for enemy in session.enemies:
			if enemy.boss and pictures.find("06-boss-%d" % previous_room) < 0:
				seen_boss = true
				await _capture("06-boss-%d" % previous_room)
		if not session.hazards.is_empty() and pictures.find("06-danger-%d" % previous_room) < 0:
			await _capture("06-danger-%d" % previous_room)
		if not session.pickups.is_empty() and pictures.find("06-pickup") < 0:
			await _capture("06-pickup")
		_defend(session)
		if session.resonance_q >= BattleSession.ULTIMATE_COST_Q:
			_send(KEY_SHIFT)
			_send(KEY_SHIFT, 0, false)
		if frame % 9 == 0:
			if session.typing.target_id == &"": _send(KEY_TAB)
			if session.typing.target_id != &"":
				var word := session.typing.word.replace(" ", "")
				if session.typing.progress < word.length():
					var character := word[session.typing.progress]
					_send(character.to_upper().unicode_at(0), character.unicode_at(0))
		frame += 1
	_check(app.route == "result" and app.run.phase == "RESULT" and app.run.facts.get("result_reason") == "victory", "application reaches actual expedition victory and persisted result")
	_check(app.run.room_serial == app.run.itinerary.encounters.size() and seen_routes.size() == app.run.itinerary.encounters.size() - 1 and seen_rewards.size() > 0 and seen_boss, "actual rooms, rewards, routes and Boss were reached")
	await _capture("07-result")
	var characters := app.profile.manual_characters
	_check(characters > 0 and app.profile.records.size() == 1 and app.saves.load_profile().manual_characters == characters, "result saves real routed characters and exactly one terminal record")
	await _type("retry")
	for iteration in 600:
		await process_frame
		if app.route == "battle": break
	_check(app.route == "battle" and app.run.run_id != original_run and app.run.room_serial == 1 and app.run.selection.instances.is_empty(), "retry starts a fresh first room with no carried local relics")
	_check(app.profile.manual_characters == characters and app.profile.records.size() == 1, "restart retains saved growth and prior result")
	await _capture("08-restart")
	paused = false
	app._home()
	await _settle()
	await _type("guide")
	await _key(KEY_ESCAPE)
	_check(app.route == "home", "Escape also exits the guide through its formal back navigation")
	var output := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "checks": checks, "rooms": rooms, "screenshots": pictures, "characters": characters, "scope": "Ordinary frost expedition through the real application, full motion, Unicode input and automated exact typing/defense. No human feel or full balance claim."}, "\t"))
	output.close()
	print("S1 application: %d checks, %d failures; evidence %s" % [checks.size(), failures, evidence])
	app.queue_free()
	await _settle()
	quit(0 if failures == 0 else 1)


func _feedback_finish(original_run: String) -> void:
	await _type("home")
	await _type("history")
	_check(app.route == "history" and app.run.run_id == original_run, "history is read-only while an unfinished expedition exists")
	await _capture("12-history-empty")
	await _key(KEY_ESCAPE)
	await _type("start")
	_check(app.route == "resume_run", "departure offers continue or restart for the one pending save")
	await _capture("13-pending")
	await _type("restart")
	_check(app.route == "prepare" and app.run.run_id == original_run, "restart preparation does not discard the existing save")
	await _key(KEY_ESCAPE)
	await _type("start")
	_check(app.route == "resume_run", "canceling restart cannot bypass the saved-run choice")
	await _type("continue")
	_check(app.route == "route", "continue returns to the saved room boundary")
	await _type("rest")
	for iteration in 900:
		await process_frame
		if app.route == "battle": break
	await _key(KEY_ESCAPE)
	_check(app.route == "pause" and not app.commands.has("vocab"), "pause has no vocabulary workshop")
	await _capture("14-pause")
	await _type("bag")
	_check(app.route == "build" and _labels(app.page).contains("本局持有") and not _labels(app.page).contains("尚未获得"), "pause build shows actual owned relic stacks and details")
	await _capture("15-owned-build")
	await _key(KEY_ESCAPE)
	_check(app.route == "pause", "owned build returns to the paused battle")
	await _type("codex")
	_check(app.route == "relics", "pause codex opens the actual catalog")
	await _key(KEY_ESCAPE)
	await _type("imsuperman")
	_check(app.god_enabled and app.profile_mode == &"god" and app.battle.session.god_mode, "hidden command activates isolated God rules during pause")
	await _type("quit")
	_check(app.route == "home" and not app.run.has_pending_run() and app.profile.records.size() == 1, "one end action saves exactly one record and returns to archive")
	await _type("history")
	_check(app.route == "history" and _labels(app.page).contains("随行遗物"), "history displays the completed expedition and its build")
	_check(app._history_detail.find_children("*", "RelicGlyph", true, false).size() > 0, "record projects persisted relic instances into visible glyphs")
	await _capture("16-history-record")
	await _key(KEY_ESCAPE)
	await _type("profile")
	await _capture("17-growth-after-run")
	var output := FileAccess.open(evidence.path_join("feedback-results.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "checks": checks, "screenshots": pictures, "scope": "Real first-room typing, reward digits, saved route, pause navigation, hidden God and one-action termination. Automated defense; not a balance claim."}, "\t"))
	output.close()
	print("Feedback application: %d checks, %d failures; evidence %s" % [checks.size(), failures, evidence])
	app.queue_free()
	await _settle()
	quit(0 if failures == 0 else 1)


func _defend(session: BattleSession) -> void:
	if session.dodge_window > 0.0 or session.parry_window > 0.0: return
	for hazard in session.hazards:
		if hazard.warning_remaining < 0.2 and hazard.contains(session.player_position) and session.dodge_charges >= 1.0:
			_send(KEY_ALT)
			return
	var imminent := false
	for threat in session.threats:
		var origin := threat.position * BattleSession.ARENA_SIZE
		var nearest := Geometry2D.get_closest_point_to_segment(session.player_position * BattleSession.ARENA_SIZE, origin, origin + threat.velocity * 0.12)
		if nearest.distance_to(session.player_position * BattleSession.ARENA_SIZE) < 58.0: imminent = true
	for enemy in session.enemies:
		if enemy.alive() and enemy.aiming and enemy.attack_clock < 0.15 and enemy.position.distance_to(session.player_position) * 800.0 < 160.0: imminent = true
	if imminent:
		if session.parry_cooldown <= 0.0: _send(KEY_SPACE)
		elif session.dodge_charges >= 1.0: _send(KEY_ALT)


func _report(session: BattleSession, serial: int) -> void:
	if reported_rooms.has(serial): return
	reported_rooms[serial] = true
	rooms.append({"room": serial, "result": session.result, "seconds": session.elapsed, "characters": session.manual_characters, "words": session.completed_words, "hp": float(session.player_hp_q) / 1024.0})
	print("S1 APP ROOM ", JSON.stringify(rooms.back()))


func _labels(node: Node) -> String:
	var result := ""
	for label in node.find_children("*", "Label", true, false): result += (label as Label).text + "\n"
	for button in node.find_children("*", "Button", true, false): result += (button as Button).text + "\n"
	return result


func _contains_retired(value: String) -> bool:
	for term in ["天赋", "副书", "独卷", "材料校准", "抵押", "借还", "债务", "共享制作"]:
		if value.contains(term): return true
	return false


func _type(text: String) -> void:
	for character in text:
		await _key(character.to_upper().unicode_at(0), character.unicode_at(0))


func _key(code: int, unicode: int = 0, pressed: bool = true) -> void:
	_send(code, unicode, pressed)
	await _settle()


func _send(code: int, unicode: int = 0, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code as Key
	event.physical_keycode = code as Key
	event.unicode = unicode
	event.pressed = pressed
	Input.parse_input_event(event)


func _settle() -> void:
	await process_frame
	await process_frame


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.45, true, false, true).timeout
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
	paused = was_paused


func _check(condition: bool, label: String) -> void:
	checks.append(label)
	if not condition:
		failures += 1
		push_error(label)
