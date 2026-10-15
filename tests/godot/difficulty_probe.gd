extends "res://tests/godot/test_s2_run.gd"
## Own driver: only reuse transaction/input helpers, never the parent's ideal bot.

const Actor := preload("res://tests/godot/difficulty_probe_actor.gd")
const BOOKS := [&"frost", &"flame", &"storm", &"spirit"]
const SCENARIOS := [
	["story_beginner", "story", "beginner", false, false],
	["normal_ordinary", "normal", "ordinary", false, false],
	["hard_skilled", "hard", "skilled", false, false],
	["nightmare_expert", "nightmare", "expert", false, false],
	["cold_expert", "apocalypse", "expert", false, false],
	["cold_elite", "apocalypse", "elite", false, false],
	["grown_expert", "apocalypse", "expert", true, false],
	["retained_ordinary", "normal", "ordinary", false, true],
]
const WORDS := {
	"mixed": "ash blade crystal dream ember frost garden hollow ink jade kindle leaf mist night ocean paper quill root spell thorn under veil wind year zenith",
	"short": "ash bat cat dew elm fog gem hat ink jet key log map net owl pen red sun top urn van wax yak zip",
	"long": "archive blossom crystal diamond emerald feather glacier harvest iceberg journey kingdom lantern morning natural orchard passage quarter rainbow shelter thunder uniform village whisper younger zealous",
}
var scenarios: Array[Dictionary] = []
var reward_trace: Array[Dictionary] = []
var chosen_seed := "curve-17"
var chosen_scenario := ""
var vocabulary_kind := "mixed"
var calibration: Array[Dictionary] = []


func _run() -> void:
	directory = "res://.temp/difficulty-probe/run-%d" % Time.get_ticks_usec()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): directory = argument.substr(6)
		if argument.begins_with("--seed="): chosen_seed = argument.substr(7)
		if argument.begins_with("--book="): sampling_book = argument.substr(7)
		if argument.begins_with("--scenario="): chosen_scenario = argument.substr(11)
		if argument.begins_with("--vocabulary="): vocabulary_kind = argument.substr(13)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	router = InputRouter.new()
	root.add_child(router)
	router.action_requested.connect(func(action: StringName) -> void: battle.queue_action(action))
	var valid_scenarios: Array = SCENARIOS.map(func(item: Array) -> String: return item[0])
	if not WORDS.has(vocabulary_kind) or (not sampling_book.is_empty() and StringName(sampling_book) not in BOOKS) or (not chosen_scenario.is_empty() and chosen_scenario not in valid_scenarios):
		_check(false, "invalid probe arguments")
	else:
		_calibrate_actor()
		for scenario: Array in SCENARIOS:
			if not chosen_scenario.is_empty() and chosen_scenario != scenario[0]: continue
			for book: StringName in BOOKS:
				if not sampling_book.is_empty() and sampling_book != str(book): continue
				_probe(scenario, book)
				_write_results()
	router.free()
	print("DIFFICULTY PROBE ", JSON.stringify({"checks": checks, "failures": failures, "out": directory}))
	quit(1 if failures > 0 else 0)


func _calibrate_actor() -> void:
	# Isolated input fixture, not a battle outcome or rerun of the research.
	for profile_name: String in Actor.PROFILES:
		for preview in [false, true]:
			battle = BattleSession.new()
			router.typing = battle.typing
			router.configure(InputRouter.Context.TYPING)
			battle.typing.upsert_target(&"a", "archer")
			if preview: battle.typing.upsert_target(&"b", "breeze")
			var counts := {"words": 0, "characters": 0}
			battle.typing.word_completed.connect(func(fact: WordCompletion) -> void:
				counts.words += 1
				battle.typing.upsert_target(fact.target_id, "archer" if fact.target_id == &"a" else "breeze")
			)
			var actor := Actor.new(profile_name, "input-check-" + profile_name, _key)
			for frame in 10800:
				battle.elapsed = frame / 60.0
				actor.tick(battle, 1.0 / 60.0, false)
				counts.characters += battle.typing.drain_receipts().size()
			var expected: float = Actor.PROFILES[profile_name][0 if preview else 1]
			var measured := float(counts.words) / 3.0
			_check(absf(measured / expected - 1.0) < 0.16, "actor throughput matches declared research scenario within frame/length tolerance")
			_check(counts.characters == actor.submitted - actor.injected_errors, "input fixture retains typo cost without backspace repair")
			calibration.append({"profile": profile_name, "preview": preview, "words_per_minute": measured, "reference_words_per_minute": expected, "characters_per_second": counts.characters / 180.0, "errors": actor.injected_errors})
			battle.free()
			battle = null
	print("PROBE INPUT ", JSON.stringify(calibration))


func _probe(scenario: Array, book: StringName) -> void:
	var label := "%s-%s-%s" % [scenario[0], book, chosen_seed]
	var session := _new_run(label, scenario[1], book, scenario[3], chosen_seed)
	var entries: Array[VocabularyEntry] = []
	for word: String in WORDS[vocabulary_kind].split(" "):
		entries.append(VocabularyEntry.new(word, "探针"))
	var prepared := VocabularyIndex.build(entries)
	var start_index := evidence.size()
	var error_start := failures
	var completed_rounds: Array[String] = []
	var round_count := 4 if bool(scenario[4]) else 1
	for round_index in round_count:
		var mode := str(session.options.difficulty)
		var victory := _probe_round(session, entries, prepared, str(scenario[2]), label)
		if not victory: break
		completed_rounds.append(mode)
		if round_index + 1 < round_count:
			var before := session.selection.to_dict()
			var saved_characters := session.profile.manual_characters
			var continued := session.continue_challenge()
			_check(continued, "earned ascent: " + session.last_error)
			if not continued: break
			before.erase("base_hp")
			var after := session.selection.to_dict()
			after.erase("base_hp")
			_check(_json_equal(before, after) and session.profile.manual_characters == saved_characters, "ascent retains assets and does not duplicate growth")
	var last: Dictionary = evidence.back() if evidence.size() > start_index else {}
	var report := {"scenario": scenario[0], "book": str(book), "seed": chosen_seed, "profile": scenario[2], "vocabulary": vocabulary_kind, "growth_fixture": scenario[3], "completed_rounds": completed_rounds, "completed": completed_rounds.size() == round_count, "rooms": evidence.size() - start_index, "last_difficulty": last.get("difficulty", ""), "last_room": last.get("room", 0), "last_result": last.get("result", "flow_error"), "flow_failures": failures - error_start}
	if failures > error_start:
		report.completed = false
		report.last_result = "flow_error"
	scenarios.append(report)
	print("PROBE SCENARIO ", JSON.stringify(report))


func _probe_round(session: RunSession, entries: Array[VocabularyEntry], prepared: VocabularyIndex, profile_name: String, label: String) -> bool:
	for serial in 9:
		var request := session.start_room(entries, prepared)
		_check(request != null, "probe departure: " + session.last_error)
		if request == null: return false
		battle = BattleSession.new()
		battle.start(request, session.combat)
		session.install_room_opening(battle)
		router.typing = battle.typing
		router.configure(InputRouter.Context.TYPING)
		var actor := Actor.new(profile_name, "%s:%s:%s:%s:%s" % [chosen_seed, session.selection.book_id, profile_name, session.facts.get("round_index", 0), serial], _key)
		var hp_trace := {"last_q": battle.player_hp_q, "lost_q": 0, "restored_q": 0}
		var events: Dictionary = {}
		var start_failures := failures
		battle.progression_changed.connect(func() -> void: _check(session.observe_battle(battle), "probe checkpoint: " + session.last_error))
		battle.event_committed.connect(func(event: Dictionary) -> void:
			var kind := str(event.get("kind", ""))
			events[kind] = int(events.get(kind, 0)) + 1
			_trace_hp(hp_trace)
		)
		var departure_hp := float(battle.player_hp_q) / Q
		var departure_world_time := battle.world_time
		var departure_assets := _new_relics(session, 0)
		var peak_enemies := 0
		var peak_threats := 0
		var enemy_sum := 0.0
		var samples := 0
		var peak_spirits := 0
		var spirit_flight_seconds := 0.0
		var timeline: Array[Dictionary] = []
		var wall_start := Time.get_ticks_usec()
		for frame in 36000: # Explicit 600 real-second censoring, never a fabricated defeat.
			if battle.result != 0 or failures > start_failures: break
			if session.phase == "BATTLE_REWARD": _probe_rewards(session, label, battle)
			actor.tick(battle, 1.0 / 60.0)
			battle.step(1.0 / 60.0)
			_trace_hp(hp_trace)
			peak_spirits = maxi(peak_spirits, battle.spirits.size())
			for spirit in battle.spirits:
				if spirit.mode in [&"dive", &"cross"]: spirit_flight_seconds += 1.0 / 60.0
			if frame % 6 == 0:
				var living := battle._living().size()
				peak_enemies = maxi(peak_enemies, living)
				peak_threats = maxi(peak_threats, battle.threats.size())
				enemy_sum += living
				samples += 1
			if frame % 600 == 0:
				timeline.append({"seconds": battle.elapsed, "hp": float(battle.player_hp_q) / Q, "enemies": battle._living().size(), "threats": battle.threats.size(), "characters": battle.manual_characters, "wave": battle.wave})
		var result_name := "flow_error" if failures > start_failures else "victory" if battle.result == 1 else "defeat" if battle.result == -1 else "timeout"
		var remaining: Array[Dictionary] = []
		for enemy in battle._living():
			remaining.append({"kind": str(enemy.kind), "hp": float(enemy.hp_q) / Q, "phase": enemy.phase, "mark": enemy.vulnerability})
		var report := {"scenario": label, "book": str(session.selection.book_id), "profile": profile_name, "seed": chosen_seed, "vocabulary": vocabulary_kind, "difficulty": session.options.difficulty, "round": session.facts.get("round_index", 0), "room": serial + 1, "result": result_name, "seconds": battle.elapsed, "world_seconds": battle.world_time, "hp": float(battle.player_hp_q) / Q, "maximum_hp": float(battle.player_max_hp_q) / Q, "departure_hp": departure_hp, "growth_hp": session.selection.growth_hp, "characters": battle.manual_characters, "words": battle.completed_words, "errors": battle.typing.mistakes, "accepted_cps": battle.manual_characters / maxf(0.01, battle.elapsed), "peak_enemies": peak_enemies, "peak_threats": peak_threats, "mean_enemies": enemy_sum / maxi(1, samples), "hp_lost": float(hp_trace.lost_q) / Q, "hp_restored": float(hp_trace.restored_q) / Q, "events": events, "actor": actor.metrics(), "departure_relics": departure_assets, "remaining": remaining, "timeline": timeline, "wall_seconds": (Time.get_ticks_usec() - wall_start) / 1000000.0}
		report.world_seconds = battle.world_time - departure_world_time
		report["damage_by_source"] = battle.runtime.damage_by_source.duplicate()
		report["kills_by_source"] = battle.runtime.kills_by_source.duplicate()
		report["peak_spirits"] = peak_spirits
		report["spirit_flight_seconds"] = spirit_flight_seconds
		_check(battle.typing.mistakes == actor.injected_errors, "only planned typo events occur")
		_check(battle.manual_characters == actor.submitted - actor.injected_errors, "all correct physical characters committed once")
		var victory := battle.result == 1
		report["combat_result"] = result_name
		report["end_relics"] = _new_relics(session, 0)
		if battle.result != 0: _check(session.finish_room(battle), "probe settlement: " + session.last_error)
		battle.free()
		battle = null
		if victory and serial < 8:
			_probe_rewards(session, label)
			_check(session.take_route("rest"), "probe rest route: " + session.last_error)
		if victory: report["end_relics"] = _new_relics(session, 0)
		if failures > start_failures:
			result_name = "flow_error"
			report.result = result_name
		report["after_boundary_hp"] = float(session.combat.hp_q) / Q
		evidence.append(report)
		print("PROBE ROOM ", JSON.stringify({"scenario": label, "difficulty": report.difficulty, "room": serial + 1, "result": result_name, "seconds": report.seconds, "hp": report.hp, "cps": report.accepted_cps, "relics": report.end_relics.size()}))
		if not victory or failures > start_failures: return false
	return true


func _probe_rewards(session: RunSession, label: String, live: BattleSession = null) -> void:
	var book_preferences := {
		&"frost": ["F003", "F001", "F006", "F009", "F014"],
		&"flame": ["A004", "A006", "A007", "A009", "A017"],
		&"storm": ["T003", "T004", "T007", "T008", "T014"],
		&"spirit": ["P004", "P008", "P009", "P011", "P025"],
	}
	for index in 32:
		if session.phase not in ["REWARD", "BATTLE_REWARD"]: return
		var candidates: Array = session.offer.candidates.duplicate()
		if candidates.is_empty():
			_check(session.supply_reward(str(session.offer.id), live), "probe supply")
			continue
		var priorities: Array = ["R001", "R039", "R012", "R024", "R016", "R019"]
		priorities.append_array(book_preferences[session.selection.book_id])
		var chosen := StringName(candidates[0])
		for id: String in priorities:
			if id in candidates:
				chosen = StringName(id)
				break
		reward_trace.append({"scenario": label, "difficulty": session.options.difficulty, "room": session.room_serial, "round": session.facts.get("round_index", 0), "offered": candidates, "chosen": str(chosen)})
		if not session.take_reward(chosen, str(session.offer.id), "", live):
			_check(false, "probe acquisition: " + session.last_error)
			return
	_check(false, "probe reward queue exhausted")


func _write_results() -> void:
	var output := FileAccess.open(directory.path_join("results.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"schema": 1, "checks": checks, "failures": failures, "profiles": Actor.PROFILES, "calibration": calibration, "scenarios": scenarios, "rooms": evidence, "rewards": reward_trace, "parameters": {"health": BattleSession.MODE_HEALTH, "damage": BattleSession.MODE_DAMAGE, "spawn": BattleSession.MODE_SPAWN, "cap": BattleSession.MODE_ACTIVE_CAP, "dodge": BattleSession.MODE_DODGE_CD, "iframe": BattleSession.MODE_IFRAME}, "scope": "60Hz formal input/reward/route/ascent; independent actor RNG, one-word preview, finite reaction/misses; no combat state injection. Growth scenario explicitly starts with prior-history fixture. 600s timeout is censoring. Not human win-rate evidence."}, "\t"))
	output.close()
