extends SceneTree
## Formal S1 run boundaries and Unicode input; no fixture damage or invulnerability.

const STEP := 1.0 / 60.0
const CHARACTER_INTERVAL := 9
const ROOM_LIMIT := 18000
var checks := 0
var failures := 0
var directory: String
var room_reports: Array[Dictionary] = []
var router: InputRouter
var battle: BattleSession
var events: Dictionary = {}
var boss_phases: Dictionary = {}
var route_failure_checked := false
var boundary_failure_checked := false


class FailingRepository:
	extends SaveRepository
	var reject_next := false

	func _init(base: String) -> void:
		super(&"normal", base)

	func save_profile(candidate: ProfileState, expected_revision: int) -> bool:
		if reject_next:
			reject_next = false
			last_error = "INJECTED_SAVE_FAILURE"
			return false
		return super.save_profile(candidate, expected_revision)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	directory = "res://.temp/shrink/flow/run-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	router = InputRouter.new()
	root.add_child(router)
	router.action_requested.connect(_action)
	for book in [&"frost", &"storm", &"spirit", &"flame"]:
		_run_book(book)
	_test_legacy_preservation()
	_check(room_reports.size() == 12 and route_failure_checked and boundary_failure_checked, "all twelve real rooms and both failure boundaries were actually reached")
	var output := FileAccess.open(directory.path_join("results.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures, "characters_per_second": 60.0 / CHARACTER_INTERVAL, "rooms": room_reports, "scope": "Formal three-room runs, Unicode router, saved rewards/routes and final restart. Synthetic exact input and automated defense; no human feel claim."}, "\t"))
	output.close()
	router.free()
	print("S1 run: %d checks, %d failures; evidence %s" % [checks, failures, directory])
	quit(0 if failures == 0 else 1)


func _new_run(book: StringName, repository: SaveRepository) -> RunSession:
	var session := RunSession.new(repository, repository.load_profile())
	session.itinerary = preload("res://game/content/s1_itinerary.tres")
	var settings := AppSettings.new()
	settings.difficulty = "normal"
	settings.progressive = false
	settings.run_seed = "s1-flow-" + str(book)
	_check(session.call("begin", book, settings), "%s begins directly from a main book: %s" % [book, session.last_error])
	_check(session.phase == "READY_FOR_ROOM" and session.selection.talents.is_empty() and session.selection.instances.is_empty(), "new run has no talents or opening relics")
	return session


func _entries() -> Array[VocabularyEntry]:
	return [VocabularyEntry.new("ash", "灰"), VocabularyEntry.new("ink", "墨"), VocabularyEntry.new("frost", "霜"), VocabularyEntry.new("spirit", "灵"), VocabularyEntry.new("archive", "档案"), VocabularyEntry.new("thunder", "雷")]


func _run_book(book: StringName) -> void:
	var repository := FailingRepository.new(directory.path_join(str(book)))
	var session := _new_run(book, repository)
	var total_characters := 0
	var run_identity := session.run_id
	var encounter_ids: PackedStringArray = []
	for serial in 3:
		if session.phase != "READY_FOR_ROOM":
			_check(false, "%s room %d was not ready: %s" % [book, serial + 1, session.phase])
			break
		var request: BattleStartRequest = session.call("start_room", _entries(), VocabularyIndex.build(_entries()))
		_check(request != null, "%s room %d persists departure: %s" % [book, serial + 1, session.last_error])
		if request == null: break
		encounter_ids.append(request.encounter.resource_path)
		_check(repository.load_profile().run_checkpoint.phase == "BATTLE", "disk battle boundary precedes world installation")
		battle = BattleSession.new()
		battle.start(request, session.combat)
		session.install_room_opening(battle)
		router.typing = battle.typing
		router.configure(InputRouter.Context.TYPING)
		events.clear()
		boss_phases.clear()
		battle.event_committed.connect(_record)
		_play_room(session)
		total_characters += battle.manual_characters
		_check(battle.result == 1, "%s room %d wins through routed typing; HP %.1f, elapsed %.2f" % [book, serial + 1, float(battle.player_hp_q) / 1024.0, battle.elapsed])
		_check(battle.manual_characters > 0 and battle.completed_words > 0, "room requires accepted physical characters and completed words")
		if serial == 2:
			_check(not boss_phases.is_empty(), "third encounter includes a real Boss")
		room_reports.append({"book": str(book), "room": serial + 1, "encounter": request.encounter.resource_path, "result": battle.result, "seconds": battle.elapsed, "hp": float(battle.player_hp_q) / 1024.0, "characters": battle.manual_characters, "words": battle.completed_words, "wave": battle.wave, "events": events.duplicate(), "boss_phases": boss_phases.keys()})
		print("S1 ROOM ", JSON.stringify(room_reports.back()))
		if battle.result != 1:
			battle.free()
			battle = null
			break
		if not boundary_failure_checked:
			var before := session.profile.to_dict()
			var bytes := FileAccess.get_file_as_bytes(repository.path)
			repository.reject_next = true
			_check(not session.call("finish_room", battle), "failed room save returns failure")
			_check(session.profile.to_dict() == before and FileAccess.get_file_as_bytes(repository.path) == bytes and session.phase == "BATTLE", "failed room save publishes neither characters nor phase nor disk changes")
			boundary_failure_checked = true
		_check(session.call("finish_room", battle), "room settlement commits: " + session.last_error)
		var revision := session.profile.revision
		_check(session.call("finish_room", battle) and session.profile.revision == revision, "duplicate room settlement does not save or pay twice")
		_check(session.profile.manual_characters == total_characters, "persisted growth equals accepted characters across room/checkpoint boundaries")
		battle.free()
		battle = null
		if serial < 2:
			_rewards(session)
			_check(session.phase == "ROUTE", "room reward queue reaches simple route")
			var choice := "offering" if serial == 1 and book == &"frost" else "rest" if serial == 0 else "continue"
			_route(session, choice)
			_rewards(session)
			_check(session.phase == "READY_FOR_ROOM", "route and any offering reward return to ready")
			var restored := RunSession.new(repository, repository.load_profile())
			_check(restored.call("restore") and restored.phase == "READY_FOR_ROOM" and restored.selection.to_dict() == session.selection.to_dict(), "persisted next-room build restores without talent configuration")
			session = restored
	_check(encounter_ids.size() == 3 and encounter_ids[0] != encounter_ids[1] and encounter_ids[1] != encounter_ids[2], "three rooms use different real encounter definitions")
	_check(session.phase == "RESULT" and session.profile.records.size() == 1 and session.facts.get("result_reason") == "victory", "%s ends in one saved victory record" % book)
	var completed_characters := session.profile.manual_characters
	var settings := AppSettings.new()
	settings.run_seed = "s1-restart-" + str(book)
	_check(session.call("begin", book, settings) and session.run_id != run_identity and session.phase == "READY_FOR_ROOM" and session.room_serial == 0, "restart creates a fresh run identity at the first room")
	_check(session.selection.instances.is_empty() and session.profile.manual_characters == completed_characters and session.profile.records.size() == 1, "normal restart resets local relics while retaining saved growth and record")


func _play_room(session: RunSession) -> void:
	for frame in ROOM_LIMIT:
		if battle.result != 0: return
		if session.phase == "BATTLE_REWARD":
			_rewards(session, battle)
		if session.phase != "BATTLE":
			_check(false, "unexpected live phase: " + session.phase)
			return
		_defend()
		if battle.resonance_q >= BattleSession.ULTIMATE_COST_Q:
			_key(KEY_SHIFT)
			_key(KEY_SHIFT, 0, false)
		if frame % CHARACTER_INTERVAL == 0:
			if battle.typing.target_id == &"": _key(KEY_TAB)
			if battle.typing.target_id != &"":
				var word := battle.typing.word.replace(" ", "")
				if battle.typing.progress < word.length():
					var character := word[battle.typing.progress]
					_key(character.to_upper().unicode_at(0), character.unicode_at(0))
		battle.step(STEP)
		for enemy in battle.enemies:
			if enemy.boss: boss_phases[enemy.phase] = true
		if battle.result == 0 and not session.call("observe_battle", battle):
			_check(false, "live reward checkpoint failed: " + session.last_error)
			return
	_check(false, "room exceeded 300 seconds of simulated battle")


func _defend() -> void:
	if battle.dodge_window > 0.0 or battle.parry_window > 0.0: return
	var imminent := false
	for threat in battle.threats:
		var origin := threat.position * BattleSession.ARENA_SIZE
		var nearest := Geometry2D.get_closest_point_to_segment(battle.player_position * BattleSession.ARENA_SIZE, origin, origin + threat.velocity * 0.12)
		if nearest.distance_to(battle.player_position * BattleSession.ARENA_SIZE) < 58.0: imminent = true
	for enemy in battle.enemies:
		if enemy.alive() and enemy.aiming and enemy.attack_clock < 0.15:
			if enemy.position.distance_to(battle.player_position) * 800.0 < 160.0: imminent = true
	if imminent:
		if battle.parry_cooldown <= 0.0: _key(KEY_SPACE)
		elif battle.dodge_charges >= 1.0: _key(KEY_ALT)


func _rewards(session: RunSession, live: BattleSession = null) -> void:
	for index in 32:
		if session.phase not in ["REWARD", "BATTLE_REWARD"]: return
		var offer := session.offer.duplicate(true)
		var restored := RunSession.new(session.repository, session.repository.load_profile())
		if live == null:
			_check(restored.call("restore") and restored.offer == offer, "saved candidates restore exactly without redraw")
		var candidates: Array = offer.get("candidates", [])
		if candidates.is_empty():
			_check(false, "formal reward has no candidates")
			return
		var chosen := StringName(candidates[0])
		for preference in [&"R001", &"R016", &"R012", &"R019", &"R014", &"R003", &"R005", &"R050", &"R054", &"R039"]:
			if str(preference) in candidates:
				chosen = preference
				break
		_check(session.call("take_reward", chosen, str(offer.id), "", live), "formal reward installs %s: %s" % [chosen, session.last_error])
		var revision := session.profile.revision
		var spent := session.rewards.spent
		var rng := session.reward_rng_state
		_check(session.call("take_reward", chosen, str(offer.id), "", live) and session.profile.revision == revision and session.rewards.spent == spent and session.reward_rng_state == rng, "duplicate reward neither pays nor saves nor redraws")
	_check(false, "reward queue exceeded its finite limit")


func _route(session: RunSession, choice: String) -> void:
	var hp := session.combat.hp_q
	var maximum := session.compiler.compile(session.selection).build.maximum_hp_q()
	var earned := session.rewards.earned
	if not route_failure_checked:
		var before := session.profile.to_dict()
		var bytes := FileAccess.get_file_as_bytes(session.repository.path)
		(session.repository as FailingRepository).reject_next = true
		_check(not session.call("take_route", choice), "route save failure is reported")
		_check(session.phase == "ROUTE" and session.combat.hp_q == hp and session.profile.to_dict() == before and FileAccess.get_file_as_bytes(session.repository.path) == bytes, "failed route publishes neither payment nor next-room state")
		route_failure_checked = true
	_check(session.call("take_route", choice), "simple route commits %s: %s" % [choice, session.last_error])
	if choice == "rest": _check(session.combat.hp_q == mini(maximum, hp + 20 * 1024), "rest restores 20 health with maximum cap")
	if choice == "offering": _check(session.combat.hp_q == hp - 15 * 1024 and session.rewards.earned == earned + 1 and session.phase == "REWARD", "offering pays 15 once and grants one saved reward")
	var revision := session.profile.revision
	var paid_hp := session.combat.hp_q
	var paid_earned := session.rewards.earned
	_check(session.call("take_route", choice) and session.combat.hp_q == paid_hp and session.rewards.earned == paid_earned and session.profile.revision == revision, "duplicate route does not repay or restore again")


func _test_legacy_preservation() -> void:
	var repository := SaveRepository.new(&"normal", directory.path_join("legacy"))
	var session := _new_run(&"frost", repository)
	var old := session.profile.copy()
	old.content_version = 1
	old.manual_characters = 1234
	old.run_checkpoint.facts.content_version = 1
	old.revision += 1
	_check(repository.save_profile(old, session.profile.revision), "fixture writes a valid old-version ready checkpoint")
	var original := FileAccess.get_file_as_bytes(repository.path)
	var restored := RunSession.new(repository, repository.load_profile())
	_check(restored.call("restore") and restored.phase == "RESULT" and restored.facts.get("result_reason") == "incompatible", "incompatible old run ends at restore boundary")
	_check(restored.profile.manual_characters == 1234 and restored.profile.records.size() == 1, "old saved characters and terminal record survive contraction")
	_check(FileAccess.file_exists(repository.path + ".v1.json") and FileAccess.get_file_as_bytes(repository.path + ".v1.json") == original, "original v1 archive is preserved byte for byte")
	var revision := restored.profile.revision
	var again := RunSession.new(repository, repository.load_profile())
	_check(again.call("restore") and again.profile.revision == revision and again.profile.records.size() == 1 and FileAccess.get_file_as_bytes(repository.path + ".v1.json") == original, "repeated restore does not resettle or overwrite preserved original")


func _key(code: int, unicode: int = 0, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code as Key
	event.physical_keycode = code as Key
	event.unicode = unicode
	event.pressed = pressed
	router._input(event)


func _action(action: StringName) -> void:
	if battle != null: battle.queue_action(action)


func _record(event: Dictionary) -> void:
	var kind: StringName = event.kind
	events[str(kind)] = int(events.get(str(kind), 0)) + 1
	if event.get("empowered", false): events["empowered"] = int(events.get("empowered", 0)) + 1


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
