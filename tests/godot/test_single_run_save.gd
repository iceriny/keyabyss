extends SceneTree
## Transaction fixtures only: no claimed battle victory or gameplay assessment.

var checks := 0
var failures := 0
var base: String

class RejectingRepository:
	extends SaveRepository
	var reject_next := false
	var reject_revision := -1
	func save_profile(candidate: ProfileState, expected_revision: int) -> bool:
		if reject_next or candidate.revision == reject_revision:
			reject_next = false
			reject_revision = -1
			last_error = "INJECTED_SAVE_FAILURE"
			return false
		return super.save_profile(candidate, expected_revision)

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	base = "res://.temp/feedback-20261008/save/fixture-%d" % Time.get_ticks_usec()
	var repo := RejectingRepository.new(&"normal", base)
	var run := RunSession.new(repo, repo.load_profile())
	var settings := AppSettings.new()
	settings.difficulty = "normal"
	check(run.begin(&"frost", settings), "first begin saves one run")
	var original_id := run.run_id
	var bytes := FileAccess.get_file_as_bytes(repo.path)
	check(run.has_pending_run() and not run.begin(&"storm", settings), "begin cannot silently overwrite")
	check(FileAccess.get_file_as_bytes(repo.path) == bytes and run.run_id == original_id, "rejected begin preserves original bytes and state")
	repo.reject_next = true
	check(not run.restart(&"storm", settings), "failed explicit restart rejects whole transaction")
	check(FileAccess.get_file_as_bytes(repo.path) == bytes and run.run_id == original_id and run.profile.records.is_empty(), "failed restart publishes neither closure nor replacement")
	var revision := run.profile.revision
	check(run.restart(&"storm", settings), "explicit restart succeeds")
	check(run.profile.revision == revision + 1 and run.run_id != original_id and run.profile.records.size() == 1, "restart is one revision and one old-run record")
	check(run.profile.records[0].run_id == original_id and run.profile.records[0].reason == "abandon", "old run recorded as explicitly ended")
	check(not run.profile.records[0].has("stats"), "unobserved run has no fabricated zero statistics")
	_test_room_restore(run, repo)
	var records := run.profile.records.size()
	bytes = FileAccess.get_file_as_bytes(repo.path)
	repo.reject_next = true
	check(not run.end_run(), "failed end preserves pending run")
	check(FileAccess.get_file_as_bytes(repo.path) == bytes and run.has_pending_run(), "failed end does not publish cleared checkpoint")
	check(run.end_run(), "end closes persisted room-replay run")
	check(run.profile.run_checkpoint.is_empty() and not run.has_pending_run() and run.profile.records.size() == records + 1, "end clears checkpoint and records exactly once")
	revision = run.profile.revision
	check(run.end_run() and run.profile.revision == revision and run.profile.records.size() == records + 1, "duplicate end has no payment or record")
	var reopened := RunSession.new(repo, repo.load_profile())
	check(reopened.restore() and not reopened.has_pending_run(), "history cannot become a continue target")
	check(reopened.begin(&"spirit", settings), "new run allowed after explicit end")
	var god_repo := SaveRepository.new(&"god", base)
	check(god_repo.load_profile().run_checkpoint.is_empty() and god_repo.load_profile().records.is_empty(), "normal saves do not change God archive")
	_test_god_transfer(reopened)
	_test_reward_restore()
	_test_suspend_without_reward()
	_test_statistics()
	print("Single run save: %d checks, %d failures; evidence %s" % [checks, failures, base])
	quit(0 if failures == 0 else 1)

func _test_room_restore(run: RunSession, repo: RejectingRepository) -> void:
	var entries: Array[VocabularyEntry] = [VocabularyEntry.new("ash", "灰")]
	var request := run.start_room(entries, VocabularyIndex.build(entries))
	check(request != null, "formal start request persists BATTLE")
	var attempt := run.attempt_id
	var fact_id := JSON.stringify([run.run_id, request.room_serial, attempt, "enemy_1"])
	var fact := RewardFact.new(fact_id, 1, request.chapter, false)
	# Explicit saved-income fixture, through actual checkpoint settlement and repository.
	check(run.rewards.consume(fact).diagnostics.is_empty(), "fixture reward uses real ledger")
	run.facts["checkpoint_characters"] = 10
	var receipt := RoomSettlementReceipt.new(run.run_id, run.room_serial, attempt, &"checkpoint", 10, &"normal")
	var updated: ProfileState = TalentProgress.prepare_checkpoint(run.profile, receipt).profile
	updated.run_checkpoint = run.to_checkpoint()
	updated.revision += 1
	check(repo.save_profile(updated, run.profile.revision), "explicit partial-room checkpoint saves")
	run.profile = repo.load_profile()
	check(run.restore(), "restore keeps original expedition")
	check(run.phase == "READY_FOR_ROOM" and run.room_serial == 0 and run.profile.manual_characters == 10, "restore re-enters unfinished room and preserves income")
	var replay := run.start_room(entries, VocabularyIndex.build(entries))
	check(replay.attempt_id == attempt and replay.room_serial == request.room_serial and replay.run_id == request.run_id, "replay retains exact original reward identity")
	var battle := BattleSession.new()
	battle.run_state = run.combat
	battle.player_hp_q = run.combat.hp_q
	battle.manual_characters = 5
	battle.reward_facts.append(RewardFact.new(fact_id, 1, request.chapter, true))
	var before := run.rewards.to_dict()
	check(run.observe_battle(battle), "old reward identity accepted without conflict after R021 change")
	check(run.rewards.to_dict() == before, "saved experience and opportunities not awarded twice")
	check(run.end_run(battle), "live end includes only new replay characters")
	check(run.profile.manual_characters == 15 and run.profile.run_checkpoint.is_empty(), "saved ten plus five new characters counted once")
	battle.free()
	# Start another real run so outer assertions cover closure before any battle.
	var settings := AppSettings.new()
	check(run.begin(&"frost", settings), "begin after replay closure")

func _test_god_transfer(normal: RunSession) -> void:
	var god_repo := RejectingRepository.new(&"god", base)
	var god := RunSession.new(god_repo, god_repo.load_profile())
	var settings := AppSettings.new()
	check(god.begin(&"storm", settings), "God existing run fixture saves")
	var source_bytes := FileAccess.get_file_as_bytes(normal.repository.path)
	check(not normal.isolate_to_god(god_repo), "existing God pending rejects activation")
	check(source_bytes == FileAccess.get_file_as_bytes(normal.repository.path), "God conflict leaves ordinary run untouched")
	check(god.end_run(), "explicit fixture cleanup closes God run")
	var god_history := god.profile.records.duplicate(true)
	var source_history := normal.profile.records.duplicate(true)
	var starting_characters := normal.profile.manual_characters
	var entries: Array[VocabularyEntry] = [VocabularyEntry.new("ash", "灰")]
	check(normal.start_room(entries, VocabularyIndex.build(entries)) != null, "normal active room transfer fixture starts")
	var live := BattleSession.new()
	live.run_state = normal.combat
	live.player_hp_q = normal.combat.hp_q
	live.manual_characters = 6
	var original_id := normal.run_id
	god_repo.reject_next = true
	check(not normal.isolate_to_god(god_repo, live), "failed God publication leaves a recoverable lock")
	check(normal.profile.run_checkpoint.facts.has("god_transfer") and normal.profile.manual_characters == starting_characters + 6, "source income sealed once and checkpoint locked")
	check(normal.repository.load_profile().records == source_history, "activation adds no false ordinary abandon history")
	check(not normal.restore() and not normal.end_run() and not normal.restart(&"flame", settings), "locked source cannot continue or overwrite")
	var recovered := RunSession.new(normal.repository, normal.repository.load_profile())
	check(recovered.isolate_to_god(god_repo), "transfer retry completes idempotently")
	check(recovered.repository.mode == &"god" and recovered.run_id == original_id, "same expedition adopted by God repository")
	check(normal.repository.load_profile().run_checkpoint.is_empty() and normal.repository.load_profile().manual_characters == starting_characters + 6, "ordinary checkpoint removed without loss or duplicate income")
	# Nested historical numbers return as floats after JSON; compare persisted semantics.
	check(JSON.parse_string(JSON.stringify(recovered.profile.records)) == JSON.parse_string(JSON.stringify(god_history)), "God preserves its own historical JSON data")
	check(recovered.profile.manual_characters == 0, "God imports no ordinary earnings")
	live.manual_characters = 9
	check(recovered.end_run(live), "God live end settles only post-activation characters")
	check(recovered.profile.manual_characters == 3 and recovered.profile.run_checkpoint.is_empty(), "six ordinary and three God characters remain isolated")
	var revision := recovered.profile.revision
	check(recovered.end_run() and recovered.profile.revision == revision, "God end remains idempotent")
	live.free()
	var source_repo := normal.repository as RejectingRepository
	var final_failure := RunSession.new(source_repo, source_repo.load_profile())
	check(final_failure.begin(&"flame", settings), "post-transfer ordinary fresh run starts")
	source_repo.reject_revision = final_failure.profile.revision + 2
	check(not final_failure.isolate_to_god(god_repo), "failure clearing source after God commit returns unfinished transfer")
	var published := god_repo.load_profile()
	check(published.has_pending_run() and final_failure.profile.run_checkpoint.facts.has("god_transfer"), "God commit retains locked source on final-write failure")
	var published_revision := published.revision
	var retry := RunSession.new(source_repo, source_repo.load_profile())
	check(retry.isolate_to_god(god_repo) and retry.profile.revision == published_revision, "retry clears source without republishing God or duplicating income")
	check(source_repo.load_profile().run_checkpoint.is_empty(), "final-write recovery leaves exactly one usable checkpoint")

func _test_reward_restore() -> void:
	var repo := RejectingRepository.new(&"normal", base.path_join("reward-resume"))
	var run := RunSession.new(repo, repo.load_profile())
	var settings := AppSettings.new()
	check(run.begin(&"frost", settings), "reward restore fixture begins real run")
	var entries: Array[VocabularyEntry] = [VocabularyEntry.new("ash", "灰")]
	check(run.start_room(entries, VocabularyIndex.build(entries)) != null, "reward restore fixture starts real room")
	var attempt := run.attempt_id
	var fact := RewardFact.new("reward-fixture", RewardPolicy.INITIAL_THRESHOLD, 1, false)
	check(run.rewards.consume(fact).diagnostics.is_empty(), "reward fixture earns actual ledger opportunity")
	run.phase = "BATTLE_REWARD"
	run.facts["checkpoint_characters"] = 6
	run._make_reward_offer(run)
	var quote := run.offer.duplicate(true)
	var updated: ProfileState = TalentProgress.prepare_checkpoint(run.profile, RoomSettlementReceipt.new(run.run_id, 1, attempt, &"checkpoint", 6, &"normal")).profile
	updated.run_checkpoint = run.to_checkpoint()
	updated.revision += 1
	check(repo.save_profile(updated, run.profile.revision), "explicit reward checkpoint fixture saves")
	run.profile = updated
	var paused_battle := BattleSession.new()
	paused_battle.run_state = run.combat
	paused_battle.player_hp_q = run.combat.hp_q
	paused_battle.manual_characters = 6
	paused_battle.reward_facts.append(fact)
	var earned := run.rewards.earned
	check(run.suspend_battle(paused_battle) and run.suspend_battle(paused_battle), "pending reward can suspend repeatedly")
	check(run.profile.manual_characters == 6 and run.rewards.earned == earned and JSON.stringify(run.offer) == JSON.stringify(quote), "pending reward suspend preserves quote without repaying characters or opportunities")
	paused_battle.free()
	var resumed := RunSession.new(repo, repo.load_profile())
	check(resumed.restore() and resumed.phase == "REWARD" and resumed.room_serial == 0, "saved room reward resumes before room replay")
	check(JSON.stringify(resumed.offer) == JSON.stringify(quote), "saved reward quote retained")
	check(resumed.skip_reward(str(resumed.offer.id)) and resumed.phase == "READY_FOR_ROOM", "finishing saved quote enters same room without route duplication")
	check(resumed.start_room(entries, VocabularyIndex.build(entries)).attempt_id == attempt and resumed.room_serial == 1, "reward resume uses original room and attempt")
	check(resumed.end_run() and resumed.profile.manual_characters == 6 and resumed.profile.records.size() == 1, "reward replay end seals saved characters exactly once")

func _test_suspend_without_reward() -> void:
	var repo := RejectingRepository.new(&"normal", base.path_join("suspend"))
	var run := RunSession.new(repo, repo.load_profile())
	var settings := AppSettings.new()
	check(run.begin(&"frost", settings), "suspend fixture begins")
	var entries: Array[VocabularyEntry] = [VocabularyEntry.new("ash", "灰")]
	var request := run.start_room(entries, VocabularyIndex.build(entries))
	check(request != null, "suspend fixture starts real room")
	var battle := BattleSession.new()
	battle.run_state = run.combat
	battle.player_hp_q = 91 * RunSession.Q
	battle.resonance_q = 12 * RunSession.Q
	battle.manual_characters = 11
	battle.reward_facts.append(RewardFact.new("suspend-fixture", 1, request.chapter, false))
	var bytes := FileAccess.get_file_as_bytes(repo.path)
	repo.reject_next = true
	check(not run.suspend_battle(battle) and FileAccess.get_file_as_bytes(repo.path) == bytes and run.profile.manual_characters == 0, "failed suspend publishes no income or checkpoint")
	check(run.suspend_battle(battle), "no-reward battle suspends through checkpoint receipt")
	check(run.phase == "BATTLE" and run.profile.manual_characters == 11 and run.profile.records.is_empty(), "suspend retains ongoing run without terminal record")
	check(run.combat.hp_q == 91 * RunSession.Q and run.combat.resonance_q == 12 * RunSession.Q and run.rewards.current == 1, "suspend saves current combat and reward facts")
	check(run.suspend_battle(battle) and run.profile.manual_characters == 11 and run.rewards.current == 1, "duplicate suspend does not repay characters or experience")
	var reopened := RunSession.new(repo, repo.load_profile())
	check(reopened.restore() and reopened.has_pending_run() and reopened.phase == "READY_FOR_ROOM", "suspended run returns to unfinished room")
	check(reopened.profile.manual_characters == 11 and reopened.combat.hp_q == 91 * RunSession.Q and reopened.profile.records.is_empty(), "suspend restore retains income and HP without history-as-continue")
	check(reopened.start_room(entries, VocabularyIndex.build(entries)).attempt_id == request.attempt_id, "suspend replay preserves original attempt for reward dedupe")
	var replay := BattleSession.new()
	replay.run_state = reopened.combat
	replay.player_hp_q = reopened.combat.hp_q
	replay.manual_characters = 4
	replay.reward_facts.append(battle.reward_facts[0])
	check(reopened.suspend_battle(replay) and reopened.profile.manual_characters == 15 and reopened.rewards.current == 1, "replay suspend adds only four new characters and no old reward")
	check(reopened.profile.run_checkpoint.run_id == request.run_id and reopened.profile.records.is_empty(), "suspend keeps exactly the same current checkpoint identity")
	battle.free()
	replay.free()


func _test_statistics() -> void:
	var repo := RejectingRepository.new(&"normal", base.path_join("statistics"))
	var run := RunSession.new(repo, repo.load_profile())
	var settings := AppSettings.new()
	var short_itinerary := RunItinerary.new()
	short_itinerary.encounters.append(load("res://game/content/single_room.tres"))
	run.itinerary = short_itinerary
	check(run.begin(&"frost", settings), "statistics fixture starts real run")
	var entries: Array[VocabularyEntry] = [VocabularyEntry.new("ash", "灰")]
	var request := run.start_room(entries, VocabularyIndex.build(entries))
	var battle := BattleSession.new()
	battle.start(request, run.combat)
	run.install_room_opening(battle)
	var target := battle.enemies[0]
	for enemy in battle.enemies:
		enemy.position = battle.player_position + Vector2(180, 120) / BattleSession.ARENA_SIZE
		enemy.previous_position = enemy.position
		enemy.attack_clock = 1000.0
	battle.typing.upsert_target(target.id, "ash")
	battle.typing.select_target(target.id)
	for character in "asxx": battle.typing.feed(character)
	battle.typing.cancel()
	battle.typing.select_target(target.id)
	for character in "ash": battle.typing.feed(character)
	battle.step(0.0)
	battle.typing.upsert_target(target.id, "ash")
	battle.typing.select_target(target.id)
	for character in "xa": battle.typing.feed(character)
	battle.runtime._assist_tokens = 1 # Explicit earned-opportunity fixture.
	battle.typing.complete_assisted()
	battle.step(0.0)
	var observed := battle.statistics.snapshot()
	check(observed.manual_characters == 6 and observed.best_correct_streak == 3 and observed.correct_streak == 1, "accepted characters form correct streak; assistance adds no manual characters: " + JSON.stringify(observed))
	check(observed.wrong_words == 2 and observed.mistakes == 3 and observed.wrong_word_counts.ash == 3, "first typo counts a word once even when abandoned, while repeated typos remain in per-word counts")
	check(observed.max_combo == 2, "gameplay combo counts committed words separately from correct-character streak")
	var combo_pickup := battle.spawn_pickup(&"rune")
	battle.typing.upsert_target(combo_pickup.id, "ash")
	battle.typing.select_target(combo_pickup.id)
	for character in "ash": battle.typing.feed(character)
	battle.step(0.0)
	check(combo_pickup.consumed and battle.statistics.max_combo == 3, "committed pickup word contributes to gameplay maximum combo")
	battle.runtime.on_player_hurt()
	check(battle.runtime._combo == 1 and battle.statistics.snapshot().max_combo == 3, "damage reduces current gameplay combo while its observed maximum remains")
	battle._commit_action(&"dodge_left")
	battle._commit_action(&"dodge_left")
	check(battle.statistics.dodges == 1, "only a launched dodge counts, blocked repeat does not")
	battle._dodge_time = 1.0
	battle.dodge_window = 0.0
	for grade: StringName in [&"success", &"perfect"]:
		battle.parry_cooldown = 0.0
		battle._commit_action(&"parry")
		battle.parry_window = 0.15 if grade == &"success" else 0.25
		for index in 2:
			var shot := BattleThreat.new()
			shot.position = battle.player_position + Vector2(35, 0) / BattleSession.ARENA_SIZE
			shot.previous_position = shot.position
			shot.velocity = Vector2(-200, 0)
			shot.source_id = target.id
			shot.attack_id = "statistics-defense-%s-%d" % [grade, index]
			shot.damage_q = 10 * BattleSession.Q
			shot.radius = 6.0
			battle.threats.append(shot)
		battle._advance_threats(0.05)
	check(battle.statistics.defense_successes == 2 and battle.statistics.perfect_defenses == 1, "defense success counts once per action despite multiple contacts; perfect remains a subset")
	battle.resonance_q = BattleSession.ULTIMATE_COST_Q
	battle._commit_action(&"ultimate")
	battle._commit_action(&"ultimate")
	check(battle.statistics.ultimates == 1, "only actual ultimate release counts")
	check(run.suspend_battle(battle) and run.suspend_battle(battle), "real statistics can checkpoint repeatedly")
	check(run.facts.result_stats.manual_characters == 9 and run.facts.result_stats.defense_successes == 2, "same live segment checkpoint overwrites instead of doubling totals")
	var saved_damage := int(run.facts.result_stats.damage_q)
	var reopened := RunSession.new(repo, repo.load_profile())
	reopened.itinerary = short_itinerary
	check(reopened.restore(), "statistics checkpoint reopens")
	var replay := BattleSession.new()
	replay.start(reopened.start_room(entries, VocabularyIndex.build(entries)), reopened.combat)
	reopened.install_room_opening(replay)
	var replay_target := replay.enemies[0]
	replay_target.position = Vector2(0.5, 0.35)
	replay_target.previous_position = replay_target.position
	replay.typing.upsert_target(replay_target.id, "ash")
	replay.typing.select_target(replay_target.id)
	for character in "ash": replay.typing.feed(character)
	replay.step(0.0)
	check(replay.statistics.best_correct_streak == 7, "correct streak continues across saved-room replay from real saved tail")
	check(replay.runtime._combo == 2 and replay.statistics.max_combo == 2, "gameplay combo follows restored runtime counters and the new committed word")
	var previous_damage := replay.statistics.damage_q
	replay.runtime._deal(replay_target, 7 * BattleSession.Q, &"statistics-fixture", replay.player_position)
	check(replay.statistics.damage_q == previous_damage + 7 * BattleSession.Q, "runtime damage contributes its committed applied damage exactly once")
	var runtime_damage := replay.runtime.actual_damage_q
	replay.commit_damage(replay_target, 5 * BattleSession.Q, 5 * BattleSession.Q, &"statistics-direct-fixture", replay.player_position)
	check(replay.statistics.damage_q == previous_damage + 12 * BattleSession.Q and replay.runtime.actual_damage_q == runtime_damage, "direct session damage is counted even outside the runtime damage counter")
	for enemy in replay.enemies:
		if enemy != replay_target: enemy.position = Vector2(0.15, 0.15)
	var victim := replay._spawn_enemy(load("res://game/content/enemies/nib.tres"), replay_target.position + Vector2(100, 0) / BattleSession.ARENA_SIZE)
	victim.hp_q = 20 * BattleSession.Q # Explicit overkill fixture for the real 35-point death pull.
	victim.max_hp_q = victim.hp_q
	replay._enemy_definitions[replay_target.id] = load("res://game/content/enemies/vortex.tres")
	var remaining_hp := replay_target.hp_q
	replay.runtime._deal(replay_target, remaining_hp + 50 * BattleSession.Q, &"statistics-fixture", replay.player_position)
	var expected_damage := previous_damage + 12 * BattleSession.Q + remaining_hp + 20 * BattleSession.Q
	check(not victim.alive() and replay.statistics.kills == 2 and replay.statistics.damage_q == expected_damage, "vortex death chain counts recursive direct damage and excludes overkill without doubling its initiating runtime hit")
	# Explicit room-boundary victory fixture: this tests saving, not earned gameplay victory.
	replay.result = 1
	var bytes := FileAccess.get_file_as_bytes(repo.path)
	repo.reject_next = true
	check(not reopened.finish_room(replay) and FileAccess.get_file_as_bytes(repo.path) == bytes and reopened.profile.records.is_empty(), "failed result save publishes no partial statistics or record")
	check(reopened.finish_room(replay) and reopened.finish_room(replay), "statistics boundary retry and duplicate finish succeed")
	var stats: Dictionary = reopened.facts.result_stats
	check(stats.manual_characters == 12 and stats.best_correct_streak == 7 and stats.wrong_words == 2 and stats.kills == 2 and stats.damage_q == saved_damage + expected_damage, "replayed segment adds only new observations and all applied damage once")
	check(stats.max_combo == 3, "round gameplay maximum combo takes the segment maximum rather than summing maxima")
	check(reopened.profile.records.size() == 1 and reopened.profile.records[0].stats == stats, "result record contains exactly the committed round statistics")
	var persisted := repo.load_profile()
	check(persisted.records[0].stats.manual_characters == 12 and persisted.records[0].stats.wrong_word_counts.ash == 3 and persisted.records[0].stats.max_combo == 3, "statistics, gameplay combo and wrong-word counts survive archive serialization")
	check(reopened.continue_challenge(), "statistics challenge continuation saves")
	check(not reopened.facts.has("result_stats") and not reopened.facts.has("round_stats") and not reopened.facts.has("statistics_segments"), "next challenge starts fresh statistics while prior archive remains")
	battle.free()
	replay.free()
