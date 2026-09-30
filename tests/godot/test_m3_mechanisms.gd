extends SceneTree

const Q := 1024
const WORD := "abcdefghijkl"
var checks := 0
var failures := 0
var sessions: Array[BattleSession] = []
var compiler := BuildCompiler.new()


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func selection(book: StringName, talents: PackedStringArray = [], assets: Dictionary[StringName, int] = {}) -> BuildSelection:
	var value := BuildSelection.new()
	value.book_id = book
	value.talents = talents
	value.assets = assets
	return value


func room(value: BuildSelection) -> BattleSession:
	var result := compiler.compile(value)
	check(result.success(), "Combination compiles: %s %s %s" % [value.book_id, value.talents, result.diagnostics])
	if not result.success(): return null
	var request := BattleStartRequest.new()
	request.build = result.build
	request.vocabulary = [VocabularyEntry.new(WORD, "测试")]
	request.encounter = BattleEncounter.new()
	request.encounter.wave_count = 1
	var session := BattleSession.new()
	sessions.append(session)
	root.add_child(session)
	session.set_physics_process(false)
	session.start(request)
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.combat_locked = true
		enemy.position = Vector2(0.68 + index * 0.07, 0.43 + index * 0.06)
		enemy.previous_position = enemy.position
		enemy.hp_q = 5000 * Q
		enemy.max_hp_q = enemy.hp_q
		enemy.frozen_time = 100.0
		enemy.attack_clock = 100.0
		session.typing.upsert_target(enemy.id, WORD)
	return session


func cast(session: BattleSession, target: int = 0, manual: String = WORD) -> void:
	session.typing.upsert_target(session.enemies[target].id, manual)
	session.typing.select_target(session.enemies[target].id)
	for character in manual: session.typing.feed(character)
	session.step(1.0 / 60)


func advance(session: BattleSession, seconds: float) -> void:
	for tick in roundi(seconds * 60): session.step(1.0 / 60)


func _run() -> void:
	_review_rule_gaps()
	var storage := room(selection(&"frost", ["T01", "T21", "T22", "T12"]))
	cast(storage)
	check(storage.runtime.stored.size() == 1, "Manual storage has a real paid entry")
	var shell := storage.runtime.stored[0]
	var budget := shell.effect.lot.amount_q
	var remaining := storage.runtime.guard("real-attack", budget / 2, shell.position)
	check(remaining == 0 and shell.closed, "Guard closes the paid shell after partial consumption")
	var returned := storage.effects.filter(func(effect: BattleEffect) -> bool: return effect.lot.root_id == shell.effect.lot.root_id)
	check(shell.effect.lot.amount_q == 0 and not returned.is_empty(), "Echo holds the closing remainder, never the old shell balance")
	var spent := storage.ledger.raw_spent_q
	storage.runtime.guard("real-attack", budget / 2, shell.position)
	check(storage.ledger.raw_spent_q == spent, "Attack replay cannot consume another shell")
	var copy := room(selection(&"frost", ["T19", "T03"], {&"R172": 1}))
	copy.enemies[0].resistances = [0, 256, -256, 0, 0]
	cast(copy)
	check(copy.runtime.stored.size() == 1, "One shared twelve-character manufacturing payment creates one copy")
	var copied := copy.runtime.stored[0].effect
	var frozen := copied.lot.packet.components()
	copy.enemies[1].resistances = [0, -256, 256, 0, 0]
	copy.runtime.dispatch(copied, copy.enemies[1])
	check(copied.lot.packet.components() == frozen and copied.lot.claims.has(&"refracted"), "Copies inherit frozen R172 composition when retargeted")
	var status := room(selection(&"flame", ["T49"], {&"R165": 1}))
	status.enemies[1].position = Vector2(0.25, 0.8)
	status.enemies[2].position = Vector2(0.5, 0.8)
	cast(status)
	advance(status, 0.4)
	check(not status.runtime.ongoing.is_empty(), "Native contact creates independent future portions")
	var ongoing := status.runtime.ongoing[0]
	var pulse_count := ongoing.remaining_pulses
	var old_remaining := ongoing.effect.lot.amount_q
	cast(status)
	advance(status, 1.0)
	check(ongoing.advanced and ongoing.remaining_pulses <= pulse_count - 2 and ongoing.effect.lot.amount_q < old_remaining, "Advance consumes the old scheduled pulses: advanced=%s pulses=%s" % [ongoing.advanced, ongoing.remaining_pulses])
	var original_build := status.compiled_build
	var changed := compiler.compile(selection(&"flame", ["T49", "N01-01"]))
	var command := BattleCommand.new()
	command.build = changed.build
	status.queue_command(command)
	status.step(1.0 / 60)
	check(status.compiled_build == changed.build and ongoing.effect.build == original_build, "Installed build changes leave old schedules frozen")
	var transport := room(selection(&"spirit", ["T01", "T25", "T26"]))
	cast(transport)
	check(not transport.runtime.stored.is_empty() and not transport.runtime.spirit_attacks.is_empty(), "Transport has separately funded cargo and attacks")
	var carrier := transport.spirits[0]
	carrier.target_id = transport.enemies[0].id
	carrier.effect = transport.runtime.take_spirit_attack(transport.enemies[0], carrier.position)
	var attack_amount := carrier.effect.lot.amount_q
	carrier.cargo = transport.runtime.pickup(carrier)
	check(carrier.cargo != null and carrier.effect.lot.amount_q == 0 and attack_amount > 0, "Picking up cargo spends exactly one real attack opportunity")
	var deadline := carrier.cargo.expires_at
	transport.runtime.return_cargo(carrier.cargo, transport.player_position)
	check(carrier.cargo.returned and carrier.cargo.expires_at == deadline, "Return neither renews cargo nor generates an echo")
	var assist := room(selection(&"frost", [], {&"R017":1}))
	cast(assist)
	advance(assist, 0.5)
	assist.typing.select_target(assist.enemies[0].id)
	assist.typing.feed("a")
	assist.typing.feed("b")
	var words_before := assist.completed_words
	assist.typing.complete_assisted()
	assist.step(1.0 / 60)
	check(assist.manual_characters == 14 and assist.completed_words == words_before, "Assisted suffix casts only manual income and skips full-manual counters")
	check(assist.runtime.work_bank[0].amount_q == 0, "Assistance consumes its earned opportunity")
	var assets := room(selection(&"frost", [], {&"R012":1, &"R024":1}))
	assets.player_hp_q = 0
	assets.step(1.0 / 60)
	check(assets.player_hp_q > 0 and assets.run_state.asset_claims.has("lab:R024:layer:0:revive"), "Revive records the stable instance once")
	var service := CombatAssetService.new(compiler)
	var configuration := selection(&"frost", ["T03"])
	var override := CombatAssetRequest.new()
	override.action = CombatAssetRequest.Action.OVERRIDE
	override.content_id = &"T22"
	var proposed := service.prepare(configuration, override)
	check(proposed.has("command") and "permit:talent:T22" not in proposed.command.build.permits(), "Temporary capability cannot forge a departure talent permit")
	var illegal := selection(&"frost", ["T03"], {&"R140":1})
	illegal.temporary_rules = ["T22"]
	check(not compiler.compile(illegal).success(), "Permanent asset permission cannot be supplied by the override")
	var reserve := room(selection(&"frost", ["T09", "T11", "T12"]))
	var remaining_lot := reserve.ledger.earn("leftover", &"fixture", reserve.compiled_build.identity(), SpellLot.Kind.POWER, 20 * Q, &"leftover")
	reserve.runtime._recover(remaining_lot, true)
	reserve.run_state.reserve_cooldown_words = 2
	var finish := reserve.finish_room(&"victory")
	check(not finish.reserve.is_empty() and finish.reserve[0].lineage[0].root == "leftover", "Handoff retains actual provenance and recovery loss")
	check(reserve.run_state.reserve_cooldown_words == 2, "Empty / full handoffs never reset reserve cooldown")
	var carried_amount := finish.reserve[0].amount_q
	var next_request := BattleStartRequest.new()
	next_request.build = reserve.compiled_build
	next_request.vocabulary = [VocabularyEntry.new(WORD, "交接")]
	next_request.encounter = BattleEncounter.new()
	var next_room := BattleSession.new()
	sessions.append(next_room)
	root.add_child(next_room)
	next_room.set_physics_process(false)
	next_room.start(next_request, reserve.run_state)
	check(next_room.ledger.room_id == 2 and next_room.runtime.reserve[0].amount_q == carried_amount and finish.reserve[0].amount_q == 0, "Consecutive rooms transfer the actual handoff once into a new ledger")
	check(next_room.run_state.reserve_cooldown_words == 2 and next_room.runtime.reserve[0].lineage[0].root == "leftover", "Consecutive rooms retain provenance and unpaid manual-word cooldown")
	var unpartitioned := room(selection(&"frost", ["T48"]))
	var unpartitioned_cold := unpartitioned.ledger.earn("cold-field-leftover", &"fixture", unpartitioned.compiled_build.identity(), SpellLot.Kind.COLD, 20 * Q, &"field")
	unpartitioned.runtime._recover(unpartitioned_cold, true)
	check(unpartitioned.runtime.reserve.is_empty() and unpartitioned_cold.amount_q == 0, "Cold / heat recovery requires a real partitioned material reserve, not just a generic field recovery flag")
	var annotation := room(selection(&"frost", ["T42"]))
	annotation.typing.select_target(annotation.enemies[0].id)
	annotation.typing.feed("a")
	annotation.step(1.0 / 60)
	check(annotation.enemies[0].local_slow_time > 0.0 and annotation.ledger._transactions.keys().any(func(key: String) -> bool: return key.contains("input-slow-cold")), "T42 spends a real conversion to cold instead of treating ice damage as free material")
	var continuation := room(selection(&"frost", ["T38"]))
	continuation.typing.select_target(continuation.enemies[0].id)
	for character in "ab": continuation.typing.feed(character)
	continuation.step(1.0 / 60)
	continuation.enemies[0].hp_q = Q
	preload("res://tests/godot/combat_fixture.gd").hit(continuation, continuation.enemies[0], 2 * Q, &"counter", continuation.player_position)
	check(continuation.run_state.shield_q > 0 and continuation.runtime.letter_marks.is_empty(), "Continuation spends real interrupted input without requiring scatter letters")
	var short_reserve := room(selection(&"frost", ["T09", "T35"]))
	for index in 2:
		short_reserve.runtime.reserve.append(short_reserve.ledger.earn("cold-reserve-%d" % index, &"fixture", short_reserve.compiled_build.identity(), SpellLot.Kind.COLD, 10 * Q, &"reserve"))
	var long_effect := preload("res://tests/godot/combat_fixture.gd").effect(short_reserve, &"counter", short_reserve.enemies[0].id, 100 * Q, 0.0, short_reserve.player_position)
	short_reserve.runtime._apply_reserve(long_effect, short_reserve.enemies[0], true, 12)
	check(long_effect.cold.amount_q == 5 * Q and long_effect.cold.lineage.size() == 2, "Long words do not claim short-word quota; same-material reserves aggregate every source")
	var spirit_guard := room(selection(&"spirit", ["T21"], {&"R049":1}))
	cast(spirit_guard)
	var guarded := spirit_guard.runtime.guard("single-spirit-attack", Q, spirit_guard.player_position)
	var spirit_remaining := spirit_guard.spirit_work_q
	spirit_guard.runtime.guard("single-spirit-attack", Q, spirit_guard.player_position)
	check(guarded == 0 and spirit_guard.spirit_work_q == spirit_remaining, "Spirit defense records attack identity even without stored shells")
	var dash_asset := room(selection(&"frost", [], {&"R009":1}))
	check(dash_asset.dodge_charges == 3.0, "New asset layer grants exactly its declared initial charge")
	dash_asset.dodge_charges = 0.0
	var reinstall := BattleCommand.new()
	reinstall.build = dash_asset.compiled_build
	dash_asset.queue_command(reinstall)
	dash_asset.step(1.0 / 60)
	check(dash_asset.dodge_charges < 0.1, "Reinstalling the stable asset cannot refresh acquisition charge")
	var calibration := selection(&"frost", ["T57", "T59", "K19"])
	calibration.secondary_book = &"flame"
	var calibrated := compiler.compile(calibration)
	check(calibrated.success() and calibrated.build.mode(&"material-1") == &"cold" and calibrated.build.mode(&"material-2") == &"heat", "K19 installs a deterministic explicit two-material allocation")
	calibration.calibrated_materials = ["cold", "charge"]
	check(not compiler.compile(calibration).success(), "Calibration rejects a material without a legitimate source")
	var cross_book := room(selection(&"frost", ["T13"]))
	cast(cross_book)
	advance(cross_book, 1.0)
	check(cross_book.enemies[1].hp_q < cross_book.enemies[1].max_hp_q or cross_book.enemies[2].hp_q < cross_book.enemies[2].max_hp_q, "Conduct works from a non-lightning primary with paid power and charge")
	var thermal := room(selection(&"frost", ["T45"], {&"R066":1}))
	cast(thermal)
	advance(thermal, 0.5)
	check(not thermal.runtime.fields.is_empty() and not thermal.runtime.ongoing.is_empty(), "Heat can fund ongoing / ground portions without a pre-existing DOT ability")
	var long_chain := room(selection(&"storm", ["T13", "T14", "T16", "K09"], {&"R113":1, &"R046":1}))
	for index in 9:
		var extra := BattleEnemy.new()
		extra.id = StringName("chain-extra-%d" % index)
		extra.combat_locked = true
		extra.position = Vector2(0.63 + index * 0.02, 0.6)
		extra.previous_position = extra.position
		extra.hp_q = 5000 * Q
		extra.max_hp_q = extra.hp_q
		extra.frozen_time = 100.0
		extra.attack_clock = 100.0
		long_chain.enemies.append(extra)
	cast(long_chain)
	advance(long_chain, 2.0)
	var reached := 0
	for enemy in long_chain.enemies:
		if enemy.hp_q < enemy.max_hp_q: reached += 1
	check(reached > 8, "Legally paid long chains are not silently truncated at eight: %d contacts" % reached)
	var structured := CombatBuildOverride.new()
	structured.id = "event:E01:choice-B"
	structured.source_id = &"E01"
	structured.modes[&"guard-order"] = &"T24"
	structured.parameter_deltas[&"storage_slots"] = -1
	var structured_request := CombatAssetRequest.new()
	structured_request.action = CombatAssetRequest.Action.OVERRIDE
	structured_request.override = structured
	var prior_selection := selection(&"frost", ["T01", "T21", "T23"])
	var prior_build := compiler.compile(prior_selection).build
	var applied := service.prepare(prior_selection, structured_request)
	check(applied.has("command") and applied.command.build.mode_operation(&"guard-order") == &"newest" and applied.command.build.value(&"storage_slots") == -1, "Event mode replaces the active policy while keeping the permanent source")
	structured_request.action = CombatAssetRequest.Action.RESTORE
	var restored := service.prepare(applied.selection, structured_request)
	check(restored.has("command") and restored.command.build.identity() == prior_build.identity(), "Expiry restores the exact original configuration without earning resources")
	var contested := CombatBuildOverride.new()
	contested.id = "event:E01:conflict"
	contested.source_id = &"E01"
	contested.modes[&"guard-order"] = &"T23"
	applied.selection.overrides.append(contested)
	check(not compiler.compile(applied.selection).success(), "Conflicting temporary policies are explicit, never selected by array order")
	var suppression := CombatBuildOverride.new()
	suppression.id = "event:E26:choice-B"
	suppression.source_id = &"E26"
	suppression.disabled_capabilities = ["field-relay"]
	var suppressed_selection := selection(&"flame", ["T45", "T47"])
	suppressed_selection.overrides.append(suppression)
	check(not compiler.compile(suppressed_selection).build.has(&"field-relay") and "permit:talent:T47" in compiler.compile(suppressed_selection).build.permits(), "Temporary suppression stops future objects without erasing permanent permissions")
	var equal_providers := compiler.compile(selection(&"frost", ["T23"], {&"R141":1}))
	check(equal_providers.success() and equal_providers.build.value(&"guard_efficiency_q") == 204, "Equivalent mode providers share one behavior and keep both declared numeric increments")
	for book in BuildCompiler.BOOKS:
		for shape: StringName in BuildCompiler.SHAPES[book]:
			var shape_selection := selection(book, ["T58"])
			shape_selection.focus_shape = shape
			var shaped_room := room(shape_selection)
			cast(shaped_room)
			if shape == &"lightning_beam": check(shaped_room.effects.all(func(effect: BattleEffect) -> bool: return effect.kind != &"storm_arc"), "Lightning beam uses a real straight contact path instead of jumping")
			advance(shaped_room, 0.8)
			check(shaped_room.runtime.actual_damage_q > 0, "Focused shape produces real paid native contact: " + str(shape))
			if shape == &"flame_column": check(not shaped_room.runtime.fields.is_empty() and shaped_room.runtime.fields[0].center != shaped_room.runtime.fields[0].endpoint, "Flame column creates a finite capsule along the actual cast line")
			if shape == &"lone_blade": check(shaped_room.spirits.size() == 1, "Lone blade keeps one body and concentrates its paid attack queue")
	var ordinary_page := room(selection(&"frost", ["T01", "T28"]))
	cast(ordinary_page)
	var ordinary_shell := ordinary_page.runtime.stored[0]
	check(ordinary_shell.effect.shape_plan_ready and not ordinary_shell.effect.shaped, "Stored ordinary shape freezes choices without launching its branches")
	var late_selection := selection(&"frost", ["T01", "T28", "T58", "T60", "K20"], {&"R168":1})
	late_selection.focus_shape = &"ice_lance"
	var late_page := room(late_selection)
	cast(late_page)
	var late_shell := late_page.runtime.stored[0]
	check(not late_shell.effect.shape_plan_ready and not late_shell.effect.shaped, "R168 holds genuinely unallocated paid power until release")
	ordinary_page.enemies[1].position = Vector2(0.1, 0.1)
	late_page.enemies[1].position = Vector2(0.1, 0.1)
	ordinary_page.runtime._close_shell(ordinary_shell, &"release")
	late_page.runtime._close_shell(late_shell, &"release")
	check(ordinary_shell.effect.lot.amount_q == 0 and late_shell.effect.lot.amount_q == 0, "Release transfers complete ownership once for ordinary and late shapes")
	var convoy := room(selection(&"spirit", ["T01", "T19", "T25", "T27", "K12"], {&"R072":1}))
	cast(convoy, 0, "abcdefghijklmnopqrstuvwxyzabcdefghijkl")
	var compatible_pages: Array[StoredSpell] = convoy.runtime.stored.filter(func(page: StoredSpell) -> bool: return page.effect.lot.claims.has(&"copied"))
	check(compatible_pages.size() == 2 and compatible_pages.all(func(page: StoredSpell) -> bool: return page.merged_sources == 1), "K12 waits until pickup to merge genuinely compatible copy portions")
	var before_transport := compatible_pages[0].effect.lot.amount_q + compatible_pages[1].effect.lot.amount_q
	var convoy_carrier := convoy.spirits[0]
	convoy_carrier.target_id = convoy.enemies[0].id
	convoy_carrier.effect = convoy.runtime.take_spirit_attack(convoy.enemies[0], convoy_carrier.position)
	var convoy_cargo := convoy.runtime.pickup(convoy_carrier)
	check(convoy_cargo != null and convoy_cargo.merged_sources == 2 and convoy_cargo.effect.lot.amount_q == before_transport - before_transport * 124 / Q, "Transport aggregates first and charges loss against the entire cargo")
	var hot_selection := selection(&"frost", ["T01", "T05", "K04"], {&"R099":1})
	var heat_override := CombatBuildOverride.new()
	heat_override.id = "event:E07:open"
	heat_override.source_id = &"E07"
	heat_override.modes[&"shell-heat-mode"] = &"K05"
	hot_selection.overrides.append(heat_override)
	var hot_room := room(hot_selection)
	cast(hot_room)
	var hot_shell := hot_room.runtime.stored[0]
	var heat_effect := preload("res://tests/godot/combat_fixture.gd").effect(hot_room, &"counter", hot_room.enemies[0].id, Q, 0.0, hot_shell.position)
	heat_effect.heat = hot_room.ledger.earn("heat-fixture", &"fixture", hot_room.compiled_build.identity(), SpellLot.Kind.HEAT, Q, &"fixture")
	hot_room.runtime._heat_contact(heat_effect, hot_shell.position)
	check(hot_shell.closed and heat_effect.heat.amount_q == 3 * Q / 4, "Explicit heat policy overrides passive heat retention and consumes the true threshold")
	var scatter := room(selection(&"frost", ["T31", "T32", "K14"]))
	scatter.typing.select_target(scatter.enemies[0].id)
	for character in "abc": scatter.typing.feed(character)
	scatter.step(1.0 / 60)
	scatter.enemies[0].hp_q = Q
	preload("res://tests/godot/combat_fixture.gd").hit(scatter, scatter.enemies[0], 2 * Q, &"counter", scatter.player_position)
	check(not scatter.runtime.letter_marks.is_empty(), "Interrupted manual positions transfer their existing opportunities to real matching positions")
	var mark: Dictionary = scatter.runtime.letter_marks[0]
	var mark_lot: SpellLot = mark.lot
	scatter.typing.select_target(mark.target)
	scatter.typing.feed(mark.character)
	scatter.step(1.0 / 60)
	check(mark_lot.amount_q == 0 and scatter.runtime._letter_rewards.has(scatter.typing.current_attempt_id()), "Matching human input redeems the marked position exactly once")
	var invalid_mark: Dictionary = scatter.runtime.letter_marks[0]
	scatter.typing.upsert_target(invalid_mark.target, "stone")
	scatter.step(1.0 / 60)
	check(not scatter.runtime.letter_marks.has(invalid_mark) and invalid_mark.lot.amount_q == 0, "A changed word version expires stale letter opportunities")
	var frozen_recovery := room(selection(&"flame", ["T49", "T07", "T11"]))
	cast(frozen_recovery)
	advance(frozen_recovery, 0.5)
	var stripped := BattleCommand.new()
	stripped.build = compiler.compile(selection(&"flame", ["T11"])).build
	frozen_recovery.queue_command(stripped)
	frozen_recovery.step(1.0 / 60)
	var recovered_result := frozen_recovery.finish_room(&"victory")
	check(not recovered_result.reserve.is_empty(), "Existing status retains its snapshot recovery contract after capability removal")
	var followup := room(selection(&"frost", [], {&"R008":1}))
	var counter_effect := followup.runtime.counter("followup-attack", 20 * Q, followup.enemies[0].id, followup.player_position)
	check(not followup.runtime._counter_reserve.is_empty() and counter_effect.lot.amount_q < 43 * Q, "R008 reserves part of the actual reflected budget for the next manual cast")
	var load_selection := selection(&"flame", ["T01", "T19", "T21", "T22", "T25", "T26", "T13", "T14", "T31", "T45", "T47", "T48", "T52", "T12", "T49", "T50"])
	var load_room := room(load_selection)
	var max_objects := 0
	var max_step_us := 0
	for iteration in 40:
		cast(load_room, iteration % 3)
		for tick in 18:
			var began := Time.get_ticks_usec()
			load_room.step(1.0 / 60)
			max_step_us = maxi(max_step_us, Time.get_ticks_usec() - began)
			max_objects = maxi(max_objects, load_room.projectiles.size() + load_room.runtime.stored.size() + load_room.runtime.fields.size() + load_room.runtime.ongoing.size() + load_room.runtime.spirit_attacks.size())
	advance(load_room, 30.0)
	check(load_room.effects.is_empty() and load_room.projectiles.is_empty() and load_room.runtime.stored.is_empty() and load_room.runtime.fields.is_empty() and load_room.runtime.ongoing.is_empty() and load_room.runtime.spirit_attacks.is_empty(), "High-load automatic chains settle after input stops")
	print("M3 LOAD: peak active=%d max fixed step=%dus (local headless sample)" % [max_objects, max_step_us])
	for session in sessions:
		if session.room_result == null: session.finish_room(&"abandon")
		check(session.ledger.active_lots().all(func(lot: SpellLot) -> bool: return lot.owner == &"handoff"), "Room cleanup leaves only authorized handoff lots")
		session.queue_free()
	await process_frame
	print("M3 mechanisms: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _review_rule_gaps() -> void:
	for relic: StringName in [&"R037", &"R041"]:
		var baseline := room(selection(&"frost"))
		var equipped := room(selection(&"frost", [], {relic: 1}))
		cast(baseline)
		cast(equipped)
		check(baseline.runtime.work_bank.is_empty() and _review_work_total(equipped) == 12 * Q, "%s alone receives the shared manual work supply" % relic)
		var before := _review_work_total(equipped)
		var origin := equipped.enemies[0].position + Vector2(0.01, 0)
		equipped.runtime.on_dodge(origin, origin)
		check(_review_work_total(equipped) == before - (2 * Q if relic == &"R037" else Q), "%s pays its actual dodge cost" % relic)
		check(not equipped.runtime.fields.is_empty() if relic == &"R037" else equipped.dodge_window > 0.0, "%s produces its dodge effect" % relic)
		if relic == &"R037": check(equipped.enemies[0].impulse.length() > 0.0, "R037 pulls a real nearby enemy")
		var empty := room(selection(&"frost", [], {relic: 1}))
		var spent := empty.ledger.raw_spent_q
		empty.runtime.on_dodge(origin, origin)
		check(empty.ledger.raw_spent_q == spent and empty.runtime.fields.is_empty() and empty.dodge_window == 0.0, "%s cannot spend without manual funding" % relic)
	var shared := room(selection(&"frost", [], {&"R037": 1, &"R041": 1}))
	cast(shared)
	check(_review_work_total(shared) == 12 * Q, "Two dodge consumers share one bank direction without duplicate income")
	for concentrated: bool in [false, true]:
		var assets: Dictionary[StringName, int] = {}
		if concentrated: assets[&"R073"] = 1
		var copy_room := room(selection(&"frost", ["T19"], assets))
		var template := preload("res://tests/godot/combat_fixture.gd").effect(copy_room, &"frost_spear", copy_room.enemies[0].id, 40 * Q, 0.0, copy_room.player_position)
		var fee := copy_room.ledger.earn("review-copy-fee", &"fixture", copy_room.compiled_build.identity(), SpellLot.Kind.WORK, 12 * Q, &"fixture")
		copy_room.runtime._make_copy(fee, template)
		var expected := 40 * Q * (920 if concentrated else 460) / Q
		check(fee.amount_q == 0 and copy_room.runtime.stored.size() == 1, "Copy pays the same twelve work units for one page")
		check(copy_room.runtime.stored[0].effect.lot.amount_q == expected and expected <= 48 * Q, "R073 doubles retention while remaining within paid conversion output")
		check(copy_room.runtime.stored[0].space_units == (2 if concentrated else 1), "R073 charges extra space only to its strengthened copy")
		if concentrated:
			copy_room.runtime._store(template)
			check(copy_room.runtime.stored.back().space_units == 1, "Non-copy storage retains its ordinary occupancy with R073 equipped")
			var blocked_fee := copy_room.ledger.earn("review-blocked-copy", &"fixture", copy_room.compiled_build.identity(), SpellLot.Kind.WORK, 12 * Q, &"fixture")
			copy_room.runtime._make_copy(blocked_fee, template)
			check(blocked_fee.amount_q == 12 * Q and copy_room.runtime.stored.size() == 2, "Insufficient copy capacity does not deduct manufacture funding")
		var poor := room(selection(&"frost", ["T19"], assets))
		var poor_template := preload("res://tests/godot/combat_fixture.gd").effect(poor, &"frost_spear", poor.enemies[0].id, 40 * Q, 0.0, poor.player_position)
		var insufficient := poor.ledger.earn("review-poor-copy", &"fixture", poor.compiled_build.identity(), SpellLot.Kind.WORK, Q, &"fixture")
		poor.runtime._make_copy(insufficient, poor_template)
		check(insufficient.amount_q == Q and poor.runtime.stored.is_empty(), "Insufficient manufacture funding remains unspent")
	var split_copy := room(selection(&"frost", ["T19"], {&"R072": 1, &"R073": 1}))
	var split_template := preload("res://tests/godot/combat_fixture.gd").effect(split_copy, &"frost_spear", split_copy.enemies[0].id, 100 * Q, 0.0, split_copy.player_position)
	var split_fee := split_copy.ledger.earn("review-split-copy", &"fixture", split_copy.compiled_build.identity(), SpellLot.Kind.WORK, 12 * Q, &"fixture")
	split_copy.runtime._make_copy(split_fee, split_template)
	check(split_copy.runtime.stored.size() == 2 and split_copy.runtime._storage_occupancy() == 4, "R072 and R073 coexist as two concentrated pages occupying two slots each")
	var split_total := 0
	for page in split_copy.runtime.stored: split_total += page.effect.lot.amount_q
	check(split_fee.amount_q == 0 and split_total == 48 * Q, "Concentration and splitting cannot create power beyond the same paid conversion output")
	var frost := room(selection(&"frost"))
	var pierced := room(selection(&"frost", ["T03"]))
	var base := preload("res://tests/godot/combat_fixture.gd").effect(frost, &"frost_spear", frost.enemies[0].id, 12 * Q, 0.0, frost.player_position)
	var improved := preload("res://tests/godot/combat_fixture.gd").effect(pierced, &"frost_spear", pierced.enemies[0].id, 12 * Q, 0.0, pierced.player_position)
	frost.runtime._configure_shape(base)
	pierced.runtime._configure_shape(improved)
	check(base.applications == 3 and improved.applications == 4 and improved.primary_share_q == base.primary_share_q * 3 / 4, "T03 adds one contact after the native frost shape and reduces its primary share")
	var share := improved.primary_share_q
	var spent_before := pierced.ledger.raw_spent_q
	var first_hp := pierced.enemies[0].hp_q
	pierced.runtime.contact(improved, pierced.enemies[0], pierced.player_position)
	check(first_hp - pierced.enemies[0].hp_q == share, "T03 primary contact uses exactly the reduced existing share")
	for index in 3: pierced.runtime.contact(improved, pierced.enemies[index], pierced.player_position, false)
	check(improved.lot.amount_q == 0 and pierced.ledger.raw_spent_q - spent_before == 12 * Q, "T03 primary, along-path contacts and retention loss conserve the original power")
	var shaped_selection := selection(&"frost", ["T03"])
	var shape_override := CombatBuildOverride.new()
	shape_override.id = "review:ice-lance"
	shape_override.source_id = &"fixture"
	shape_override.modes[&"shape"] = &"ice_lance"
	shaped_selection.overrides.append(shape_override)
	var shaped_room := room(shaped_selection)
	var shaped := preload("res://tests/godot/combat_fixture.gd").effect(shaped_room, &"frost_spear", shaped_room.enemies[0].id, 20 * Q, 0.0, shaped_room.player_position)
	shaped_room.runtime._configure_shape(shaped)
	check(shaped.applications == 3 and shaped.primary_share_q == 12 * Q, "T03 also processes the ice-lance base of two contacts and four-fifths primary power")


func _review_work_total(session: BattleSession) -> int:
	var total := 0
	for lot in session.runtime.work_bank: total += lot.amount_q
	return total
