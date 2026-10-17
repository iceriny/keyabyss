extends SceneTree
## S2 transaction fixtures are explicit; --formal additionally earns nine-room victories.

const Q := 1024
const MODES := ["story", "normal", "hard", "nightmare", "apocalypse"]
const STARTING_HEALTH := [155, 125, 110, 100, 90]
var checks := 0
var failures := 0
var directory: String
var evidence: Array[Dictionary] = []
var router: InputRouter
var battle: BattleSession
var sampling_seed := "s3-sample-1"
var sampling_book := ""


class FailingRepository:
	extends SaveRepository
	var reject_next := false
	var save_calls: int = 0

	func _init(base: String) -> void:
		super(&"normal", base)

	func save_profile(candidate: ProfileState, expected_revision: int) -> bool:
		save_calls += 1
		if reject_next:
			reject_next = false
			last_error = "INJECTED_SAVE_FAILURE"
			return false
		return super.save_profile(candidate, expected_revision)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	directory = "res://.temp/shrink/flow/s2-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for mode in MODES: _test_continuation(mode)
	_test_records_and_end()
	_test_reroll()
	_test_relic_restore_compatibility()
	_test_full_pool_supply()
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--seed="): sampling_seed = argument.substr(7)
		if argument.begins_with("--book="): sampling_book = argument.substr(7)
	if not sampling_book.is_empty() and sampling_book not in ["frost", "storm", "spirit", "flame"]:
		push_error("Unknown --book: " + sampling_book)
		quit(1)
		return
	var balance_requested := "--balance" in arguments or "--cold-only" in arguments or "--retained-only" in arguments or "--grown-retained" in arguments
	var range_requested := "--range-check" in arguments
	if "--formal" in arguments or balance_requested or range_requested:
		router = InputRouter.new()
		root.add_child(router)
		router.action_requested.connect(func(action: StringName) -> void: battle.queue_action(action))
		if "--formal" in OS.get_cmdline_user_args():
			for book in [&"frost", &"storm", &"spirit", &"flame"]:
				if sampling_book.is_empty() or str(book) == sampling_book: _formal_run(book)
		if balance_requested: _balance_matrix()
		if range_requested: _range_check()
		router.free()
	var output := FileAccess.open(directory.path_join("results.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures, "formal_requested": "--formal" in arguments, "balance_requested": balance_requested, "range_requested": range_requested, "mistakes_requested": "--mistakes" in arguments, "cold_only": "--cold-only" in arguments, "retained_only": "--retained-only" in arguments, "evidence": evidence, "scope": "Explicit valid RESULT/reward fixtures test transaction contracts; grown range samples use an explicit valid prior-history receipt fixture. Formal input uses 60 Hz, fixed dictionary, Unicode, target selection via Tab, automated geometry-informed parry/Alt and earned ultimate. Default submits exact letters; --mistakes submits one rejected letter per twenty attempts, deferred until target progress > 0, consuming a scheduled slot. Accuracy is measured from actual accepted/submitted characters. No Ctrl completion or injected combat damage, HP, position, invulnerability or victory. Fixed seed is one sample; this is not human feel."}, "\t"))
	output.close()
	print("S2 run: %d checks, %d failures; evidence %s" % [checks, failures, directory])
	quit(0 if failures == 0 else 1)


func _new_run(label: String, mode: String = "normal", book: StringName = &"frost", growth: bool = false, run_seed: String = "") -> RunSession:
	var repository := FailingRepository.new(directory.path_join(label))
	var session := RunSession.new(repository, repository.load_profile())
	if growth:
		# Explicit prior-history fixture; no combat HP or victory is fabricated.
		var receipt := RoomSettlementReceipt.new("balance-prior-history", 1, "prior", &"victory", TalentProgress.MAX_LEVEL * TalentProgress.CHARACTERS_PER_LEVEL, &"normal")
		session.profile = TalentProgress.prepare(session.profile, receipt).profile
	var settings := AppSettings.new()
	settings.difficulty = mode
	settings.progressive = false
	settings.run_seed = "s2-" + label if run_seed.is_empty() else run_seed
	_check(session.begin(book, settings), "direct book begin: " + session.last_error)
	return session


func _persist_fixture(session: RunSession) -> RunSession:
	var proposed := session.profile.copy()
	proposed.run_checkpoint = session.to_checkpoint()
	proposed.revision += 1
	_check(RunSession.from_checkpoint(proposed.run_checkpoint) != null, "fixture passes the real checkpoint parser")
	_check(session.repository.save_profile(proposed, session.profile.revision), "fixture persists through actual profile repository: " + session.repository.last_error)
	var restored := RunSession.new(session.repository, session.repository.load_profile())
	_check(restored.restore(), "fixture reopens through real restore")
	return restored


func _acquire_fixture(session: RunSession, id: StringName, identity: String) -> void:
	var result := RunTransactionService.new(session.compiler).prepare_acquisition(session.selection, session.combat, id, identity, "", {"shortest": 3, "longest": 7})
	_check(result.diagnostics.is_empty(), "fixture asset uses actual acquisition contract: " + str(result.diagnostics))
	if result.diagnostics.is_empty():
		session.selection = result.selection
		session.combat = result.state


func _victory_fixture(label: String, mode: String = "normal") -> RunSession:
	var session := _new_run(label, mode)
	_acquire_fixture(session, &"R001", label + ":power")
	_acquire_fixture(session, &"R012", label + ":health")
	_acquire_fixture(session, &"R024", label + ":rescue")
	var rescue: CombatAssetInstance = session.selection.instances.back()
	_check(session.combat.claim_asset(rescue.usage_key(), &"revive"), "fixture consumes one actual rescue usage identity")
	session.phase = "RESULT"
	session.room_serial = session.itinerary.encounters.size()
	session.facts["result_reason"] = "victory"
	session.facts["victory_pending"] = true
	session.facts["round_index"] = 0
	session.facts["round_start_characters"] = 0
	session.facts["rerolls"] = 3
	session.facts["result_build"] = session.selection.to_dict()
	session.combat.hp_q = 65 * Q
	if mode == "nightmare": session.combat.hp_q = session.compiler.compile(session.selection).build.maximum_hp_q() - 10 * Q
	session.combat.relic_counters = {"casts": 7, "combo": 4, "perfect": 2, "manual": 7, "assist": 1, "boost": 0}
	var receipt := RoomSettlementReceipt.new(session.run_id, 1, label + ":fixture-first-round", &"victory", 100, &"normal")
	var prepared := TalentProgress.prepare(session.profile, receipt)
	_check(prepared.diagnostics.is_empty(), "fixture character receipt passes actual settlement validation")
	session.profile = prepared.profile
	session.profile.records.append({"run_id": session.run_id, "reason": "victory", "characters": 100, "book": "frost", "rooms": session.room_serial})
	return _persist_fixture(session)


func _test_continuation(mode: String) -> void:
	var session := _victory_fixture("continue-" + mode, mode)
	var identity := session.run_id
	var assets := _inherited_selection(session.selection)
	var claims: Dictionary = RunStateCodec.encode(session.combat).get("asset_claims", {}).duplicate(true)
	var counters: Dictionary = session.combat.relic_counters.duplicate()
	var next_selection := session.selection.copy()
	next_selection.base_hp = STARTING_HEALTH[mini(MODES.find(mode) + 1, 4)]
	var expected_hp := mini(session.compiler.compile(next_selection).build.maximum_hp_q(), session.combat.hp_q + 30 * Q)
	_check(not session.next_challenge_label().is_empty(), "pending victory exposes its next challenge label")
	var bytes := FileAccess.get_file_as_bytes(session.repository.path)
	var snapshot := session.to_checkpoint()
	(session.repository as FailingRepository).reject_next = true
	_check(not session.continue_challenge(), "continuation save failure is reported")
	_check(session.to_checkpoint() == snapshot and FileAccess.get_file_as_bytes(session.repository.path) == bytes, "failed continuation publishes no stage, healing, reroll or file change")
	_check(session.continue_challenge(), "continue commits: " + session.last_error)
	_check(session.run_id == identity and _inherited_selection(session.selection) == assets, "continuation preserves run, book, growth and relic IDs, instances and layers")
	_check(session.selection.base_hp == next_selection.base_hp, "next difficulty selects its own starting health baseline")
	_check(RunStateCodec.encode(session.combat).get("asset_claims", {}) == claims, "continuation preserves consumed asset opportunities")
	_check(session.combat.relic_counters == counters, "continuation preserves relic cadence and ready assist opportunity")
	_check(session.phase == "READY_FOR_ROOM" and session.room_serial == 0 and int(session.facts.round_index) == 1 and not bool(session.facts.victory_pending), "continuation creates exactly the next round at room zero")
	_check(session.combat.hp_q == expected_hp and int(session.facts.rerolls) == 4, "continuation heals 30 within actual maximum and refills one reroll with cap four")
	var expected: String = MODES[mini(MODES.find(mode) + 1, MODES.size() - 1)]
	_check(session.options.difficulty == expected and int(session.options.get("loop_index", 0)) == (1 if mode == "apocalypse" else 0), "five modes advance once; apocalypse advances loop pressure")
	_check(int(session.facts.round_start_characters) == 100 and session.profile.manual_characters == 100 and session.profile.records.size() == 1, "continuation neither earns growth nor repeats its previous stage record")
	var after := session.to_checkpoint()
	var revision := session.profile.revision
	session.continue_challenge()
	_check(session.to_checkpoint() == after and session.profile.revision == revision, "duplicate continuation cannot restore health, rerolls or advance again")
	var restored := RunSession.new(session.repository, session.repository.load_profile())
	_check(restored.restore() and _json_equal(restored.to_checkpoint(), after), "continued identity and state survive JSON reload")
	_check(not restored.combat.claim_asset(restored.selection.instances.back().usage_key(), &"revive"), "reloaded consumed rescue cannot be used again after advancing")
	evidence.append({"kind": "RESULT transaction fixture", "mode": mode, "next_mode": str(session.options.difficulty), "loop": session.options.get("loop_index", 0), "instances": session.selection.instances.size(), "claimed_opportunities": claims.size()})


func _test_records_and_end() -> void:
	var session := _victory_fixture("records")
	var original := session.run_id
	_check(session.continue_challenge(), "record fixture enters round two")
	var candidate := session.copy()
	candidate.phase = "RESULT"
	candidate.room_serial = candidate.itinerary.encounters.size()
	candidate.facts["result_reason"] = "victory"
	candidate.facts["victory_pending"] = true
	candidate.facts["result_build"] = candidate.selection.to_dict()
	var receipt := RoomSettlementReceipt.new(original, 1, "fixture-second-round", &"victory", 30, &"normal")
	var progress := TalentProgress.prepare(session.profile, receipt)
	_check(progress.diagnostics.is_empty(), "second-round fixture uses a distinct valid settlement identity")
	var advanced: ProfileState = progress.profile
	var record := session._record(candidate, advanced)
	_check(int(record.characters) == 30, "pure stage-record projection reports only newly committed round characters")
	advanced.records.append(record)
	candidate.profile = advanced
	session = _persist_fixture(candidate)
	var bytes := FileAccess.get_file_as_bytes(session.repository.path)
	var before := session.to_checkpoint()
	(session.repository as FailingRepository).reject_next = true
	_check(not session.end_challenge() and session.to_checkpoint() == before and FileAccess.get_file_as_bytes(session.repository.path) == bytes, "failed end does not close assets or change the original pending victory")
	_check(session.end_challenge(), "explicit end closes a pending victory")
	_check(session.phase == "RESULT" and session.selection.instances.is_empty() and not bool(session.facts.get("victory_pending", false)), "end clears local relics and continuation eligibility")
	_check(session.profile.manual_characters == 130 and session.profile.records.size() == 2, "end does not earn growth or append another victory record")
	var revision := session.profile.revision
	session.end_challenge()
	_check(session.profile.revision == revision and session.profile.records.size() == 2, "duplicate end does not resettle")
	var settings := AppSettings.new()
	_check(session.begin(&"storm", settings) and session.run_id != original and session.selection.book_id == &"storm" and session.selection.instances.is_empty(), "ordinary restart creates a new run and clears inherited relics")
	_check(session.profile.manual_characters == 130 and session.profile.records.size() == 2, "ordinary restart retains prior characters and records")
	evidence.append({"kind": "record projection fixture", "round_characters": record.characters, "total_characters": 130})


func _reward_fixture(label: String) -> RunSession:
	var session := _new_run(label)
	session.phase = "REWARD"
	session.room_serial = 1
	session.rewards.earned += 1
	session.facts["rerolls"] = 2
	session.facts["route_complete"] = false
	session._make_reward_offer(session)
	return _persist_fixture(session)


func _test_reroll() -> void:
	var session := _reward_fixture("reroll")
	var previous: Dictionary = session.offer.duplicate(true)
	_check(not session.supply_reward(str(previous.id)), "nonempty eligible pool cannot exchange a relic offer for supply")
	var spent := session.rewards.spent
	var bytes := FileAccess.get_file_as_bytes(session.repository.path)
	(session.repository as FailingRepository).reject_next = true
	_check(not session.reroll_reward(str(previous.id)), "reroll save failure is reported")
	_check(session.offer == previous and int(session.facts.rerolls) == 2 and FileAccess.get_file_as_bytes(session.repository.path) == bytes, "failed reroll preserves quote, counter and file")
	_check(session.reroll_reward(str(previous.id)), "reroll refreshes a valid saved quote")
	_check(str(session.offer.id) != str(previous.id) and int(session.facts.rerolls) == 1 and session.rewards.spent == spent, "reroll changes quote identity and spends one reroll rather than reward opportunity")
	var after := session.to_checkpoint()
	var revision := session.profile.revision
	session.reroll_reward(str(previous.id))
	_check(session.to_checkpoint() == after and session.profile.revision == revision, "old reroll quote cannot pay twice or redraw again")
	_check(not session.take_reward(StringName(previous.candidates[0]), str(previous.id)), "stale pre-reroll reward quote cannot be acquired")
	var restored := RunSession.new(session.repository, session.repository.load_profile())
	_check(restored.restore() and restored.offer == session.offer and int(restored.facts.rerolls) == 1, "refreshed quote and remaining rerolls reopen unchanged")
	_check(session.reroll_reward(str(session.offer.id)) and int(session.facts.rerolls) == 0, "last reroll is consumed")
	after = session.to_checkpoint()
	_check(not session.reroll_reward(str(session.offer.id)) and session.to_checkpoint() == after, "zero rerolls rejects further redraw")


func _test_relic_restore_compatibility() -> void:
	var legal := _new_run("compat-legal")
	_acquire_fixture(legal, &"R003", "compat-legal:cold")
	legal = _save_legacy_checkpoint(legal)
	var bytes := FileAccess.get_file_as_bytes(legal.repository.path)
	var checkpoint := legal.profile.run_checkpoint.duplicate(true)
	var revision := legal.profile.revision
	var saves := (legal.repository as FailingRepository).save_calls
	_check(legal.restore() and _json_equal(legal.to_checkpoint(), checkpoint), "legal old relic ownership resumes unchanged")
	_check(legal.profile.revision == revision and (legal.repository as FailingRepository).save_calls == saves and FileAccess.get_file_as_bytes(legal.repository.path) == bytes, "legal ready checkpoints need no compatibility save")
	for conflict in ["exclusive", "capability"]:
		var old := _new_run("compat-" + conflict, "normal", &"frost" if conflict == "exclusive" else &"flame")
		var assets := {&"R003": 2, &"R004": 2, &"R031": 1, &"R032": 1, &"R044": 1, &"R045": 1} if conflict == "exclusive" else {&"R004": 1}
		for id: StringName in assets:
			for layer: int in assets[id]:
				old.selection.instances.append(_legacy_relic(id, "%s:%s:%d" % [conflict, id, layer]))
		old.phase = "BATTLE"
		old.room_serial = 1
		old.attempt_id = "compat-" + conflict + ":attempt"
		old.facts["checkpoint_characters"] = 11
		old = _save_legacy_checkpoint(old)
		bytes = FileAccess.get_file_as_bytes(old.repository.path)
		checkpoint = old.profile.run_checkpoint.duplicate(true)
		revision = old.profile.revision
		saves = (old.repository as FailingRepository).save_calls
		_check(not old.restore() and "旧局已保留" in old.last_error and "重开" in old.last_error, "new %s requirements reject the old build through the preserved-run path" % conflict)
		_check(old.profile.has_pending_run() and _json_equal(old.profile.run_checkpoint, checkpoint) and old.profile.revision == revision, "rejected %s ownership retains the original checkpoint and revision" % conflict)
		_check((old.repository as FailingRepository).save_calls == saves and FileAccess.get_file_as_bytes(old.repository.path) == bytes, "rejected %s battle does not publish resume state or alter the file" % conflict)
		var settings := AppSettings.new()
		_check(old.restart(&"storm", settings) and old.selection.instances.is_empty(), "explicit restart remains available after an incompatible %s build" % conflict)
	for old_phase in ["REWARD", "BATTLE_REWARD"]:
		var old := _reward_fixture("compat-offer-" + old_phase)
		old.phase = old_phase
		old.attempt_id = "compat-offer:attempt"
		old.offer.candidates = ["R045", "G027", "R005"]
		old = _save_legacy_checkpoint(old)
		var obsolete_id: String = old.profile.run_checkpoint.offer.id
		var reward_state: Dictionary = old.profile.run_checkpoint.rewards.duplicate(true)
		var rerolls: int = old.profile.run_checkpoint.facts.rerolls
		var serial: int = old.profile.run_checkpoint.facts.offer_serial
		bytes = FileAccess.get_file_as_bytes(old.repository.path)
		checkpoint = old.profile.run_checkpoint.duplicate(true)
		revision = old.profile.revision
		saves = (old.repository as FailingRepository).save_calls
		(old.repository as FailingRepository).reject_next = true
		_check(not old.restore(), "a failed %s offer migration remains recoverable" % old_phase)
		_check(_json_equal(old.profile.run_checkpoint, checkpoint) and old.profile.revision == revision and FileAccess.get_file_as_bytes(old.repository.path) == bytes, "failed %s offer migration publishes no quote, RNG or resume state" % old_phase)
		_check(old.restore(), "%s offer with obsolete qualification is rebuilt" % old_phase)
		_check(old.profile.revision == revision + 1 and (old.repository as FailingRepository).save_calls == saves + 2, "%s offer and battle resume publish one successful save transaction" % old_phase)
		_check(old.phase == "REWARD" and str(old.offer.id).begins_with(old.run_id + ":reward:") and str(old.offer.id) != obsolete_id and int(old.facts.offer_serial) == serial + 1, "%s refresh keeps the run identity and advances the quote once" % old_phase)
		_check(_json_equal(old.rewards.to_dict(), reward_state) and int(old.facts.rerolls) == rerolls, "%s automatic refresh spends no reward or reroll" % old_phase)
		var service := AcquisitionService.new(old.compiler)
		for id: String in old.offer.candidates:
			_check(service.evaluate(old.selection, StringName(id), old.acquisition_context()).eligible, "refreshed offer contains only currently eligible IDs: " + id)
		var fresh := old.offer.duplicate(true)
		var reloaded := RunSession.new(old.repository, old.repository.load_profile())
		saves = (old.repository as FailingRepository).save_calls
		_check(reloaded.restore() and reloaded.offer == fresh and (old.repository as FailingRepository).save_calls == saves, "%s refreshed offer reopens without a second redraw" % old_phase)
		var chosen := StringName(reloaded.offer.candidates[0])
		_check(not reloaded.take_reward(chosen, obsolete_id), "obsolete %s quote cannot acquire the refreshed reward" % old_phase)
		_check(reloaded.take_reward(chosen, str(fresh.id)), "refreshed %s quote acquires through the real transaction" % old_phase)
		revision = reloaded.profile.revision
		var owned := reloaded.selection.instances.size()
		_check(reloaded.take_reward(chosen, str(fresh.id)) and reloaded.profile.revision == revision and reloaded.selection.instances.size() == owned, "repeated %s acquisition retains its once-only receipt" % old_phase)
	var empty := _reward_fixture("compat-empty-offer")
	empty.offer.candidates.clear()
	empty = _save_legacy_checkpoint(empty)
	_check(empty.restore() and not empty.offer.candidates.is_empty(), "an old exhausted pool quote becomes a reward when the expanded pool is reachable")


func _legacy_relic(id: StringName, identity: String) -> CombatAssetInstance:
	var instance := CombatAssetInstance.new()
	instance.instance_id = identity
	instance.content_id = id
	instance.source_id = &"reward"
	return instance


func _save_legacy_checkpoint(session: RunSession) -> RunSession:
	var proposed := session.profile.copy()
	proposed.run_checkpoint = session.to_checkpoint()
	proposed.revision += 1
	_check(session.repository.save_profile(proposed, session.profile.revision), "old ownership/offer fixture uses the real profile writer")
	return RunSession.new(session.repository, session.repository.load_profile())


func _test_full_pool_supply() -> void:
	var session := _new_run("full-pool")
	var service := AcquisitionService.new(session.compiler)
	var acquired := 0
	for index in 240:
		var available := service.candidates(session.selection, {"shortest": 3, "longest": 7})
		if available.is_empty(): break
		_acquire_fixture(session, StringName(available[0]), "full-pool:%d" % index)
		acquired += 1
	_check(acquired > 0 and service.candidates(session.selection, {"shortest": 3, "longest": 7}).is_empty(), "legal per-book relic pool is fully stacked through actual acquisition rules")
	session.phase = "REWARD"
	session.room_serial = 1
	session.rewards.earned += 1
	session.facts["vocabulary_letters"] = ["ash", "archive"]
	session.facts["route_complete"] = true
	session.combat.hp_q = 40 * Q
	session._make_reward_offer(session)
	session = _persist_fixture(session)
	_check(session.offer.candidates.is_empty(), "full pool creates an actual empty candidate offer")
	var offer_id: String = session.offer.id
	var before_spent := session.rewards.spent
	var bytes := FileAccess.get_file_as_bytes(session.repository.path)
	(session.repository as FailingRepository).reject_next = true
	_check(not session.supply_reward(offer_id), "supply save failure is reported")
	_check(session.combat.hp_q == 40 * Q and session.pending_dodge == 0 and session.rewards.spent == before_spent and FileAccess.get_file_as_bytes(session.repository.path) == bytes, "failed supply grants nothing and spends nothing")
	_check(session.supply_reward(offer_id), "empty-pool supply commits")
	_check(session.combat.hp_q == 65 * Q and session.pending_dodge == 1 and session.rewards.spent == before_spent + 1 and session.phase == "READY_FOR_ROOM", "supply restores 25 health and one opening dodge while spending one reward")
	var after := session.to_checkpoint()
	var revision := session.profile.revision
	_check(session.supply_reward(offer_id) and session.to_checkpoint() == after and session.profile.revision == revision, "duplicate supply does not restore or spend again")
	var maximum := session.compiler.compile(session.selection).build.maximum_hp_q()
	session.combat.hp_q = maximum - 10 * Q
	session.phase = "REWARD"
	session.rewards.earned += 1
	session._make_reward_offer(session)
	session = _persist_fixture(session)
	_check(session.supply_reward(str(session.offer.id)) and session.combat.hp_q == maximum, "supply health is capped at the actual build maximum")
	evidence.append({"kind": "full legal pool transaction fixture", "book": "frost", "instances": acquired, "supply_health": 25, "supply_dodge": 1})


func _formal_run(book: StringName, session: RunSession = null, cps: float = 60.0 / 9.0, assessment: bool = false, label: String = "formal") -> bool:
	if session == null: session = _new_run("formal-" + str(book), "normal", book)
	_check(session.itinerary.encounters.size() == 9, "formal run uses the complete nine-room itinerary")
	if session.itinerary.encounters.size() != 9: return false
	var entries: Array[VocabularyEntry] = [VocabularyEntry.new("ash", "灰"), VocabularyEntry.new("frost", "霜"), VocabularyEntry.new("archive", "档案")]
	for serial in 9:
		var request := session.start_room(entries, VocabularyIndex.build(entries))
		_check(request != null, "formal room departure persists")
		if request == null: return false
		battle = BattleSession.new()
		battle.start(request, session.combat)
		session.install_room_opening(battle)
		var wall_start := Time.get_ticks_usec()
		var event_counts: Dictionary = {}
		var attack_outcomes: Dictionary = {}
		var hp_trace := {"last_q": battle.player_hp_q, "lost_q": 0, "restored_q": 0}
		var progression_failed: Array[bool] = [false]
		battle.progression_changed.connect(func() -> void:
			if not session.observe_battle(battle):
				_check(false, "formal checkpoint failed: " + session.last_error)
				progression_failed[0] = true
		)
		battle.event_committed.connect(func(event: Dictionary) -> void:
			var kind := str(event.get("kind", ""))
			event_counts[kind] = int(event_counts.get(kind, 0)) + 1
			if kind == "enemy_attack":
				var outcome := str(event.get("outcome", ""))
				attack_outcomes[outcome] = int(attack_outcomes.get(outcome, 0)) + 1
			_trace_hp(hp_trace)
		)
		var observed_phases: Dictionary = {}
		var maximum_threats := 0
		var next_character := 0.0
		var scheduled_slots := 0
		var submitted_characters := 0
		var injected_errors := 0
		var error_pending := false
		var relics: PackedStringArray = []
		for instance in session.selection.instances: relics.append(str(instance.content_id))
		var departure_instances := session.selection.instances.size()
		var departure_hp := float(battle.player_hp_q) / Q
		router.typing = battle.typing
		router.configure(InputRouter.Context.TYPING)
		for frame in 24000:
			if battle.result != 0: break
			if session.phase == "BATTLE_REWARD": _formal_rewards(session, battle)
			_defend()
			if battle.resonance_q >= BattleSession.ULTIMATE_COST_Q:
				_key(KEY_SHIFT)
				_key(KEY_SHIFT, 0, false)
			if float(frame) / 60.0 >= next_character:
				next_character += 1.0 / cps
				scheduled_slots += 1
				if battle.typing.target_id == &"": _key(KEY_TAB)
				var word := battle.typing.word.replace(" ", "")
				if battle.typing.target_id != &"" and battle.typing.progress < word.length():
					var character := word[battle.typing.progress]
					submitted_characters += 1
					if "--mistakes" in OS.get_cmdline_user_args() and submitted_characters % 20 == 0: error_pending = true
					if error_pending and battle.typing.progress > 0:
						character = _wrong_character()
						injected_errors += 1
						error_pending = false
					_key(character.to_upper().unicode_at(0), character.unicode_at(0))
			battle.step(1.0 / 60.0)
			_trace_hp(hp_trace)
			maximum_threats = maxi(maximum_threats, battle.threats.size())
			for enemy in battle.enemies:
				if enemy.boss: observed_phases[enemy.phase] = true
			if progression_failed[0]: break
		var remaining: Array[Dictionary] = []
		if battle.result != 1:
			for enemy in battle.enemies:
				if enemy.alive(): remaining.append({"id": str(enemy.id), "kind": str(enemy.kind), "hp": float(enemy.hp_q) / Q, "boss": enemy.boss, "phase": enemy.phase, "position": str(enemy.position), "word": enemy.word})
		var report := {"kind": "formal Unicode battle", "book": str(book), "room": serial + 1, "result": battle.result, "seconds": battle.elapsed, "hp": float(battle.player_hp_q) / Q, "characters": battle.manual_characters, "words": battle.completed_words, "encounter": request.encounter.resource_path, "relics_at_departure": relics, "boss_phases": observed_phases.keys(), "maximum_threats": maximum_threats, "remaining_enemies": remaining, "failure_input": battle.typing.word if battle.result != 1 else ""}
		report.merge({"scenario": label, "difficulty": session.options.difficulty, "round": session.facts.get("round_index", 0), "loop": session.options.get("loop_index", 0), "input_cps": cps, "input_accuracy": float(battle.manual_characters) / maxi(1, submitted_characters), "mistakes_requested": "--mistakes" in OS.get_cmdline_user_args(), "scheduled_slots": scheduled_slots, "submitted_characters": submitted_characters, "errors": battle.typing.mistakes, "injected_errors": injected_errors, "growth_hp": session.selection.growth_hp, "seed": session.seed_text, "maximum_hp": float(battle.compiled_build.maximum_hp_q()) / Q})
		_check(battle.typing.mistakes == injected_errors, "wrong-letter input is actually rejected by the Unicode typing route")
		report.merge({"wall_seconds": float(Time.get_ticks_usec() - wall_start) / 1000000.0, "event_counts": event_counts, "timeout": battle.result == 0, "wave": battle.wave})
		report.merge({"attack_outcomes": attack_outcomes, "hp_loss_observed": float(hp_trace.lost_q) / Q, "hp_restore_observed": float(hp_trace.restored_q) / Q})
		report["departure_hp"] = departure_hp
		if not assessment: _check(battle.result == 1 and battle.manual_characters > 0, "formal nine-room victory is earned from accepted input")
		if battle.result != 1:
			report["relics_gained"] = _new_relics(session, departure_instances)
			if battle.result == -1:
				_check(session.finish_room(battle), "actual balance defeat settlement saves")
				report["after_boundary_hp"] = float(session.combat.hp_q) / Q
			evidence.append(report)
			print("S2 FORMAL ROOM ", JSON.stringify(report))
			battle.free()
			battle = null
			return false
		_check(session.finish_room(battle), "formal room settlement saves")
		battle.free()
		battle = null
		if serial < 8:
			_formal_rewards(session)
			_check(session.take_route("rest"), "formal rest route advances")
		report["relics_gained"] = _new_relics(session, departure_instances)
		report["after_boundary_hp"] = float(session.combat.hp_q) / Q
		evidence.append(report)
		print("S2 FORMAL ROOM ", JSON.stringify(report))
	_check(session.phase == "RESULT" and bool(session.facts.get("victory_pending", false)) and session.profile.records.size() == int(session.facts.get("round_index", 0)) + 1, "formal ninth-room victory retains a pending continuation and one record per earned round")
	if assessment: return true
	var assets := _inherited_selection(session.selection)
	var characters := session.profile.manual_characters
	var identity := session.run_id
	_check(session.continue_challenge() and session.run_id == identity and _inherited_selection(session.selection) == assets and session.options.difficulty == "hard", "formal victory keeps earned relics and advances to hard")
	_check(session.profile.manual_characters == characters and session.profile.records.size() == 1, "formal continuation does not replay previous earnings")
	return true


func _balance_matrix() -> void:
	# First assessment stage: high-speed cold apocalypse, then medium retained ascent.
	# Expand the other modes/speeds only after the product pressure target is assessed.
	var grown := "--grown-retained" in OS.get_cmdline_user_args()
	if "--retained-only" not in OS.get_cmdline_user_args() and not grown:
		for book in [&"frost", &"storm", &"spirit", &"flame"]:
			if not sampling_book.is_empty() and str(book) != sampling_book: continue
			var label := "cold-%s-apocalypse-8" % book
			var session := _new_run(label, "apocalypse", book, false, sampling_seed)
			_balance_round(book, session, 8.0, label)
	if "--cold-only" in OS.get_cmdline_user_args(): return
	var chain_books: Array[StringName] = [&"frost", &"storm", &"spirit", &"flame"]
	if grown: chain_books.assign([&"frost", &"spirit", &"flame"])
	for book in chain_books:
		if not sampling_book.is_empty() and str(book) != sampling_book: continue
		var chain_label := ("grown-retained-%s" if grown else "retained-%s") % book
		var chain := _new_run(chain_label, "normal", book, grown, sampling_seed)
		for round_index in 4:
			if not _balance_round(book, chain, 5.0, chain_label): break
			if round_index < 3:
				_check(chain.continue_challenge(), "balance earned continuation commits")
				evidence.append({"kind": "balance continuation", "scenario": chain_label, "book": str(book), "difficulty": chain.options.difficulty, "round": chain.facts.get("round_index", 0), "run_id": chain.run_id, "hp": float(chain.combat.hp_q) / Q, "growth_hp": chain.selection.growth_hp, "relics": _new_relics(chain, 0), "rerolls": chain.facts.rerolls})


func _balance_round(book: StringName, session: RunSession, cps: float, label: String) -> bool:
	var mode := str(session.options.difficulty)
	var round_index := int(session.facts.get("round_index", 0))
	var start_assets := session.selection.instances.size()
	var start_characters := session.profile.manual_characters
	var evidence_start := evidence.size()
	var completed := _formal_run(book, session, cps, true, label)
	var accepted := 0
	var submitted := 0
	var errors := 0
	for index in range(evidence_start, evidence.size()):
		if evidence[index].get("kind") == "formal Unicode battle":
			accepted += int(evidence[index].characters)
			submitted += int(evidence[index].submitted_characters)
			errors += int(evidence[index].errors)
	var report := {"kind": "balance round", "scenario": label, "book": str(book), "difficulty": mode, "round": round_index, "completed": completed, "input_cps": cps, "accuracy": float(accepted) / maxi(1, submitted), "submitted_characters": submitted, "accepted_characters": accepted, "errors": errors, "mistakes_requested": "--mistakes" in OS.get_cmdline_user_args(), "seed": session.seed_text, "run_id": session.run_id, "growth_hp": session.selection.growth_hp, "start_relic_instances": start_assets, "end_relic_instances": session.selection.instances.size(), "new_saved_characters": session.profile.manual_characters - start_characters, "phase": session.phase, "hp": float(session.combat.hp_q) / Q}
	evidence.append(report)
	print("S3 BALANCE ROUND ", JSON.stringify(report))
	return completed


func _range_check() -> void:
	for book in [&"frost", &"storm", &"spirit", &"flame"]:
		if not sampling_book.is_empty() and str(book) != sampling_book: continue
		for setting in [{"mode": "normal", "cps": 3.0, "growth": false}, {"mode": "nightmare", "cps": 8.0, "growth": false}, {"mode": "apocalypse", "cps": 8.0, "growth": true}]:
			var label := "range-%s-%s-%d-%s" % [book, setting.mode, setting.cps, "grown" if setting.growth else "zero"]
			var session := _new_run(label, str(setting.mode), book, bool(setting.growth), sampling_seed)
			_balance_round(book, session, float(setting.cps), label)


func _new_relics(session: RunSession, from_index: int) -> PackedStringArray:
	var result := PackedStringArray()
	for index in range(from_index, session.selection.instances.size()):
		result.append(str(session.selection.instances[index].content_id))
	return result


func _trace_hp(trace: Dictionary) -> void:
	var change := battle.player_hp_q - int(trace.last_q)
	if change < 0: trace.lost_q = int(trace.lost_q) - change
	else: trace.restored_q = int(trace.restored_q) + change
	trace.last_q = battle.player_hp_q


func _wrong_character() -> String:
	# Avoid TypingSession's valid prefix-retarget route so this is a real typo.
	var prefix := battle.typing.word.replace(" ", "").left(battle.typing.progress)
	var next_letters := ""
	for target_word in battle.typing._targets.values():
		var playable := str(target_word).replace(" ", "")
		if playable.begins_with(prefix) and playable.length() > prefix.length():
			next_letters += playable[prefix.length()]
	for candidate in "zqxjvbnmklywpfghsdrtuioeac":
		if candidate not in next_letters: return candidate
	return "z"


func _formal_rewards(session: RunSession, live: BattleSession = null) -> void:
	for index in 32:
		if session.phase not in ["REWARD", "BATTLE_REWARD"]: return
		if session.offer.candidates.is_empty():
			_check(session.supply_reward(str(session.offer.id), live), "formal empty-pool supply")
		else:
			var chosen := StringName(session.offer.candidates[0])
			for id in ["R001", "R016", "R012", "R019", "R039", "R024"]:
				if id in session.offer.candidates:
					chosen = StringName(id)
					break
			_check(session.take_reward(chosen, str(session.offer.id), "", live), "formal relic acquisition: " + session.last_error)
	_check(false, "formal reward queue did not drain")


func _defend() -> void:
	if battle.dodge_window > 0.0 or battle.parry_window > 0.0: return
	for hazard in battle.hazards:
		# Hazard contact ignores parry. Use the genuine Alt safe-direction route.
		if hazard.contains(battle.player_position) and hazard.warning_remaining < 0.18 and battle.dodge_charges >= 1.0:
			_key(KEY_ALT)
			return
	var imminent := false
	for threat in battle.threats:
		var origin := threat.position * BattleSession.ARENA_SIZE
		var nearest := Geometry2D.get_closest_point_to_segment(battle.player_position * BattleSession.ARENA_SIZE, origin, origin + threat.velocity * 0.12)
		if nearest.distance_to(battle.player_position * BattleSession.ARENA_SIZE) < 58.0: imminent = true
	for enemy in battle.enemies:
		if enemy.alive() and enemy.aiming and enemy.attack_clock < 0.15 and enemy.position.distance_to(battle.player_position) * 800.0 < 160.0: imminent = true
	if imminent:
		if battle.parry_cooldown <= 0.0: _key(KEY_SPACE)
		elif battle.dodge_charges >= 1.0: _key(KEY_ALT)


func _key(code: Key, unicode: int = 0, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = pressed
	router._input(event)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _json_equal(left: Dictionary, right: Dictionary) -> bool:
	# JSON has one number type; compare the same persisted representation on both sides.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _inherited_selection(selection: BuildSelection) -> Dictionary:
	var data := selection.to_dict()
	data.erase("base_hp") # The next difficulty changes this documented baseline.
	return data
