class_name RunSession
extends RefCounted
## Owns persisted run transitions. A battle owns only its current fixed-step world.

const Q := 1024
const DIFFICULTIES := ["story", "normal", "hard", "nightmare", "apocalypse"]
const DIFFICULTY_NAMES := ["启程", "冒险", "深渊", "噩梦", "灭世"]
const STARTING_HEALTH := [155, 125, 110, 100, 90]
const SERIALIZED := ["run_id", "phase", "room_serial", "attempt_id", "seed_text", "options", "facts", "offer", "contracts", "transactions", "used_events", "pending_dodge", "pending_opening", "reward_rng_state", "event_rng_state"]
var repository: SaveRepository
var profile: ProfileState
var compiler := BuildCompiler.new()
var itinerary: RunItinerary = preload("res://game/content/s2_itinerary.tres")
var selection := BuildSelection.new()
var combat := RunCombatState.new()
var rewards := RewardLedger.new()
var pledged: Array[CombatAssetInstance] = []
var run_id: String
var phase: String = "RESULT"
var room_serial: int = 0
var attempt_id: String
var seed_text: String
var options: Dictionary = {}
var facts: Dictionary = {}
var offer: Dictionary = {}
var contracts: Array[Dictionary] = []
var transactions: Dictionary = {}
var used_events: PackedStringArray = []
var pending_dodge: int = 0
var pending_opening: Array[Dictionary] = []
var reward_rng_state: String = "0"
var event_rng_state: String = "0"
var last_error: String
var _pending_boundary: RunSession


func _init(saves: SaveRepository = null, state: ProfileState = null) -> void:
	repository = saves
	profile = state


func begin(book_id: StringName, settings: AppSettings) -> bool:
	if has_pending_run():
		last_error = "已有进行中的远征，请继续或明确重开。"
		return false
	var candidate := _new_candidate(book_id, settings, profile)
	return candidate != null and _save(candidate)


func has_pending_run() -> bool:
	return profile.has_pending_run()


func restart(book_id: StringName, settings: AppSettings, battle: BattleSession = null) -> bool:
	var ended := _prepare_end(battle)
	if ended.is_empty(): return false
	var candidate := _new_candidate(book_id, settings, ended.profile)
	return candidate != null and _save(candidate, ended.profile)


func _new_candidate(book_id: StringName, settings: AppSettings, starting_profile: ProfileState) -> RunSession:
	var chosen := BuildSelection.new()
	chosen.book_id = book_id
	chosen.growth_hp = TalentProgress.health_for(starting_profile.manual_characters)
	chosen.base_hp = STARTING_HEALTH[DIFFICULTIES.find(settings.difficulty)]
	var compiled := compiler.compile(chosen)
	if not compiled.success():
		last_error = "\n".join(compiled.diagnostics)
		return null
	var candidate := RunSession.new(repository, profile)
	candidate.selection = chosen
	candidate.combat.hp_q = compiled.build.maximum_hp_q()
	candidate.run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	candidate.phase = "READY_FOR_ROOM"
	candidate.seed_text = settings.run_seed if not settings.run_seed.is_empty() else candidate.run_id
	candidate.options = {"difficulty": settings.difficulty, "progressive": settings.progressive, "minimum_length": settings.min_length, "maximum_length": settings.max_length, "vocabulary_id": settings.vocabulary_id}
	candidate.options["loop_index"] = 0
	candidate.facts.merge({"rerolls": 2, "round_index": 0, "round_start_characters": 0, "offer_serial": 0, "victory_pending": false})
	candidate.facts["content_version"] = SaveRepository.CONTENT_VERSION
	candidate.facts["graph_version"] = SaveRepository.GRAPH_VERSION
	var rng := RandomNumberGenerator.new()
	rng.seed = (candidate.seed_text + ":rewards").hash()
	candidate.reward_rng_state = str(rng.state)
	rng.seed = (candidate.seed_text + ":events").hash()
	candidate.event_rng_state = str(rng.state)
	candidate.rewards.start_chapter(1, itinerary.chapter_experience(1))
	return candidate


func restore() -> bool:
	if profile.run_checkpoint.is_empty():
		return true
	var candidate := from_checkpoint(profile.run_checkpoint)
	if candidate == null:
		last_error = "本局检查点无法读取，原档案已保留。"
		return false
	if candidate.facts.has("god_transfer"):
		last_error = "God档转移尚未完成，请重新激活以完成接管；原远征已锁定保留。"
		return false
	candidate.repository = repository
	candidate.profile = profile
	var incompatible := int(candidate.facts.get("content_version", -1)) != SaveRepository.CONTENT_VERSION or int(candidate.facts.get("graph_version", -1)) != SaveRepository.GRAPH_VERSION
	if incompatible and profile.has_pending_run():
		last_error = "远征规则已变化，旧局已保留；请明确重开。"
		return false
	if candidate.phase in ["BATTLE", "BATTLE_REWARD"]:
		candidate.facts["resume_attempt_id"] = candidate.attempt_id
		candidate.facts["resume_characters"] = int(candidate.facts.get("checkpoint_characters", 0))
		candidate.facts.erase("god_character_offset")
		candidate.facts["resume_reward_facts"] = candidate.rewards.to_dict().facts.keys()
		candidate.room_serial -= 1
		candidate.phase = "REWARD" if candidate.phase == "BATTLE_REWARD" else "READY_FOR_ROOM"
		candidate.facts["route_complete"] = true
		return _save(candidate)
	_adopt(candidate)
	return true


func start_room(entries: Array[VocabularyEntry], prepared: VocabularyIndex) -> BattleStartRequest:
	if phase != "READY_FOR_ROOM" or room_serial >= itinerary.encounters.size():
		last_error = "当前没有可进入的房间。"
		return null
	var candidate := copy()
	candidate.room_serial += 1
	var resuming := candidate.facts.has("resume_attempt_id")
	candidate.attempt_id = str(candidate.facts.resume_attempt_id) if resuming else Crypto.new().generate_random_bytes(12).hex_encode()
	candidate.facts.erase("resume_attempt_id")
	if not resuming:
		candidate.facts["resume_characters"] = 0
		candidate.facts.erase("god_character_offset")
		candidate.facts.erase("resume_reward_facts")
	candidate.phase = "BATTLE"
	candidate.facts["checkpoint_characters"] = int(candidate.facts.get("resume_characters", 0))
	candidate.facts["route_complete"] = false
	var local_chapter := itinerary.chapter_of(candidate.room_serial)
	var chapter := local_chapter + int(candidate.facts.get("round_index", 0)) * itinerary.chapter_of(itinerary.encounters.size())
	candidate.rewards.start_chapter(chapter, itinerary.chapter_experience(local_chapter))
	var compiled := compiler.compile(candidate.selection)
	if not compiled.success():
		last_error = "\n".join(compiled.diagnostics)
		return null
	var request := BattleStartRequest.new()
	request.run_id = candidate.run_id
	request.room_serial = candidate.room_serial + int(candidate.facts.get("round_index", 0)) * itinerary.encounters.size()
	request.attempt_id = candidate.attempt_id
	request.chapter = chapter
	request.loop_index = int(options.get("loop_index", 0))
	request.build = compiled.build
	request.vocabulary = entries
	request.vocabulary_index = prepared
	request.maximum_length = int(options.maximum_length)
	request.encounter = itinerary.encounters[candidate.room_serial - 1]
	request.difficulty = str(options.difficulty)
	request.seed_text = seed_text + ":battle:" + str(candidate.facts.get("round_index", 0)) + ":" + str(candidate.room_serial)
	request.progressive = bool(options.progressive)
	request.minimum_length = int(options.minimum_length)
	var words: Array[String] = []
	for entry in entries:
		words.append(entry.word.replace(" ", ""))
	candidate.facts["vocabulary_letters"] = words
	if not _save(candidate):
		return null
	return request


func install_room_opening(battle: BattleSession) -> void:
	battle.dodge_charges = minf(2.0 + battle.compiled_build.value(&"dodge_capacity"), battle.dodge_charges + pending_dodge)
	pending_dodge = 0
	if battle.statistics != null:
		battle.statistics.correct_streak = int(facts.get("round_stats", {}).get("correct_streak", 0))


func observe_battle(battle: BattleSession) -> bool:
	if profile.run_checkpoint.get("facts", {}).has("god_transfer"):
		last_error = "远征正在转入God档，请先完成接管。"
		return false
	if phase != "BATTLE" or battle.result != 0:
		return true
	var candidate := copy()
	if not _consume_facts(candidate, battle.reward_facts):
		return false
	_merge_facts(candidate, battle)
	if candidate.rewards.available() <= 0:
		rewards = candidate.rewards
		facts = candidate.facts
		return true
	battle.set_physics_process(false)
	candidate.phase = "BATTLE_REWARD"
	candidate.combat = RunStateCodec.decode(RunStateCodec.encode(battle.run_state))
	candidate.combat.hp_q = battle.player_hp_q
	candidate.combat.resonance_q = battle.resonance_q
	candidate.facts["checkpoint_characters"] = _room_characters(battle.manual_characters)
	_make_reward_offer(candidate)
	var receipt := RoomSettlementReceipt.new(run_id, room_serial, attempt_id, &"checkpoint", _room_characters(battle.manual_characters), profile.mode)
	var progress := TalentProgress.prepare_checkpoint(profile, receipt)
	if not progress.diagnostics.is_empty():
		last_error = "\n".join(progress.diagnostics)
		return false
	return _save(candidate, progress.profile)


func suspend_battle(battle: BattleSession) -> bool:
	if phase not in ["BATTLE", "BATTLE_REWARD"]:
		last_error = "当前没有可以保存的战斗。"
		return false
	if battle.result != 0:
		return finish_room(battle)
	var candidate := copy()
	if not _consume_facts(candidate, battle.reward_facts): return false
	_merge_facts(candidate, battle)
	candidate.combat = RunStateCodec.decode(RunStateCodec.encode(battle.run_state))
	candidate.combat.hp_q = battle.player_hp_q
	candidate.combat.resonance_q = battle.resonance_q
	candidate.facts["checkpoint_characters"] = _room_characters(battle.manual_characters)
	if phase == "BATTLE" and candidate.rewards.available() > 0:
		candidate.phase = "BATTLE_REWARD"
		_make_reward_offer(candidate)
	var receipt := RoomSettlementReceipt.new(run_id, room_serial, attempt_id, &"checkpoint", int(candidate.facts.checkpoint_characters), profile.mode)
	var progress := TalentProgress.prepare_checkpoint(profile, receipt)
	if not progress.diagnostics.is_empty():
		last_error = "\n".join(progress.diagnostics)
		return false
	return _save(candidate, progress.profile)


func finish_room(battle: BattleSession) -> bool:
	if _pending_boundary != null:
		return _save_boundary()
	if phase not in ["BATTLE", "BATTLE_REWARD"]:
		return phase in ["REWARD", "ROUTE", "READY_FOR_ROOM", "RESULT"]
	var result := battle.finish_room(&"victory" if battle.result > 0 else &"abandon" if battle.abandoned_run else &"defeat")
	var candidate := copy()
	candidate.combat = RunStateCodec.decode(RunStateCodec.encode(battle.run_state))
	if not _consume_facts(candidate, result.reward_facts):
		return false
	for key in result.facts:
		candidate.facts[key] = bool(candidate.facts.get(key, false)) or bool(result.facts[key])
	_merge_statistics(candidate, result.statistics)
	candidate.facts["checkpoint_characters"] = _room_characters(result.manual_characters)
	candidate.facts["result_reason"] = str(result.reason)
	candidate.facts["last_receipt"] = {"characters": result.manual_characters, "words": result.manual_words, "reason": str(result.reason)}
	candidate.offer.clear()
	var victory := result.reason == &"victory"
	if not _expire(candidate, victory):
		return false
	if not victory or room_serial == itinerary.encounters.size():
		candidate.phase = "RESULT"
		candidate.facts["victory_pending"] = victory
		if victory:
			candidate.facts["result_build"] = candidate.selection.to_dict()
		else:
			_close_run(candidate)
	else:
		candidate.phase = "REWARD" if candidate.rewards.available() > 0 else "ROUTE"
		if candidate.phase == "REWARD":
			_make_reward_offer(candidate)
	_pending_boundary = candidate
	return _save_boundary()


func _close_run(candidate: RunSession) -> void:
	candidate.facts["victory_pending"] = false
	candidate.facts["result_build"] = candidate.selection.to_dict()
	for contract in candidate.contracts:
		if contract.has("trial") and not bool(contract.get("trial_complete", false)):
			contract["trial_result"] = candidate.facts.result_reason
		contract["closed_reason"] = "run_end"
	var archived: Array = candidate.facts.get("archived_contracts", []).duplicate(true)
	archived.append_array(candidate.contracts.duplicate(true))
	candidate.facts["closed_contracts"] = archived
	candidate.offer.clear()
	candidate.contracts.clear()
	candidate.pledged.clear()
	candidate.selection.instances.clear()
	candidate.selection.assets.clear()
	candidate.selection.asset_instances.clear()
	candidate.selection.temporary_rules.clear()
	candidate.selection.overrides.clear()
	candidate.pending_opening.clear()
	candidate.pending_dodge = 0
	candidate.combat.reserve.clear()


func _save_boundary() -> bool:
	var receipt := RoomSettlementReceipt.new(run_id, room_serial, attempt_id, StringName(_pending_boundary.facts.result_reason), int(_pending_boundary.facts.checkpoint_characters), profile.mode)
	var progress := TalentProgress.prepare(profile, receipt)
	if not progress.diagnostics.is_empty():
		last_error = "\n".join(progress.diagnostics)
		return false
	if _pending_boundary.phase == "RESULT":
		_append_record(_pending_boundary, progress.profile)
	var candidate := _pending_boundary
	if not _save(candidate, progress.profile):
		return false
	_pending_boundary = null
	return true


func _record(candidate: RunSession, settled_profile: ProfileState) -> Dictionary:
	var record := {"run_id": candidate.run_id, "reason": candidate.facts.result_reason, "rooms": candidate.room_serial, "round": int(candidate.facts.get("round_index", 0)), "difficulty": candidate.options.get("difficulty", "normal"), "loop": candidate.options.get("loop_index", 0), "book": str(candidate.selection.book_id), "characters": int(settled_profile.settlements.runs.get(candidate.run_id, {}).get("manual_characters", 0)) - int(candidate.facts.get("round_start_characters", 0)), "routes": candidate.facts.get("routes", []).duplicate(true), "events": candidate.facts.get("event_history", []).duplicate(true), "contracts": candidate.facts.get("closed_contracts", []).duplicate(true), "build": candidate.facts.result_build.duplicate(true), "rewards": candidate.rewards.to_dict()}
	if candidate.facts.has("result_stats"):
		record["stats"] = candidate.facts.result_stats.duplicate(true)
	return record


func next_challenge_label() -> String:
	var rank := DIFFICULTIES.find(str(options.get("difficulty", "normal")))
	return DIFFICULTY_NAMES[rank + 1] if rank < DIFFICULTIES.size() - 1 else "灭世 · 第 %d 周目" % (int(options.get("loop_index", 0)) + 2)


func continue_challenge() -> bool:
	if phase != "RESULT" or not bool(facts.get("victory_pending", false)):
		last_error = "只有通关的远征可以继续挑战。"
		return false
	var candidate := copy()
	var rank := DIFFICULTIES.find(str(options.difficulty))
	if rank < DIFFICULTIES.size() - 1:
		candidate.options.difficulty = DIFFICULTIES[rank + 1]
	else:
		candidate.options["loop_index"] = int(options.get("loop_index", 0)) + 1
	candidate.selection.base_hp = STARTING_HEALTH[DIFFICULTIES.find(str(candidate.options.difficulty))]
	candidate.facts["victory_pending"] = false
	candidate.facts["round_index"] = int(facts.get("round_index", 0)) + 1
	candidate.facts["round_start_characters"] = int(profile.settlements.runs.get(run_id, {}).get("manual_characters", 0))
	candidate.facts["rerolls"] = mini(4, int(facts.get("rerolls", 0)) + 1)
	candidate.facts["routes"] = []
	for key in ["statistics_segments", "result_stats", "round_stats"]: candidate.facts.erase(key)
	candidate.room_serial = 0
	candidate.combat.hp_q = mini(compiler.compile(candidate.selection).build.maximum_hp_q(), combat.hp_q + 30 * Q)
	candidate.rewards.spent = candidate.rewards.earned
	candidate.offer.clear()
	candidate.phase = "READY_FOR_ROOM"
	return _save(candidate)


func end_challenge() -> bool:
	if phase != "RESULT":
		last_error = "请先完成当前挑战。"
		return false
	return end_run()


func end_run(battle: BattleSession = null) -> bool:
	if not has_pending_run(): return true
	var ended := _prepare_end(battle)
	return not ended.is_empty() and _save(ended.run, ended.profile)


func _prepare_end(battle: BattleSession) -> Dictionary:
	var candidate := from_checkpoint(profile.run_checkpoint) if has_pending_run() else copy()
	if candidate == null:
		last_error = "原远征无法读取，原档案已保留。"
		return {}
	var updated := profile.copy()
	if has_pending_run() and not (candidate.phase == "RESULT" and bool(candidate.facts.get("victory_pending", false))):
		if candidate.phase in ["BATTLE", "BATTLE_REWARD"] or candidate.facts.has("resume_attempt_id"):
			var characters := int(candidate.facts.get("checkpoint_characters", 0))
			if battle != null:
				characters = int(candidate.facts.get("resume_characters", 0)) + maxi(0, battle.manual_characters - int(candidate.facts.get("god_character_offset", 0)))
				candidate.combat = RunStateCodec.decode(RunStateCodec.encode(battle.run_state))
				candidate.combat.hp_q = battle.player_hp_q
				if battle.statistics != null: _merge_statistics(candidate, battle.statistics.snapshot())
			var receipt_room := candidate.room_serial + 1 if candidate.facts.has("resume_attempt_id") else candidate.room_serial
			var receipt_attempt := str(candidate.facts.resume_attempt_id) if candidate.facts.has("resume_attempt_id") else candidate.attempt_id
			var receipt := RoomSettlementReceipt.new(candidate.run_id, receipt_room, receipt_attempt, &"abandon", characters, profile.mode)
			var progress := TalentProgress.prepare(updated, receipt)
			if not progress.diagnostics.is_empty():
				last_error = "\n".join(progress.diagnostics)
				return {}
			updated = progress.profile
		candidate.facts["result_reason"] = "abandon"
		candidate.phase = "RESULT"
		_close_run(candidate)
		_append_record(candidate, updated)
	else:
		candidate.phase = "RESULT"
		_close_run(candidate)
	return {"run": candidate, "profile": updated}


func _append_record(candidate: RunSession, updated: ProfileState) -> void:
	for record in updated.records:
		if record.get("run_id") == candidate.run_id and int(record.get("round", 0)) == int(candidate.facts.get("round_index", 0)): return
	updated.records.append(_record(candidate, updated))


func _room_characters(current: int) -> int:
	return int(facts.get("resume_characters", 0)) + maxi(0, current - int(facts.get("god_character_offset", 0)))


func isolate_to_god(god_repository: SaveRepository, battle: BattleSession = null) -> bool:
	if repository.mode == &"god": return true
	if god_repository == null or god_repository.mode != &"god":
		last_error = "接管仓库必须为God档。"
		return false
	var target := god_repository.load_profile()
	if target == null:
		last_error = god_repository.last_error
		return false
	var source_facts: Variant = profile.run_checkpoint.get("facts", {})
	if not source_facts is Dictionary or not source_facts.get("god_transfer", {}) is Dictionary:
		last_error = "原远征接管字段无法读取，原档案已保留。"
		return false
	var marker: Dictionary = source_facts.get("god_transfer", {})
	if marker.is_empty():
		if not has_pending_run():
			last_error = "当前没有需要转移的远征。"
			return false
		if target.has_pending_run():
			last_error = "God档已有未完成远征，请先处理该远征。"
			return false
		var candidate := copy() if not run_id.is_empty() else from_checkpoint(profile.run_checkpoint)
		if candidate == null:
			last_error = "原远征无法读取，原档案已保留。"
			return false
		var source := profile.copy()
		if candidate.phase in ["BATTLE", "BATTLE_REWARD"] or candidate.facts.has("resume_attempt_id"):
			var characters := int(candidate.facts.get("checkpoint_characters", 0))
			if battle != null:
				characters = _room_characters(battle.manual_characters)
				candidate.combat = RunStateCodec.decode(RunStateCodec.encode(battle.run_state))
				candidate.combat.hp_q = battle.player_hp_q
				if battle.statistics != null: _merge_statistics(candidate, battle.statistics.snapshot())
			var serial := candidate.room_serial + 1 if candidate.facts.has("resume_attempt_id") else candidate.room_serial
			var attempt := str(candidate.facts.resume_attempt_id) if candidate.facts.has("resume_attempt_id") else candidate.attempt_id
			var progress := TalentProgress.prepare(source, RoomSettlementReceipt.new(candidate.run_id, serial, attempt, &"interrupted", characters, &"normal"))
			if not progress.diagnostics.is_empty():
				last_error = "\n".join(progress.diagnostics)
				return false
			source = progress.profile
		candidate.facts["checkpoint_characters"] = 0
		candidate.facts["resume_characters"] = 0
		candidate.facts["god_character_offset"] = battle.manual_characters if battle != null else 0
		candidate.facts["round_start_characters"] = 0
		candidate.facts["resume_reward_facts"] = candidate.rewards.to_dict().facts.keys()
		var token := Crypto.new().generate_random_bytes(16).hex_encode()
		candidate.facts["god_transfer_token"] = token
		marker = {"target_path": god_repository.path, "token": token, "checkpoint": candidate.to_checkpoint()}
		source.run_checkpoint = candidate.to_checkpoint()
		source.run_checkpoint.facts["god_transfer"] = marker
		source.revision = profile.revision + 1
		if not repository.save_profile(source, profile.revision):
			last_error = repository.last_error
			return false
		profile = source
	if not marker.has_all(["target_path", "token", "checkpoint"]) or not marker.checkpoint is Dictionary or not marker.token is String or str(marker.token).is_empty() or from_checkpoint(marker.checkpoint) == null:
		last_error = "接管标记无法读取，原档案已保留。"
		return false
	if marker.get("target_path") != god_repository.path:
		last_error = "转移目标与原接管标记不一致，原档案已保留。"
		return false
	var received: bool = target.run_checkpoint.get("facts", {}).get("god_transfer_token", "") == marker.token
	if target.has_pending_run() and not received:
		last_error = "God档已有未完成远征，原转移保持锁定。"
		return false
	if not received:
		# Ensure fallback also contains the lock before publishing the second profile.
		if not repository.protect_transfer_backup(profile.revision):
			last_error = repository.last_error
			return false
		var proposed := target.copy()
		proposed.run_checkpoint = marker.checkpoint.duplicate(true)
		proposed.revision += 1
		if not god_repository.save_profile(proposed, target.revision):
			last_error = god_repository.last_error
			return false
		target = proposed
	var adopted := from_checkpoint(target.run_checkpoint)
	if adopted == null:
		last_error = "God接管检查点无法读取，普通档保持锁定。"
		return false
	var cleared := profile.copy()
	cleared.run_checkpoint.clear()
	cleared.revision += 1
	if not repository.save_profile(cleared, profile.revision):
		last_error = repository.last_error
		return false
	adopted.profile = target
	repository = god_repository
	_adopt(adopted)
	last_error = ""
	return true


func take_reward(content_id: StringName, offer_id: String, parent_id: String = "", battle: BattleSession = null) -> bool:
	if transactions.has(offer_id):
		return transactions[offer_id] == str(content_id)
	if phase not in ["BATTLE_REWARD", "REWARD"] or offer.get("id", "") != offer_id or str(content_id) not in offer.get("candidates", []):
		last_error = "奖励报价已变化，请重新查看。"
		return false
	var candidate := copy()
	var prepared := RunTransactionService.new(compiler).prepare_acquisition(candidate.selection, candidate.combat, content_id, offer_id + ":asset" if parent_id.is_empty() else parent_id, parent_id, acquisition_context())
	if not prepared.diagnostics.is_empty():
		last_error = "\n".join(prepared.diagnostics)
		return false
	if not candidate.rewards.spend(1):
		last_error = "没有可用奖励机会。"
		return false
	candidate.selection = prepared.selection
	candidate.combat = prepared.state
	candidate.transactions[offer_id] = str(content_id)
	candidate.offer.clear()
	if battle == null:
		candidate.pending_dodge += prepared.dodge_delta
	if candidate.rewards.available() > 0:
		_make_reward_offer(candidate)
	else:
		candidate.phase = "BATTLE" if phase == "BATTLE_REWARD" else "READY_FOR_ROOM" if bool(candidate.facts.get("route_complete", false)) else "ROUTE"
	if not _save(candidate):
		return false
	if battle != null:
		battle.run_state = combat
		battle.runtime.run = combat
		battle.player_hp_q = combat.hp_q
		battle.install_prepared_build(prepared.build)
		battle.dodge_charges = minf(2.0 + prepared.build.value(&"dodge_capacity"), battle.dodge_charges + prepared.dodge_delta)
	return true


func skip_reward(offer_id: String) -> bool:
	if transactions.has(offer_id):
		return transactions[offer_id] == "skip"
	if phase not in ["BATTLE_REWARD", "REWARD"] or offer.get("id", "") != offer_id:
		last_error = "奖励报价已变化。"
		return false
	var candidate := copy()
	if not candidate.rewards.spend(1):
		return false
	candidate.transactions[offer_id] = "skip"
	candidate.offer.clear()
	if candidate.rewards.available() > 0:
		_make_reward_offer(candidate)
	else:
		candidate.phase = "BATTLE" if phase == "BATTLE_REWARD" else "READY_FOR_ROOM" if bool(candidate.facts.get("route_complete", false)) else "ROUTE"
	return _save(candidate)


func reroll_reward(offer_id: String) -> bool:
	if phase not in ["BATTLE_REWARD", "REWARD"] or offer.get("id", "") != offer_id or int(facts.get("rerolls", 0)) <= 0:
		last_error = "当前不能重抽。"
		return false
	var candidate := copy()
	candidate.facts["rerolls"] = int(facts.rerolls) - 1
	_make_reward_offer(candidate)
	return _save(candidate)


func supply_reward(offer_id: String, battle: BattleSession = null) -> bool:
	if transactions.has(offer_id): return transactions[offer_id] == "supply"
	if phase not in ["BATTLE_REWARD", "REWARD"] or offer.get("id", "") != offer_id or not offer.get("candidates", []).is_empty():
		last_error = "当前奖励不是补给。"
		return false
	var candidate := copy()
	if not candidate.rewards.spend(1): return false
	var build := compiler.compile(selection).build
	candidate.combat.hp_q = mini(build.maximum_hp_q(), combat.hp_q + 25 * Q)
	candidate.transactions[offer_id] = "supply"
	if battle == null: candidate.pending_dodge += 1
	candidate.offer.clear()
	if candidate.rewards.available() > 0:
		_make_reward_offer(candidate)
	else:
		candidate.phase = "BATTLE" if phase == "BATTLE_REWARD" else "READY_FOR_ROOM" if bool(candidate.facts.get("route_complete", false)) else "ROUTE"
	if not _save(candidate): return false
	if battle != null:
		battle.player_hp_q = combat.hp_q
		battle.run_state = combat
		battle.runtime.run = combat
		battle.dodge_charges = minf(2.0 + build.value(&"dodge_capacity"), battle.dodge_charges + 1)
	return true


func leave_route() -> bool:
	return take_route("continue")


func take_route(choice: String) -> bool:
	var identity := "%s:route:%d:%d" % [run_id, int(facts.get("round_index", 0)), room_serial]
	if transactions.has(identity):
		return transactions[identity] == choice
	if phase != "ROUTE" or choice not in ["continue", "rest", "offering"]:
		last_error = "当前不能进入下一房。"
		return false
	var candidate := copy()
	var maximum := compiler.compile(selection).build.maximum_hp_q()
	if choice == "rest":
		candidate.combat.hp_q = mini(maximum, candidate.combat.hp_q + 20 * Q)
	elif choice == "offering":
		if combat.hp_q <= 15 * Q:
			last_error = "需要保留至少 1 点生命，才能付出 15 点生命。"
			return false
		candidate.combat.hp_q -= 15 * Q
		candidate.rewards.earned += 1
	candidate.transactions[identity] = choice
	var history: Array = candidate.facts.get("routes", [])
	history.append({"room": room_serial, "choice": choice})
	candidate.facts["routes"] = history
	candidate.offer.clear()
	candidate.facts["route_complete"] = true
	candidate.phase = "REWARD" if candidate.rewards.available() > 0 else "READY_FOR_ROOM"
	if candidate.phase == "REWARD":
		_make_reward_offer(candidate)
	return _save(candidate)


func acquisition_context() -> Dictionary:
	var shortest := 999
	var longest := 0
	for word: String in facts.get("vocabulary_letters", []):
		shortest = mini(shortest, word.length())
		longest = maxi(longest, word.length())
	return {"pledged": pledged, "shortest": shortest if longest > 0 else int(options.get("minimum_length", 1)), "longest": longest if longest > 0 else int(options.get("maximum_length", 12))}




func copy() -> RunSession:
	var result := from_checkpoint(to_checkpoint())
	result.repository = repository
	result.profile = profile
	return result


func to_checkpoint() -> Dictionary:
	var data: Dictionary = {}
	for property in SERIALIZED:
		var value: Variant = get(property)
		data[property] = Array(value) if value is PackedStringArray else value.duplicate(true) if value is Dictionary or value is Array else value
	data["selection"] = selection.to_dict()
	data["combat"] = RunStateCodec.encode(combat)
	data["rewards"] = rewards.to_dict()
	data["pledged"] = []
	for instance in pledged:
		data.pledged.append(instance.to_dict())
	return data


static func from_checkpoint(data: Dictionary) -> RunSession:
	if not data.has_all(SERIALIZED + ["selection", "combat", "rewards", "pledged"]):
		return null
	for field in ["selection", "combat", "rewards", "options", "facts", "offer", "transactions"]:
		if not data[field] is Dictionary:
			return null
	for field in ["contracts", "pending_opening", "pledged"]:
		if not data[field] is Array:
			return null
		for item in data[field]:
			if not item is Dictionary:
				return null
	for field in ["run_id", "phase", "attempt_id", "seed_text", "reward_rng_state", "event_rng_state"]:
		if not data[field] is String:
			return null
	if data.phase not in ["RESULT", "READY_FOR_ROOM", "BATTLE", "BATTLE_REWARD", "REWARD", "ROUTE", "EVENT"]:
		return null
	if not ProfileState.is_count(data.room_serial) or int(data.room_serial) > 9 or not ProfileState.is_count(data.pending_dodge):
		return null
	if data.phase in ["BATTLE", "BATTLE_REWARD"] and int(data.room_serial) < 1:
		return null
	if not data.used_events is Array:
		return null
	for id in data.used_events:
		if not id is String:
			return null
	if data.phase in ["BATTLE_REWARD", "REWARD"] and (not data.offer.get("id") is String or not data.offer.get("candidates") is Array):
		return null
	if data.phase == "EVENT" and (not data.offer.get("id") is String or not data.offer.get("event") is String or not data.offer.get("bindings") is Dictionary):
		return null
	var result := RunSession.new()
	for property in SERIALIZED:
		if not data.has(property):
			return null
		if property in ["room_serial", "pending_dodge"]:
			result.set(property, int(data[property]))
		elif property == "used_events":
			result.used_events = PackedStringArray(data[property])
		elif property in ["contracts", "pending_opening"]:
			result.get(property).assign(data[property].duplicate(true))
		else:
			result.set(property, data[property].duplicate(true) if data[property] is Array or data[property] is Dictionary else data[property])
	result.selection = BuildSelection.from_dict(data.selection)
	result.combat = RunStateCodec.decode(data.combat)
	result.rewards = RewardLedger.from_dict(data.rewards)
	if result.selection == null or result.combat == null or result.rewards == null:
		return null
	if not result.pending_opening.is_empty():
		var opening_data := RunStateCodec.encode(RunCombatState.new())
		opening_data.reserve = result.pending_opening
		if RunStateCodec.decode(opening_data) == null:
			return null
	for item in data.get("pledged", []):
		var instance := CombatAssetInstance.from_dict(item)
		if instance == null:
			return null
		result.pledged.append(instance)
	return result


func _save(candidate: RunSession, updated_profile: ProfileState = null) -> bool:
	if profile.run_checkpoint.get("facts", {}).has("god_transfer"):
		last_error = "远征正在转入God档，请先完成接管。"
		return false
	var proposed := profile.copy() if updated_profile == null else updated_profile
	proposed.content_version = SaveRepository.CONTENT_VERSION
	proposed.graph_version = SaveRepository.GRAPH_VERSION
	proposed.layout_version = SaveRepository.LAYOUT_VERSION
	proposed.run_checkpoint = candidate.to_checkpoint() if candidate.phase != "RESULT" or bool(candidate.facts.get("victory_pending", false)) else {}
	proposed.revision = profile.revision + 1
	if not repository.save_profile(proposed, profile.revision):
		last_error = repository.last_error
		return false
	candidate.profile = proposed
	_adopt(candidate)
	last_error = ""
	return true


func _adopt(candidate: RunSession) -> void:
	for property in SERIALIZED:
		set(property, candidate.get(property))
	selection = candidate.selection
	combat = candidate.combat
	rewards = candidate.rewards
	pledged = candidate.pledged
	profile = candidate.profile


func _consume_facts(candidate: RunSession, items: Array[RewardFact]) -> bool:
	for item in items:
		if item.fact_id in candidate.facts.get("resume_reward_facts", []): continue
		var result := candidate.rewards.consume(item)
		if not result.diagnostics.is_empty():
			last_error = "\n".join(result.diagnostics)
			return false
	return true


func _merge_facts(candidate: RunSession, battle: BattleSession) -> void:
	for key in ["has_created_redeemable_mark", "has_input_interruption", "has_same_root_lots"]:
		candidate.facts[key] = bool(candidate.facts.get(key, false)) or bool(battle.get(key))
	if battle.statistics != null: _merge_statistics(candidate, battle.statistics.snapshot())


func _merge_statistics(candidate: RunSession, snapshot: Dictionary) -> void:
	if snapshot.is_empty(): return
	var segments: Dictionary = candidate.facts.get("statistics_segments", {})
	segments[snapshot.segment_id] = snapshot.duplicate(true)
	candidate.facts["statistics_segments"] = segments
	var totals := {"version": 1, "best_correct_streak": 0, "correct_streak": snapshot.correct_streak, "wrong_word_counts": {}}
	for key in BattleStatistics.SUM_FIELDS: totals[key] = 0
	totals.elapsed = 0.0
	for segment: Dictionary in segments.values():
		for key in BattleStatistics.SUM_FIELDS: totals[key] += segment[key]
		totals.best_correct_streak = maxi(totals.best_correct_streak, int(segment.best_correct_streak))
		if segment.has("max_combo"): totals["max_combo"] = maxi(int(totals.get("max_combo", 0)), int(segment.max_combo))
		for word: String in segment.wrong_word_counts:
			totals.wrong_word_counts[word] = int(totals.wrong_word_counts.get(word, 0)) + int(segment.wrong_word_counts[word])
	candidate.facts["round_stats"] = totals
	candidate.facts["result_stats"] = totals.duplicate(true)


func _make_reward_offer(candidate: RunSession) -> void:
	var eligible := AcquisitionService.new(compiler).candidates(candidate.selection, candidate.acquisition_context())
	var rng := RandomNumberGenerator.new()
	rng.state = int(candidate.reward_rng_state)
	var candidates: Array[String] = []
	while not eligible.is_empty() and candidates.size() < 3:
		var index := rng.randi_range(0, eligible.size() - 1)
		candidates.append(eligible[index])
		eligible.remove_at(index)
	candidate.reward_rng_state = str(rng.state)
	candidate.facts["offer_serial"] = int(candidate.facts.get("offer_serial", 0)) + 1
	candidate.offer = {"id": "%s:reward:%d" % [run_id, int(candidate.facts.offer_serial)], "kind": "reward", "candidates": candidates}


func _expire(candidate: RunSession, _victory: bool) -> bool:
	var compiled := compiler.compile(candidate.selection)
	if not compiled.success():
		last_error = "\n".join(compiled.diagnostics)
		return false
	candidate.combat.hp_q = mini(candidate.combat.hp_q, compiled.build.maximum_hp_q())
	return true
