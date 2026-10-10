extends "res://tests/godot/test_s1_rules.gd"



func _run() -> void:
	if "--four-books" in OS.get_cmdline_user_args():
		_run_four_books()
		return
	var compiler := BuildCompiler.new()
	var ice := _session(&"frost")
	_word(ice, "abcd")
	var spear := ice.projectiles[0].effect
	var primary_damage := spear.damage_q
	var first_hp := ice.enemies[0].hp_q
	var second_hp := ice.enemies[1].hp_q
	ice.runtime.contact(spear, ice.enemies[1], ice.player_position, false)
	ice.runtime.contact(spear, ice.enemies[0], ice.player_position, true)
	_check(first_hp - ice.enemies[0].hp_q == primary_damage, "ice primary retains full damage after an intervening pierce")
	_check(second_hp - ice.enemies[1].hp_q == primary_damage, "ice secondary retains equal damage")
	_check(spear.lot.amount_q == 0, "normal ice has exactly one primary and one paid pierce")
	for index in 2: _word(ice, "abcd")
	_check(ice.projectiles[2].effect.applications == 4, "third ice cast has three finite pierces")
	var echo_ice := _session(&"frost", {&"R006": 1})
	for index in 3: _word(echo_ice, "abcd")
	var source_damage := echo_ice.projectiles[3].effect.damage_q
	@warning_ignore("integer_division")
	_check(echo_ice.projectiles[2].effect.kind == &"echo" and echo_ice.projectiles[2].effect.damage_q == source_damage * 665 / 1024, "ice echo copies one primary strike, not the pierce pool")
	var acquisition := AcquisitionService.new(compiler)
	_check(AcquisitionService.ACTIVE_RELICS.size() == 58, "58 baseline identities are registered")
	for id in AcquisitionService.ACTIVE_RELICS:
		var definition := compiler.catalog.get_definition(id) as RelicDefinition
		var selection := BuildSelection.new()
		if not definition.allowed_books.is_empty(): selection.book_id = StringName(definition.allowed_books[0])
		for required in definition.requires_all: selection.assets[StringName(required)] = 1
		_check(definition.permits.is_empty(), "%s has no permanent permit" % id)
		_check(not definition.description.is_empty(), "%s has final description" % id)
		_check(acquisition.evaluate(selection, id, {"shortest": 3, "longest": 8}).eligible, "%s is obtainable with main-book prerequisites" % id)
		selection.assets[id] = definition.max_stacks
		_check(compiler.compile(selection).success(), "%s compiles at baseline stack limit" % id)
		_check(not acquisition.evaluate(selection, id, {"shortest": 3, "longest": 8}).eligible, "%s cannot exceed stack limit" % id)
		if not definition.requires_all.is_empty():
			selection.assets.erase(StringName(definition.requires_all[0]))
			_check(not compiler.compile(selection).success(), "%s requires all awakening components" % id)
	var no_feather := _session(&"frost")
	for index in 6: _word(no_feather, "abcd")
	_check(not no_feather.compiled_build.has(&"assist") and not no_feather.runtime.assist_ready() and not no_feather.runtime.consume_assist(), "manual input cannot unlock Ctrl without the feather relic")
	no_feather.typing.upsert_target(no_feather.enemies[0].id, "abcd")
	no_feather.typing.select_target(no_feather.enemies[0].id)
	no_feather.typing.feed("a")
	no_feather.queue_action(&"assist")
	no_feather.step(0.0)
	_check(no_feather.typing.progress == 1 and no_feather.completed_words == 6, "Ctrl without the relic preserves the current word")
	no_feather.runtime._assist_tokens = 1
	_check(not no_feather.runtime.assist_ready() and not no_feather.runtime.consume_assist(), "a saved token cannot authorize assistance without its relic")
	var periodic := _session(&"frost", {&"R013": 2, &"R039": 2, &"R017": 1})
	periodic.player_hp_q = 50 * 1024
	for index in 6:
		_word(periodic, "abcd")
		if index == 2: _check(not periodic.runtime.assist_ready(), "feather requires four manual words before its first opportunity")
		if index == 3: _check(periodic.compiled_build.has(&"assist") and periodic.runtime.assist_ready(), "feather activates assistance on the fourth manual word")
	_check(periodic.player_hp_q == 58 * 1024, "six casts heal by leech layers")
	_check(periodic.run_state.shield_q == 24 * 1024, "five casts grant ward shield")
	_check(periodic.runtime._assist_tokens == 1, "four manual words create one explicit assist opportunity")
	_check(periodic.runtime.consume_assist() and periodic.runtime._assist_tokens == 0, "explicit assist consumes opportunity once")
	_check(not periodic.runtime.assist_ready() and not periodic.runtime.consume_assist(), "spent feather opportunities cannot fall back to general work resources")
	var partial := _session(&"flame", {&"R011": 1})
	partial.typing.upsert_target(partial.enemies[0].id, "abcd")
	partial.typing.select_target(partial.enemies[0].id)
	partial.typing.feed("a")
	partial.enemies[0].hp_q = 0
	partial.runtime.on_enemy_death(partial.enemies[0], &"fixture")
	partial.runtime.on_enemy_death(partial.enemies[0], &"fixture")
	_check(partial.run_state.shield_q == 10 * 1024, "partial-word death grants shield once without spending input")
	var corrosion := _session(&"spirit", {&"R028": 2})
	_word(corrosion, "abcd")
	var hp := corrosion.enemies[0].hp_q
	corrosion.runtime.advance(1.0)
	_check(hp - corrosion.enemies[0].hp_q == 16 * 1024, "corrosion has independent per-second damage")
	for index in 3:
		_word(corrosion, "abcd")
	_check(corrosion.runtime.ongoing.size() == 1 and corrosion.runtime.ongoing[0].stacks == 3, "direct contacts refresh corrosion and cap its independent status at three stacks")
	hp = corrosion.enemies[0].hp_q
	corrosion.runtime.advance(0.5)
	_check(corrosion.enemies[0].hp_q == hp, "corrosion refresh preserves the next one-second tick")
	corrosion.runtime.advance(3.5)
	_check(hp - corrosion.enemies[0].hp_q == 4 * 48 * 1024 and corrosion.runtime.ongoing.is_empty(), "refreshed corrosion spends exactly four seconds of three-stack damage and expires")
	hp = corrosion.enemies[0].hp_q
	corrosion.runtime.advance(1.0)
	_check(corrosion.enemies[0].hp_q == hp, "expired corrosion does not keep dealing damage")
	var execution := _session(&"flame", {&"R027": 1})
	execution.enemies[0].hp_q = 100 * 1024
	_word(execution, "abcd")
	execution.runtime.contact(execution.projectiles[0].effect, execution.enemies[0], execution.player_position)
	_check(not execution.enemies[0].alive(), "ordinary enemy below eighteen percent is executed")
	var frozen := _session(&"frost", {&"R004": 2, &"R032": 1, &"R044": 1})
	frozen.enemies[0].frozen_time = 1.0
	frozen.runtime._deal(frozen.enemies[0], frozen.enemies[0].hp_q, &"fixture", frozen.player_position)
	_check(not frozen.effects.is_empty() and frozen.effects.size() <= 6, "root frozen death emits bounded awakening needles")
	var fire := _session(&"flame", {&"R050": 1, &"R051": 2, &"R052": 2, &"R056": 1})
	fire.runtime._burn(fire.enemies[0], 5)
	_check(fire.enemies[0].burn == 127, "flame awakening caps accumulated burn points")
	fire.runtime._deal(fire.enemies[0], fire.enemies[0].hp_q, &"fixture", fire.player_position)
	_check(fire.enemies[1].burn == 98 and fire.enemies[1].burn_depth == 1, "wildfire spreads bounded burn points and generation")
	var gravity := _session(&"flame", {&"R037": 1, &"R055": 2})
	gravity.runtime.on_dodge(gravity.player_position, Vector2.ZERO)
	_check(gravity.runtime.fields.size() == 2, "gravity well and fire trail coexist at dodge origin")
	var graze := _session(&"frost", {&"R038": 1})
	var threat := BattleThreat.new()
	threat.attack_id = "graze-once"
	graze.runtime.graze(threat)
	graze.runtime.graze(threat)
	_check(graze.run_state.shield_q == int(0.6 * 1024), "one bullet grants grazing shield once")
	var disarm := _session(&"frost", {&"R008": 1})
	_check(is_equal_approx(disarm.runtime.on_disarm(), 1.6), "disarm gets independent relic multiplier")
	_word(disarm, "abcd")
	var boosted := disarm.projectiles[0].effect.damage_q
	_word(disarm, "abcd")
	_check(boosted > disarm.projectiles[1].effect.damage_q * 1.8, "disarm boost applies to exactly the next cast")
	var counter_item := _session(&"spirit", {&"R008": 1})
	var counter_origin := Vector2(0.5, 0.5)
	for enemy in counter_item.enemies: enemy.position = counter_origin
	for index in 5:
		var enemy := BattleEnemy.new()
		enemy.id = StringName("counter-range-%d" % index)
		enemy.position = counter_origin + Vector2(400.0 + 30.0 * index if index < 4 else 521.0, 0.0) / BattleSession.ARENA_SIZE
		enemy.hp_q = 10000 * 1024
		enemy.max_hp_q = enemy.hp_q
		enemy.boss = index == 3
		enemy.phase = 3
		counter_item.enemies.append(enemy)
		counter_item._enemies_by_id[enemy.id] = enemy
		counter_item._enemy_definitions[enemy.id] = counter_item._enemy_definitions.values()[0]
	var rune := BattlePickup.new()
	rune.kind = &"rune"
	rune.position = counter_origin
	var rune_fact := WordCompletion.new()
	rune_fact.word = "abcd"
	rune_fact.attempt_id = "counter-item-empty"
	counter_item.runtime.on_pickup_completed(rune, 0, rune_fact, {"work_q": 0})
	var counter_damage := int(12 * 1024 * 1.6)
	for index in 6:
		_check(counter_item.enemies[index].hp_q == 10000 * 1024 - counter_damage, "counter item hits every target in enlarged radius, including boss %d" % index)
	_check(counter_item.enemies[6].hp_q == 10000 * 1024, "counter item excludes target outside 520 radius")
	rune_fact.attempt_id = "counter-item-projectiles"
	counter_item.runtime.on_pickup_completed(rune, 22, rune_fact, {"work_q": 0})
	_check(counter_item.enemies[0].hp_q == 10000 * 1024 - 2 * counter_damage, "reflected projectile count does not increase counter item area damage")
	var crit := _session(&"frost", {&"R022": 1})
	for index in 4: _word(crit, "abcd")
	_check(crit.projectiles[3].effect.damage_q > crit.projectiles[2].effect.damage_q * 1.9, "fourth cast produces critical cadence")
	periodic.runtime.finish(&"victory")
	var checkpoint := RunStateCodec.decode(RunStateCodec.encode(periodic.run_state))
	var next_room := BattleSession.new()
	sessions.append(next_room)
	var next_request := BattleStartRequest.new()
	next_request.build = periodic.compiled_build
	next_request.vocabulary = [VocabularyEntry.new("abcd", "test")]
	next_request.vocabulary_index = VocabularyIndex.build(next_request.vocabulary)
	next_request.seed_text = "cross-room-counters"
	next_room.start(next_request, checkpoint)
	_check(next_room.runtime._cast_count == 6 and next_room.runtime._manual_words == 6 and next_room.runtime._assist_tokens == 0, "word cadence and consumed assist survive room checkpoint")
	_check(next_room.runtime.book_cast_count() == 6 and not next_room.runtime.next_empowered(), "main spell cadence survives room checkpoint")
	next_room.runtime._book_cast_count = 2
	_check(next_room.runtime.next_empowered(), "next main word predicts third spell enhancement")
	var pickup := BattlePickup.new()
	pickup.kind = &"ink"
	var pickup_fact := WordCompletion.new()
	pickup_fact.word = "abcd"
	pickup_fact.attempt_id = "cadence-pickup"
	next_room.runtime.on_pickup_completed(pickup, 0, pickup_fact, {"work_q": 0})
	_check(next_room.runtime.book_cast_count() == 2 and next_room.runtime.next_empowered(), "pickup advances relic cadence without consuming main spell enhancement")
	var growth := BuildSelection.new()
	var thunder := _session(&"storm", {&"R017": 1, &"R034": 1, &"R040": 1, &"R047": 1})
	var primary := BattleEffect.new()
	primary.damage_q = 100 * 1024
	var strike := thunder.runtime.storm_word_strike(primary, thunder.enemies[0], 0.1)
	thunder.effects.append(strike)
	_check(thunder.run_state.shield_q == 0 and strike.damage_q == 70 * 1024, "ultimate word strike earns independent seventy-percent damage without granting shield early")
	thunder._advance_effects(0.1)
	_check(thunder.run_state.shield_q == 2 * 1024, "actual ultimate word strike contact grants shield")
	var cancelled := thunder.runtime.storm_word_strike(primary, thunder.enemies[1], 0.1)
	thunder.effects.append(cancelled)
	thunder.enemies[1].hp_q = 0
	thunder._advance_effects(0.1)
	_check(thunder.run_state.shield_q == 2 * 1024 and cancelled.lot.amount_q == 0, "dead scheduled target cancels strike and grants no shield")
	thunder.ultimate_time = 3.0
	thunder.runtime._assist_tokens = 1
	thunder.typing.upsert_target(thunder.enemies[0].id, "abcd")
	thunder.typing.select_target(thunder.enemies[0].id)
	thunder.typing.feed("a")
	thunder.typing.complete_assisted()
	thunder.step(0.0)
	_check(thunder.completed_words == 0 and thunder.runtime.book_cast_count() == 1 and thunder.run_state.shield_q == 4 * 1024, "assisted main word triggers ultimate strike while counting only its manual characters")
	growth.base_hp = 155
	growth.growth_hp = 20
	growth.assets[&"R012"] = 1
	var grown := compiler.compile(growth)
	_check(grown.success() and grown.build.maximum_hp_q() == 195 * 1024, "difficulty health, growth and relic health add independently")
	_check(growth.copy().growth_hp == 20 and growth.copy().base_hp == 155, "growth and base health survive selection copy")
	_check(BuildSelection.from_dict(growth.to_dict()).growth_hp == 20, "growth snapshot survives serialization")
	var legacy := growth.to_dict()
	legacy.erase("growth_hp")
	legacy.erase("base_hp")
	_check(BuildSelection.from_dict(legacy).growth_hp == 0 and BuildSelection.from_dict(legacy).base_hp == 100, "old selection gets explicit zero-growth baseline")
	var plain_growth := growth.copy()
	plain_growth.growth_hp = 0
	_check(compiler.compile(plain_growth).build.identity() != grown.build.identity(), "growth contributes to immutable build identity")
	growth.growth_hp = 21
	_check(not compiler.compile(growth).success(), "growth cap is enforced at compile boundary")
	growth.growth_hp = 0
	growth.base_hp = 0
	_check(not compiler.compile(growth).success(), "difficulty health range is enforced")
	for session in sessions: session.free()
	print("S2_RULES: ", "PASS" if failures == 0 else "FAIL ", failures)
	quit(0 if failures == 0 else 1)


func _run_four_books() -> void:
	_four_input_contract()
	_four_dead_target()
	_four_paper()
	_four_flame()
	_four_frost()
	_four_storm()
	_four_defenses()
	for session in sessions: session.free()
	print("FOUR_BOOKS: ", "PASS" if failures == 0 else "FAIL ", failures)
	quit(0 if failures == 0 else 1)


func _four_session(book: StringName, assets: Dictionary = {}) -> BattleSession:
	var session := _session(book, assets)
	# Fixed-position fixtures suppress autonomous movement and attacks; paid hit impulses remain real.
	for enemy in session.enemies:
		enemy.stationary = true
		enemy.speed = 0.0
		enemy.attack_clock = 1000.0
	return session


func _four_events(session: BattleSession) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	session.event_committed.connect(func(event: Dictionary) -> void: events.append(event))
	return events


func _four_impacts(events: Array[Dictionary], source: StringName) -> Array[Dictionary]:
	var impacts: Array[Dictionary] = []
	for event in events:
		if event.get("kind") == &"impact" and event.get("source") == source: impacts.append(event)
	return impacts


func _four_target(session: BattleSession, index: int, position: Vector2) -> BattleEnemy:
	var enemy := BattleEnemy.new()
	enemy.id = StringName("four-target-%d" % index)
	enemy.word = "abcde"
	enemy.position = position
	enemy.previous_position = position
	enemy.hp_q = 10000 * 1024
	enemy.max_hp_q = enemy.hp_q
	enemy.stationary = true
	enemy.speed = 0.0
	enemy.attack_interval = 1000.0
	enemy.attack_clock = 1000.0
	session.enemies.append(enemy)
	session._enemies_by_id[enemy.id] = enemy
	session._enemy_definitions[enemy.id] = session._enemy_definitions.values()[0]
	return enemy


func _four_input_contract() -> void:
	for book in BuildCompiler.BOOKS:
		var session := _four_session(book)
		var events := _four_events(session)
		for index in 3: _word(session, "abcde")
		var casts: Array[Dictionary] = []
		for event in events:
			if event.get("kind") == &"cast": casts.append(event)
		_check(casts.size() == 3 and not casts[0].empowered and not casts[1].empowered and casts[2].empowered, "%s strengthens exactly its third direct completion" % book)
		_check(session.runtime.book_cast_count() == 3 and session.manual_characters == 15, "%s counts one cast per real word" % book)
		_check(session.resonance_q == 15 * roundi(1.2 * 1024) + 9 * 1024, "%s earns manual, completion and perfect resonance once" % book)
	var assisted := _four_session(&"frost", {&"R017": 1, &"R006": 1})
	for index in 4: _word(assisted, "abcde")
	var before := assisted.resonance_q
	assisted.typing.upsert_target(assisted.enemies[0].id, "abcde")
	assisted.typing.select_target(assisted.enemies[0].id)
	assisted.typing.feed("a")
	assisted.queue_action(&"assist")
	assisted.step(0.0)
	var effect := assisted.projectiles[-1].effect
	_check(assisted.runtime.book_cast_count() == 5 and assisted.completed_words == 4 and assisted.manual_characters == 21, "assisted completion counts once, copies do not advance book cadence")
	_check(effect.manual_count == 1 and not effect.empowered, "assisted main spell uses only its one manual character")
	_check(assisted.resonance_q - before == roundi(1.2 * 1024) + 3 * 1024, "assisted characters earn no manual resonance")
	var bottle := assisted.spawn_pickup(&"ink")
	assisted.typing.select_target(bottle.id)
	for character in bottle.word: assisted.typing.feed(character)
	assisted.step(0.0)
	_check(assisted.runtime.book_cast_count() == 5 and assisted.runtime.next_empowered(), "item completion leaves next book enhancement intact")
	var imperfect := _four_session(&"frost")
	imperfect.typing.upsert_target(imperfect.enemies[0].id, "abcde")
	imperfect.typing.select_target(imperfect.enemies[0].id)
	imperfect.typing.feed("x")
	for character in "abcde": imperfect.typing.feed(character)
	imperfect.step(0.0)
	_check(imperfect.resonance_q == 5 * roundi(1.2 * 1024) + 2 * 1024, "a mistaken word earns completion but no perfect bonus")
	assisted.ultimate_time = 2.0
	before = assisted.resonance_q
	_word(assisted, "abcde")
	assisted.runtime.graze(BattleThreat.new())
	assisted.add_resonance(50 * 1024)
	_check(assisted.resonance_q == before, "active ultimate blocks manual, word, defense and explicit resonance income")


func _four_dead_target() -> void:
	var session := _four_session(&"frost")
	var original := session.enemies[0]
	original.position = Vector2(0.62, 0.35)
	original.previous_position = original.position
	session.enemies[1].position = Vector2(0.64, 0.35)
	session.enemies[1].previous_position = session.enemies[1].position
	var far := _four_target(session, 2, Vector2(0.36, 0.5))
	var events := _four_events(session)
	session.typing.upsert_target(original.id, "abcde")
	session.typing.select_target(original.id)
	session.typing.feed("a")
	session.typing.feed("b")
	session.step(0.0)
	session.runtime._deal(original, original.hp_q, &"counter", original.position)
	_check(session.typing.target_id == original.id and session.typing.progress == 2, "death retains the in-progress original word")
	for character in "cde": session.typing.feed(character)
	session.step(0.0)
	var effect := session.projectiles[0].effect
	_check(effect.target_id == session.enemies[1].id and effect.target_id != far.id and effect.manual_count == 5, "dead-word completion chooses the nearest legal enemy to the original position")
	_check(session.manual_characters == 5 and session.completed_words == 1 and session.runtime.book_cast_count() == 1, "dead-word continuation settles input and cast exactly once")
	_check(_four_impacts(events, &"counter").size() == 1, "fixture death is one real committed hit")


func _four_paper() -> void:
	var session := _four_session(&"spirit")
	var events := _four_events(session)
	_word(session, "abcd")
	_check(session.spirits.is_empty() and session.enemies[0].vulnerability == 16, "four completed manual characters mark immediately but do not wake a spirit")
	_word(session, "abcde")
	_check(session.spirits.size() == 1, "five cumulative completed manual characters wake one spirit")
	var existing := session.spirits[0]
	_word(session, "a")
	_check(session.spirits.size() == 2 and session.spirits[0] == existing and existing.crossing, "third cast commands the existing spirit and preserves its identity")
	var marks := _four_impacts(events, &"spirit_mark")
	_check(marks.size() == 3 and int(marks[0].damage_q) == roundi(int(marks[0].raw_q) * (1.0 + 32.0 / 127.0)), "instant mark applies the new vulnerability multiplier exactly once")
	_check(existing.effect.kind == &"spirit_cross" and existing.effect.damage_q > 0, "third cast gives the existing spirit a paid cross attack")
	for index in 5: _word(session, "abcde")
	_check(session.spirits.size() == 4 and session.enemies[0].vulnerability == 127, "continued manual input reaches the spirit and vulnerability caps")
	session.spirit_time = 0.2
	session.typing.upsert_target(session.enemies[0].id, "abcde")
	session.typing.select_target(session.enemies[0].id)
	session.typing.feed("a")
	session.step(0.0)
	_check(is_equal_approx(session.spirit_time, 8.0), "correct partial input renews active spirits without completing a word")
	session.step(7.9)
	_check(session.spirits.size() == 4, "idle tail preserves the complete formation before eight seconds")
	session.step(0.11)
	_check(session.spirits.size() == 3, "idle expiry sleeps one spirit rather than clearing the formation")
	session.step(1.01)
	_check(session.spirits.size() == 2, "continued idle sleeps the next spirit after its own interval")


func _four_flame() -> void:
	var burn := _four_session(&"flame")
	var target := burn.enemies[0]
	var hp := target.hp_q
	burn.runtime.add_burn(target, 70, "cold-burn")
	for index in 12: burn.runtime.advance(0.1)
	_check(target.burn == 10 and hp - target.hp_q == 72 * 1024, "cold target spends twelve finite burn ticks and retains ten points")
	hp = target.hp_q
	burn.runtime.advance(1.0)
	_check(target.burn == 10 and target.hp_q == hp, "residual heat does no damage without a new source")
	burn.runtime.add_burn(target, 70, "warm-burn")
	for index in 14: burn.runtime.advance(0.1)
	_check(target.burn == 10 and hp - target.hp_q == 84 * 1024, "inherited residual heat yields fourteen ticks on the next hit")
	burn.runtime.add_burn(target, 999, "cap")
	_check(target.burn == 127, "burn points saturate at 127")
	for layers in range(1, 4):
		var mist := _four_session(&"flame")
		for index in layers: mist.runtime._region(mist.enemies[0].position, 90.0, 2.0, &"fire_field")
		mist.runtime.advance(0.2)
		_check(mist.enemies[0].burn == [4, 6, 7][layers - 1], "%d overlapping fire mists apply geometric contributions" % layers)
	var blocked := _four_session(&"flame")
	blocked.enemies[0].position = blocked.player_position + Vector2(0.0, -260.0) / BattleSession.ARENA_SIZE
	blocked.enemies[1].position = blocked.player_position + Vector2(0.0, -130.0) / BattleSession.ARENA_SIZE
	for enemy in blocked.enemies: enemy.previous_position = enemy.position
	_word(blocked, "abcde")
	var original_hp := blocked.enemies[0].hp_q
	var front_hp := blocked.enemies[1].hp_q
	blocked._advance_projectiles(0.5)
	_check(blocked.enemies[0].hp_q == original_hp and blocked.enemies[1].hp_q < front_hp and blocked.enemies[1].burn == 70, "fire projectile stops at its first actual collision")
	for index in 2: _word(blocked, "abcde")
	blocked._advance_projectiles(0.5)
	_check(blocked.runtime.fields.size() == 1 and blocked.runtime.fields[0].center == blocked.enemies[1].position, "third flame cast leaves its fire mist at the actual blocking target")


func _four_frost() -> void:
	var ice := _four_session(&"frost")
	_word(ice, "abcde")
	var spear := ice.projectiles[0].effect
	var damage := spear.damage_q
	var hp0 := ice.enemies[0].hp_q
	var hp1 := ice.enemies[1].hp_q
	ice.runtime.contact(spear, ice.enemies[1], ice.player_position, false)
	ice.runtime.contact(spear, ice.enemies[0], ice.player_position, true)
	_check(hp0 - ice.enemies[0].hp_q == damage and hp1 - ice.enemies[1].hp_q == damage and spear.lot.amount_q == 0, "normal ice pays two equal contacts even when secondary resolves first")
	for index in 2: _word(ice, "abcde")
	_check(ice.projectiles[-1].effect.empowered and ice.projectiles[-1].effect.applications == 4 and ice.projectiles[-1].effect.damage_q > damage * 1.4, "third ice cast gains power and four finite contacts")
	var control := _four_session(&"frost")
	var target := control.enemies[0]
	control.runtime._apply_cold(target, 90 * 1024, control.compiled_build)
	_check(target.frozen_time == 0.0 and is_equal_approx(target.cold_move_scale(), 0.5) and is_equal_approx(target.cold_attack_scale(), 0.65), "ninety cold slows movement and attack without freezing")
	control.runtime._apply_cold(target, 1 * 1024, control.compiled_build)
	_check(target.cold == 31 and is_equal_approx(target.frozen_time, 0.9), "strictly above ninety cold consumes sixty and freezes for 0.9 seconds")
	var attack_clock := target.attack_clock
	control._advance_enemies(0.2)
	_check(target.attack_clock == attack_clock, "freeze pauses enemy attack progress")
	control.runtime.advance(0.9)
	_check(target.frozen_time == 0.0 and is_equal_approx(target.freeze_cooldown, 1.0), "ordinary thaw starts one second of freeze immunity")
	control._advance_enemies(0.1)
	_check(target.attack_clock < attack_clock, "thaw resumes the existing enemy attack progress")
	control.runtime._apply_cold(target, 200 * 1024, control.compiled_build)
	_check(target.cold == 127 and target.frozen_time == 0.0, "cold saturates during thaw immunity without refreezing")
	control.runtime.advance(1.0)
	_check(target.frozen_time > 0.0 and target.cold == 55, "remaining cold can freeze again when ordinary immunity ends")
	var boss := control.enemies[1]
	boss.boss = true
	control.runtime._apply_cold(boss, 91 * 1024, control.compiled_build)
	_check(is_equal_approx(boss.frozen_time, 0.45), "Boss uses its shorter freeze duration")
	control.runtime.advance(0.45)
	_check(is_equal_approx(boss.freeze_cooldown, 3.0), "Boss thaw grants three seconds of freeze immunity")
	var outside := _four_session(&"frost")
	var pushed := outside.enemies[0]
	pushed.position = Vector2(-0.2, 0.5)
	pushed.combat_locked = false
	pushed.frozen_time = 0.2
	outside.runtime.advance(0.3)
	_check(pushed.frozen_time == 0.0, "a frozen enemy pushed outside the combat boundary still thaws")


func _four_storm() -> void:
	for charged in [false, true]:
		var storm := _four_session(&"storm")
		storm.enemies[0].position = Vector2(0.25, 0.35)
		storm.enemies[1].position = storm.enemies[0].position + Vector2(200.0, 0.0) / BattleSession.ARENA_SIZE
		_four_target(storm, 2, storm.enemies[0].position + Vector2(400.0, 0.0) / BattleSession.ARENA_SIZE)
		_four_target(storm, 3, storm.enemies[0].position + Vector2(600.0, 0.0) / BattleSession.ARENA_SIZE)
		for enemy in storm.enemies: enemy.previous_position = enemy.position
		if charged: storm.enemies[0].shock = 31
		var events := _four_events(storm)
		_word(storm, "abcde")
		for index in 8: storm._advance_effects(0.081)
		var hits := _four_impacts(events, &"storm_arc")
		_check(hits.size() == (4 if charged else 3) and storm.effects.is_empty(), "charged=%s chain ends at its finite hit allowance" % charged)
		var visited: Dictionary = {}
		for hit in hits:
			_check(not visited.has(hit.enemy), "one chain never revisits %s" % hit.enemy)
			visited[hit.enemy] = true
		if hits.size() >= 3:
			_check(absf(float(hits[1].damage_q) / hits[0].damage_q - 0.6) < 0.002 and absf(float(hits[2].damage_q) / hits[0].damage_q - 0.2) < 0.002, "charged=%s chain preserves 100/60/20 percent natural decay" % charged)
		if charged:
			_check(storm.enemies[0].shock == 37 and absf(float(hits[-1].damage_q) / hits[0].damage_q - 0.2) < 0.002, "pre-hit shock spends thirty before new points and the extra hit keeps the tail floor")
		else:
			_check(storm.enemies[0].shock == 36 and storm.enemies[-1].shock == 0, "new shock does not charge its own hit or spend the untouched fourth target")
	var uncharged := _four_session(&"storm")
	_word(uncharged, "abcde")
	var charged_power := _four_session(&"storm")
	charged_power.enemies[0].shock = 31
	_word(charged_power, "abcde")
	_check(absf(float(charged_power.runtime.actual_damage_q) / uncharged.runtime.actual_damage_q - 1.25) < 0.002, "pre-existing shock adds one quarter of the hit and carries the charge onward")
	for points in [30, 31, 60, 61]:
		var reach := _four_session(&"storm")
		reach.enemies[0].position = Vector2(0.25, 0.35)
		var distance := 400.0 if points <= 31 else 600.0
		reach.enemies[1].position = reach.enemies[0].position + Vector2(distance, 0) / BattleSession.ARENA_SIZE
		reach.enemies[1].shock = points
		for enemy in reach.enemies: enemy.previous_position = enemy.position
		var events := _four_events(reach)
		_word(reach, "abcde")
		for index in 5: reach._advance_effects(0.081)
		_check(_four_impacts(events, &"storm_arc").size() == (2 if points in [31, 61] else 1), "%d candidate shock selects its own ordinary, enlarged or arena-wide reach" % points)
	var blast := _four_session(&"storm")
	for index in 2:
		_word(blast, "abcde")
		for phase in 4: blast._advance_effects(0.081)
	blast.enemies[0].shock = 0
	blast.enemies[1].shock = 0
	blast.enemies[1].position = blast.enemies[0].position + Vector2(80.0, 0.0) / BattleSession.ARENA_SIZE
	var blast_events := _four_events(blast)
	_word(blast, "abcde")
	var main := _four_impacts(blast_events, &"storm_arc")
	var bursts := _four_impacts(blast_events, &"storm_burst")
	_check(main.size() == 1 and bursts.size() == 1 and absf(float(bursts[0].damage_q) / main[0].damage_q - 0.3) < 0.002 and blast.effects.size() == 1, "third storm keeps full primary damage, one thirty-percent neighbor burst and one continuation")
	blast.runtime.add_shock(blast.enemies[0], 999)
	_check(blast.enemies[0].shock == 127, "shock points saturate at 127")


func _four_defenses() -> void:
	for book in BuildCompiler.BOOKS:
		var session := _four_session(book)
		var events := _four_events(session)
		var origin := session.player_position
		session.enemies[0].position = origin + Vector2(120.0, 0.0) / BattleSession.ARENA_SIZE
		session.enemies[0].previous_position = session.enemies[0].position
		var hp := session.enemies[0].hp_q
		session.queue_action(&"dodge_right")
		session.step(0.0)
		_check(is_equal_approx(session.dodge_charges, 1.0), "%s formal dodge spends one charge" % book)
		if book == &"storm":
			_check(_four_impacts(events, &"storm_dodge").size() == 1 and session.enemies[0].hp_q == hp - 18 * 1024 and session.enemies[0].shock == 30, "storm dodge applies its path hit once")
		else:
			var kind: StringName = {&"spirit": &"paper_crane", &"flame": &"fire_field", &"frost": &"ice_mist"}[book]
			_check(session.runtime.fields.size() == 1 and session.runtime.fields[0].effect.kind == kind and session.runtime.fields[0].center == origin, "%s dodge leaves exactly its native field at the origin" % book)
			if book == &"spirit":
				var bullet := BattleThreat.new()
				bullet.source_id = session.enemies[0].id
				bullet.previous_position = origin - Vector2(40.0, 0.0) / BattleSession.ARENA_SIZE
				bullet.position = origin + Vector2(40.0, 0.0) / BattleSession.ARENA_SIZE
				_check(session.runtime.intercept_crane(bullet) and not session.runtime.intercept_crane(bullet) and session.runtime.fields.is_empty(), "one paper crane intercepts and retires exactly once")
				_check(session.enemies[0].hp_q == hp - 24 * 1024, "paper crane counterdamage belongs to the native effect")
			elif book == &"frost":
				session.runtime.advance(0.2)
				_check(session.enemies[0].cold == 0, "ice mist does not add cold outside its actual radius")
				session.enemies[0].position = origin + Vector2(70.0, 0.0) / BattleSession.ARENA_SIZE
				session.enemies[0].cold = 10
				session.runtime.advance(0.5)
				_check(session.enemies[0].cold == 19, "ice mist adds thirty cold per second while natural cold decay continues")
				session.player_position = origin - Vector2(100.0, 0.0) / BattleSession.ARENA_SIZE
				_check(session.runtime.obscures(session.enemies[0]), "ice mist hides a line of sight longer than ninety pixels")
				session.player_position = session.enemies[0].position - Vector2(89.0, 0.0) / BattleSession.ARENA_SIZE
				_check(not session.runtime.obscures(session.enemies[0]), "ice mist preserves point-blank vision within ninety pixels")
		var ultimate := _four_session(book)
		ultimate.enemies[0].position = ultimate.player_position + Vector2(80.0, 0.0) / BattleSession.ARENA_SIZE
		ultimate.enemies[0].previous_position = ultimate.enemies[0].position
		ultimate.enemies[1].position = Vector2(0.90, 0.20)
		ultimate.enemies[1].previous_position = ultimate.enemies[1].position
		var distant_hp := ultimate.enemies[1].hp_q
		for distance in [640.0, 660.0]:
			var bullet := BattleThreat.new()
			bullet.position = ultimate.player_position + Vector2(distance, 0.0) / BattleSession.ARENA_SIZE
			bullet.previous_position = bullet.position
			ultimate.threats.append(bullet)
		ultimate.resonance_q = BattleSession.ULTIMATE_COST_Q
		ultimate.queue_action(&"ultimate")
		ultimate.step(0.0)
		_check(ultimate.threats.size() == 1 and ((ultimate.threats[0].position - ultimate.player_position) * BattleSession.ARENA_SIZE).length() > 650.0, "%s ultimate clears bullets through the 650-pixel boundary" % book)
		_check(ultimate.enemies[0].impulse.length() > 0.0, "%s ultimate pushes a nearby enemy" % book)
		if book != &"flame": _check(ultimate.enemies[1].impulse == Vector2.ZERO, "%s ultimate does not push outside its domain" % book)
		var duration: float = {&"spirit": 8.0, &"flame": 5.0, &"frost": 4.0, &"storm": 6.0}[book]
		_check(is_equal_approx(ultimate.ultimate_time, duration) and ultimate.resonance_q == 0, "%s ultimate spends its charge and starts the finite native duration" % book)
		match book:
			&"spirit": _check(ultimate.spirits.size() == 4 and is_equal_approx(ultimate.spirit_time, 8.0), "paper ultimate can start a full formation from zero spirits")
			&"flame": _check(ultimate.enemies[1].hp_q == distant_hp - 60 * 1024, "flame ultimate initial wave reaches enemies outside its local domain")
			&"frost":
				_check(ultimate.run_state.shield_q == 20 * 1024, "ice ultimate grants its immediate twenty-point shield")
				ultimate._advance_ultimates(0.13)
				_check(ultimate.effects.size() == 1 and ultimate.effects[0].kind == &"frost_ultimate" and ((ultimate.effects[0].origin - ultimate.enemies[0].position) * BattleSession.ARENA_SIZE).length() > 200.0, "ice domain schedules a targeted spear from a separate angle")
			&"storm":
				_four_target(ultimate, 2, ultimate.enemies[0].position + Vector2(80.0, 0.0) / BattleSession.ARENA_SIZE)
				var ultimate_events := _four_events(ultimate)
				_word(ultimate, "abcde")
				_check(_four_impacts(ultimate_events, &"storm_arc").size() == 1 and ultimate.effects.size() == 1 and _four_impacts(ultimate_events, &"storm_ultimate_word").is_empty(), "storm ultimate completion emits one primary explosion chain")
				_check(ultimate.resonance_q == 0, "storm ultimate words cannot replenish the running ultimate")
