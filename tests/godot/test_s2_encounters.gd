extends SceneTree

var failures := 0


class CalibrationBattle:
	extends BattleSession

	func _advance_encounter(_delta: float) -> void:
		pass # The calibration driver owns the explicit finite wave schedule.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--four-books-balance" in OS.get_cmdline_user_args():
		_run_four_books_balance()
		return
	if "--god" in OS.get_cmdline_user_args():
		_check_god_mode()
		print("God battle rules: %s failure(s)" % failures)
		quit(1 if failures else 0)
		return
	if "--arrival" in OS.get_cmdline_user_args():
		_check_arrival_ranges()
		print("Arrival ranges: %s failure(s)" % failures)
		quit(1 if failures else 0)
		return
	if "--word-cost" in OS.get_cmdline_user_args():
		_run_word_cost()
		return
	if "--defense" in OS.get_cmdline_user_args():
		_run_defense()
		return
	if "--tail" in OS.get_cmdline_user_args():
		_run_tail()
		return
	var itinerary: RunItinerary = load("res://game/content/s2_itinerary.tres")
	_check_god_mode()
	_check_arrival_ranges()
	_check(itinerary.encounters.size() == 9, "nine distinct room resources")
	var kinds: Dictionary = {}
	for room in itinerary.encounters:
		for definition in room.enemies: kinds[definition.kind] = true
		if room.reinforcement != null: kinds[room.reinforcement.kind] = true
	kinds[&"tower"] = true
	_check(kinds.size() == 20, "seventeen ordinary kinds and three Bosses are referenced")
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("abcdef", "测试"), VocabularyEntry.new("ghijkl", "测试"), VocabularyEntry.new("mnopqr", "测试"), VocabularyEntry.new("stuvwx", "测试")]
	var battle := BattleSession.new()
	battle.encounter = itinerary.encounters[8]
	battle.start_baseline(&"storm", words, "normal", "s2", false)
	var boss := battle.enemies[0]
	_check(boss.max_hp_q == roundi(1050 * 1.7 * 1.7 * battle.Q), "physical chapter scales Boss health without reward chapter")
	battle.commit_damage(boss, 99999 * battle.Q, 99999 * battle.Q, &"test", battle.player_position)
	_check(boss.hp_q == roundi(boss.max_hp_q * 0.665) and is_equal_approx(boss.phase_lock, 0.55), "large hits cannot skip phase one")
	battle._advance_enemies(0.01)
	_check(boss.phase == 2, "committed phase floor transitions to phase two")
	boss.hp_q = roundi(boss.max_hp_q * 0.3)
	boss.phase_lock = 0.0
	battle._advance_enemies(0.01)
	var towers := battle._living().filter(func(enemy: BattleEnemy) -> bool: return enemy.kind == &"tower")
	_check(towers.size() == 2 and boss.shielded, "final Boss summons two real shield sources")
	var previous := boss.hp_q
	battle.commit_damage(boss, 100 * battle.Q, 100 * battle.Q, &"test", battle.player_position)
	_check(previous - boss.hp_q == 45 * battle.Q, "living pillars reduce Boss damage by 55 percent")
	for tower in towers: battle.commit_damage(tower, 1000 * battle.Q, 1000 * battle.Q, &"test", battle.player_position)
	previous = boss.hp_q
	battle.commit_damage(boss, 100 * battle.Q, 100 * battle.Q, &"test", battle.player_position)
	_check(previous - boss.hp_q == 100 * battle.Q, "killing pillars removes mitigation immediately")
	var mirror := battle._spawn_enemy(load("res://game/content/enemies/mirror.tres"), Vector2(0.6, 0.5))
	previous = mirror.hp_q
	battle.commit_damage(mirror, 10 * battle.Q, 10 * battle.Q, &"test", battle.player_position, false, Vector2.INF, true)
	_check(previous - mirror.hp_q == roundi(5.5 * battle.Q) and not mirror.mirror_ready, "mirror consumes its direct-hit shield")
	mirror.mirror_ready = true
	mirror.frozen_time = 1.0
	previous = mirror.hp_q
	battle.commit_damage(mirror, 10 * battle.Q, 10 * battle.Q, &"test", battle.player_position, false, Vector2.INF, true)
	_check(previous - mirror.hp_q == 10 * battle.Q and mirror.mirror_ready, "freezing bypasses mirror")
	var brood := battle._spawn_enemy(load("res://game/content/enemies/brood.tres"), Vector2(0.65, 0.5))
	for attack in 8: battle._resolve_attack(brood)
	_check(brood.spawn_count == 5, "brood spawning is finite")
	var split := battle._spawn_enemy(load("res://game/content/enemies/split.tres"), Vector2(0.6, 0.6))
	var count := battle.enemies.size()
	battle.commit_damage(split, 1000 * battle.Q, 1000 * battle.Q, &"test", battle.player_position)
	_check(battle.enemies.size() == count + 2 and battle.enemies[-1].small, "split death creates two separate small word targets")
	var scribe := battle._spawn_enemy(load("res://game/content/enemies/scribe.tres"), Vector2(0.7, 0.6))
	battle.hazards.clear()
	battle._spawn_laser(scribe)
	_check(battle.hazards[0].contains(battle.player_position) and battle.hazards[0].warning_remaining > 0.0, "laser warning geometry matches its future contact")
	battle.commit_damage(scribe, 1000 * battle.Q, 1000 * battle.Q, &"test", battle.player_position)
	battle._advance_hazards(0.01)
	_check(battle.hazards.is_empty(), "source death cancels warned hazards")
	battle.pickups.clear()
	battle.threats.clear()
	var pickup := battle.spawn_pickup(&"rune")
	var manual := battle.manual_characters
	var complete := battle.completed_words
	battle.typing.select_target(pickup.id)
	for character in pickup.word: battle.typing.feed(character)
	battle.hurt_window = 10.0
	battle.step(1.0 / 60.0)
	_check(pickup.consumed and battle.manual_characters - manual == pickup.word.length() and battle.completed_words == complete, "pickup words count physical input exactly once and do not cast the main book")
	battle.hazards.clear()
	var laser := BattleHazard.new()
	laser.kind = &"laser"
	laser.origin = Vector2(battle.player_position.x, 0.0)
	laser.end = Vector2(battle.player_position.x, 1.0)
	laser.width = 30.0
	battle.hazards.append(laser)
	var blast := BattleHazard.new()
	blast.kind = &"blast"
	blast.center = battle.player_position + Vector2.LEFT * 240.0 / BattleSession.ARENA_SIZE
	blast.radius = 180.0
	battle.hazards.append(blast)
	var safe := BattleSession.clamp_player(battle.player_position + battle._safe_direction() * 240.0 / BattleSession.ARENA_SIZE)
	_check(not laser.contains(safe) and not blast.contains(safe), "Alt chooses a safe point using the same laser/blast/player geometry as contact")
	battle.free()
	print("S2 encounters: %s failure(s)" % failures)
	quit(1 if failures else 0)


func _check_god_mode() -> void:
	for book in [&"frost", &"storm", &"spirit", &"flame"]:
		var selection := BuildSelection.new()
		selection.book_id = book
		var request := BattleStartRequest.new()
		request.build = BuildCompiler.new().compile(selection).build
		request.vocabulary = [VocabularyEntry.new("archive", "档案")]
		request.vocabulary_index = VocabularyIndex.build(request.vocabulary)
		request.encounter = load("res://game/content/encounters/final_editor.tres")
		request.seed_text = "god-rule-fixture"
		var battle := BattleSession.new()
		battle.start(request)
		_check(not battle.god_mode, "God is disabled by default")
		battle.dodge_charges = 0.0
		battle.resonance_q = 0
		var idle_dodge_time := battle._dodge_time
		var idle_position := battle.player_position
		battle._commit_action(&"dodge_left")
		battle._commit_action(&"ultimate")
		_check(battle._dodge_time == idle_dodge_time and battle.player_position == idle_position and battle.ultimates.is_empty(), "ordinary defense and ultimate still require resources")
		battle.activate_god_mode()
		_check(battle.god_mode and battle.resonance_q == BattleSession.ULTIMATE_COST_Q and battle.dodge_charges >= 2.0, "explicit paused-battle activation fills only action resources")
		var hp := battle.player_hp_q
		battle._take_player_damage(5 * battle.Q, "god-nonlethal")
		_check(battle.player_hp_q == hp - 5 * battle.Q, "God still takes ordinary damage")
		battle._take_player_damage(battle.player_max_hp_q * 2, "god-lethal")
		_check(battle.player_hp_q == battle.player_max_hp_q and battle.result == 0, "God restores lethal damage to maximum HP")
		battle.dodge_charges = 0.0
		battle._commit_action(&"dodge_left")
		_check(battle._dodge_time == 0.0 and battle.dodge_charges >= 2.0, "God bypasses dodge charge without skipping its real motion")
		var destination := battle._dodge_to
		battle._commit_action(&"dodge_right")
		_check(battle._dodge_to == destination, "God cannot interrupt a dodge already in flight")
		battle.step(0.17)
		_check(battle.player_position == destination and battle._dodge_time == 0.17, "God dodge reaches its normal committed landing")
		battle.resonance_q = 0
		battle._commit_action(&"ultimate")
		battle._commit_action(&"ultimate")
		_check(battle.ultimates.size() == 2 and battle.resonance_q == BattleSession.ULTIMATE_COST_Q, "God permits repeated real ultimates even while one is active")
		for tick in 3600:
			battle._advance_ultimates(1.0 / 60.0)
			_word_cost_tick(battle)
		_check(battle.ultimates.is_empty() and _word_cost_active(battle) == 0, "repeated God ultimates keep finite native effects")
		request.god_mode = true
		battle.start(request)
		_check(battle.god_mode and battle.resonance_q == BattleSession.ULTIMATE_COST_Q, "new battle honors the explicit request")
		request.god_mode = false
		battle.start(request)
		_check(not battle.god_mode, "new ordinary request does not inherit a prior battle's God flag")
		battle.free()


func _check_arrival_ranges() -> void:
	var battle := BattleSession.new()
	battle.encounter = load("res://game/content/encounters/lost_library_1.tres")
	battle._rng.seed = 8512
	for direction_index in BattleEncounter.DIRECTIONS.size():
		var direction: String = BattleEncounter.DIRECTIONS[direction_index]
		var center_angle := direction_index * PI / 4.0 - PI / 2.0
		var minimum_angle := INF
		var maximum_angle := -INF
		for sample in 64:
			var at := battle._arrival_position(direction)
			var point := at * BattleSession.ARENA_SIZE
			var offset := point - BattleSession.ARENA_SIZE * 0.5
			var angle := wrapf(offset.angle() - center_angle, -PI, PI)
			minimum_angle = minf(minimum_angle, angle)
			maximum_angle = maxf(maximum_angle, angle)
			_check(absf(angle) <= deg_to_rad(55.0) + 0.0001, "arrival stays in its advertised direction area")
			var edge_distance := minf(minf(point.x, point.y), minf(BattleSession.ARENA_SIZE.x - point.x, BattleSession.ARENA_SIZE.y - point.y))
			_check(is_equal_approx(edge_distance, 64.0) and not BattleSession.in_combat(at, 16.0), "arrival remains in the cold boundary before word selection")
		_check(maximum_angle - minimum_angle > deg_to_rad(80.0), "each direction has a broad sampled spatial distribution")
	battle.free()
	# Exercise the real single-enemy paced spawner, where index/count used to
	# repeat the exact same centerline every batch.
	battle = BattleSession.new()
	battle.encounter = load("res://game/content/encounters/lost_library_1.tres")
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("archive", "档案")]
	battle.start_baseline(&"storm", words, "normal", "arrival-spawner", false)
	var positions: Array[Vector2] = []
	var before := battle.enemies.size()
	var expected_batches := mini(7, mini(ceili(float(battle._room_quota * battle.wave) / battle.encounter.wave_count) - battle._spawned, battle._enemy_cap - battle._living().size()))
	for batch in 7:
		battle._spawn_clock = 0.0
		battle._advance_encounter(0.0)
		if battle.enemies.size() > before:
			positions.append(battle.enemies[-1].position)
			before = battle.enemies.size()
	_check(positions.size() == expected_batches and expected_batches >= 2, "real first-wave single-enemy batches enter the sample within their live cap")
	for index in range(1, positions.size()):
		_check(positions[index].distance_to(positions[index - 1]) > 0.0001, "successive single-enemy batches use distinct arrival points")
	var entering := battle.enemies[-1]
	_check(not battle.typing._targets.has(entering.id), "cold arrival has no selectable word")
	for tick in 1800:
		battle._advance_enemy_motion(1.0 / 60.0)
		if BattleSession.enemy_in_combat(entering): break
	_check(BattleSession.enemy_in_combat(entering), "distributed arrival still approaches into the clear arena")
	battle._advance_enemies(0.0)
	_check(battle.typing._targets.has(entering.id), "word becomes selectable after normal entry")
	battle.free()


func _run_word_cost() -> void:
	var reports: Array[Dictionary] = []
	for book in [&"frost", &"storm", &"spirit", &"flame"]:
		for word_text in ["ash", "archive"]:
			var selection := BuildSelection.new()
			selection.book_id = book
			var request := BattleStartRequest.new()
			request.build = BuildCompiler.new().compile(selection).build
			request.vocabulary = [VocabularyEntry.new(word_text, "度量")]
			request.vocabulary_index = VocabularyIndex.build(request.vocabulary)
			request.encounter = load("res://game/content/encounters/final_editor.tres")
			request.difficulty = "apocalypse" # The actual third-chapter Boss survives six casts above its first phase floor.
			request.seed_text = "word-cost-fixed"
			request.progressive = false
			var battle := BattleSession.new()
			battle.start(request, RunCombatState.new())
			battle.step(0.0) # Register the real spawn target without moving it or advancing enemy AI.
			var target := battle.enemies[0]
			var distance := ((target.position - battle.player_position) * BattleSession.ARENA_SIZE).length()
			var waits: Array[float] = []
			var total_wait := 0.0
			for cast_index in 6:
				_check(target.alive() and battle.typing._targets.has(target.id), "word-cost target stays available before cast")
				battle.typing.select_target(target.id)
				for character in target.word: battle.typing.feed(character)
				battle.step(0.0) # Normal receipt/word commit; instantaneous input is explicitly a cost fixture.
				var waited := 0.0
				for tick in 180:
					if not target.word_pending and battle.typing._targets.has(target.id): break
					_word_cost_tick(battle)
					waited += 1.0 / 60.0
				_check(not target.word_pending and battle.typing._targets.has(target.id), "primary renews its word within three seconds")
				waits.append(waited)
				total_wait += waited
			var settle_seconds := 0.0
			for tick in 3600:
				if _word_cost_active(battle) == 0: break
				_word_cost_tick(battle)
				settle_seconds += 1.0 / 60.0
			_check(_word_cost_active(battle) == 0, "word-cost derived lifecycle retires")
			_check(battle.manual_characters == word_text.length() * 6 and battle.runtime.book_cast_count() == 6, "word-cost records exactly six physical words")
			var report := {"book": str(book), "word": word_text, "characters": battle.manual_characters, "casts": battle.runtime.book_cast_count(), "boss_distance_px": distance, "boss_remaining_hp": float(target.hp_q) / 1024, "submitted_damage": float(battle.runtime.actual_damage_q) / 1024, "unapplied_damage": float(battle.runtime.overkill_damage_q) / 1024, "raw_spent_q": battle.ledger.raw_spent_q, "word_pending_seconds": waits, "total_primary_wait_seconds": total_wait, "derived_end_after_last_primary_seconds": settle_seconds, "derived_end_after_last_word_seconds": waits[-1] + settle_seconds, "active_at_end": _word_cost_active(battle)}
			reports.append(report)
			print("WORD COST ", JSON.stringify(report))
			battle.free()
	var path := "res://.temp/shrink/encounters/word-cost-%s.json" % Time.get_ticks_usec()
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"model": "Four books x fixed ash/archive vocabulary, no relics, identical stationary original Boss/player coordinates and actual apocalypse Boss HP. Six normal physical receipt commits at instantaneous input; only real spell/status/blade paths advance at60Hz while enemy AI, defenses, pickups and rewards are excluded. Includes native empowerment. Submitted damage is actual HP loss; unapplied damage includes mitigated/floored/overkill packet remainder, not exclusively target death overflow. Wait excludes human typing time. Derived end is measured after the sixth word and after its primary renewal. Rule cost isolation, not real victory or skill/balance evidence.", "reports": reports, "failures": failures}, "\t"))
	output.close()
	print("Word-cost evidence: ", path)
	quit(1 if failures else 0)


func _word_cost_tick(battle: BattleSession) -> void:
	battle.runtime.advance(1.0 / 60.0)
	battle._advance_effects(1.0 / 60.0)
	# A fixed-position target fixture still expires native freeze/mark/phase timers.
	var fixed_positions: Array[Vector2] = []
	for enemy in battle.enemies: fixed_positions.append(enemy.position)
	battle._advance_enemy_motion(1.0 / 60.0)
	for index in battle.enemies.size():
		battle.enemies[index].position = fixed_positions[index]
		battle.enemies[index].previous_position = fixed_positions[index]
	battle._advance_projectiles(1.0 / 60.0)
	battle._advance_blades(1.0 / 60.0)


func _word_cost_active(battle: BattleSession) -> int:
	return battle.effects.size() + battle.projectiles.size() + battle.spirits.size() + battle.runtime.ongoing.size() + battle.runtime.fields.size() + battle.runtime.spirit_attacks.size()


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run_defense() -> void:
	var reports: Array[Dictionary] = []
	var compiler := BuildCompiler.new()
	var transaction := RunTransactionService.new(compiler)
	var itinerary: RunItinerary = load("res://game/content/s2_itinerary.tres")
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("archive", "档案"), VocabularyEntry.new("frost", "霜"), VocabularyEntry.new("ash", "灰")]
	for book in [&"frost", &"storm", &"spirit", &"flame"]:
		for counter_relics in [false, true]:
			var selection := BuildSelection.new()
			selection.book_id = book
			selection.base_hp = 125
			var state := RunCombatState.new()
			state.hp_q = 125 * 1024
			if counter_relics:
				for id in [&"R057", &"R058"]:
					var acquired := transaction.prepare_acquisition(selection, state, id, "defense-prior:%s:%s" % [book, id], "", {"shortest": 3, "longest": 7})
					_check(acquired.diagnostics.is_empty(), "prior counter relic uses the actual acquisition contract")
					selection = acquired.selection
					state = acquired.state
			var compiled := compiler.compile(selection)
			_check(compiled.success(), "defense fixture compiles")
			for serial in itinerary.encounters.size():
				var request := BattleStartRequest.new()
				request.build = compiled.build
				request.vocabulary = words
				request.vocabulary_index = VocabularyIndex.build(words)
				request.encounter = itinerary.encounters[serial]
				request.difficulty = "normal"
				request.seed_text = "defense-boundary-1"
				request.progressive = false
				request.room_serial = serial + 1
				var battle := BattleSession.new()
				battle.start(request, state)
				for tick in 36000:
					_defense_only(battle)
					battle.step(1.0 / 60.0)
					if battle.result != 0: break
				_check(battle.manual_characters == 0 and battle.completed_words == 0, "defense model never feeds or assists a word")
				var report := {"book": str(book), "counter_relics": counter_relics, "room": serial + 1, "result": battle.result, "seconds": battle.elapsed, "hp": float(battle.player_hp_q) / 1024, "characters": battle.manual_characters, "remaining": battle._living().size(), "damage": float(battle.runtime.actual_damage_q) / 1024}
				reports.append(report)
				print("DEFENSE BOUNDARY ", JSON.stringify(report))
				var victory := battle.result == 1
				battle.free()
				if not victory: break
	var path := "res://.temp/shrink/encounters/defense-%s.json" % Time.get_ticks_usec()
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"model": "60Hz, geometry-informed parry/Alt only; no Unicode, Ctrl, ultimate, injected HP/position/invulnerability/damage. Counter relics are explicit prior-acquisition contract fixtures, not claims of random reward earnings. Fixed seed and one normal-mode sample; no rest healing or new rewards between rooms.", "reports": reports, "failures": failures}, "\t"))
	output.close()
	print("Defense evidence: ", path)
	quit(1 if failures else 0)


func _defense_only(battle: BattleSession) -> void:
	if battle.dodge_window > 0.0 or battle.parry_window > 0.0: return
	for hazard in battle.hazards:
		if hazard.contains(battle.player_position) and hazard.warning_remaining < 0.18 and battle.dodge_charges >= 1.0:
			battle.queue_action(&"dodge_auto")
			return
	var imminent := false
	var player := battle.player_position * BattleSession.ARENA_SIZE
	for threat in battle.threats:
		if threat.reflected: continue
		var origin := threat.position * BattleSession.ARENA_SIZE
		var nearest := Geometry2D.get_closest_point_to_segment(player, origin, origin + threat.velocity * 0.12)
		if nearest.distance_to(player) < 54.0 + threat.radius: imminent = true
	for enemy in battle._living():
		if enemy.behavior == &"melee" and enemy.aiming and enemy.attack_clock < 0.2:
			imminent = imminent or CombatGeometry.disc_in_sector(player - enemy.melee_origin * BattleSession.ARENA_SIZE, 21.0, enemy.melee_direction, BattleEnemy.MELEE_REACH, BattleEnemy.MELEE_HALF_ANGLE)
		if enemy.charge_time > 0.0:
			imminent = imminent or CombatGeometry.sweep_discs(enemy.position * BattleSession.ARENA_SIZE, enemy.position * BattleSession.ARENA_SIZE + enemy.charge_direction * enemy.charge_speed * 0.12, player, player, enemy.radius + 54.0) != INF
	if imminent:
		if battle.parry_cooldown <= 0.0: battle.queue_action(&"parry")
		elif battle.dodge_charges >= 1.0: battle.queue_action(&"dodge_auto")


func _run_four_books_balance() -> void:
	var reports: Array[Dictionary] = []
	var compiler := BuildCompiler.new()
	var transaction := RunTransactionService.new(compiler)
	for book in [&"spirit", &"flame", &"frost", &"storm"]:
		for scenario in ["short", "sustain", "sparse", "dense", "boss", "reinforcements", "tailored"]:
			for input in [{"cps": 3.0, "word": "lumen"}, {"cps": 6.0, "word": "lumen"}, {"cps": 6.0, "word": "ash"}, {"cps": 6.0, "word": "archive"}]:
				var selection := BuildSelection.new()
				selection.book_id = book
				var state := RunCombatState.new()
				if scenario == "tailored":
					var relics: Array = {&"spirit": [&"R005", &"R035", &"R048"], &"flame": [&"R050", &"R051", &"R052"], &"frost": [&"R004", &"R032", &"R044"], &"storm": [&"R002", &"R033", &"R046"]}[book]
					for relic: StringName in relics:
						var acquired := transaction.prepare_acquisition(selection, state, relic, "four-books:" + str(relic), "", {"shortest": 3, "longest": 7})
						_check(acquired.diagnostics.is_empty(), "tailored fixture uses actual acquisition prerequisites")
						selection = acquired.selection
						state = acquired.state
				var request := BattleStartRequest.new()
				request.build = compiler.compile(selection).build
				request.vocabulary = [VocabularyEntry.new(input.word, "校准")]
				request.vocabulary_index = VocabularyIndex.build(request.vocabulary)
				request.difficulty = "normal"
				request.seed_text = "four-books-1"
				request.progressive = false
				var battle := CalibrationBattle.new()
				battle.start(request, state)
				# Explicit controlled geometry. Spawn pressure, loot and enemy attacks are
				# excluded here; the separate formal run covers those real interactions.
				battle.enemies.clear()
				battle._enemies_by_id.clear()
				battle.typing.set_targets({})
				battle._enemy_definitions.clear()
				battle._room_quota = 999
				battle._spawn_clock = 9999.0
				battle._pickup_clock = 9999.0
				var boss_scene: bool = scenario in ["boss", "reinforcements"]
				var count := 1 if boss_scene else (2 if scenario == "sparse" else 6)
				for index in count:
					_balance_enemy(battle, index, scenario, boss_scene and index == 0)
				var samples := {"cold6": 0.0, "damage18": 0.0, "hits": 0, "pierces": 0, "chains": 0, "saturation": 0}
				battle.event_committed.connect(func(event: Dictionary) -> void:
					if event.kind == &"impact":
						samples.hits += 1
						if event.source == &"frost_spear": samples.pierces += 1
						if event.source == &"storm_arc": samples.chains += 1
				)
				var duration := 6.0 if scenario == "short" else 30.0
				var next_letter := 0.0
				var casts := 0
				for tick in roundi(duration * 60):
					if scenario in ["sustain", "reinforcements"] and tick > 0 and tick % 180 == 0:
						_balance_enemy(battle, battle.enemies.size(), scenario, false)
					if tick / 60.0 >= next_letter:
						next_letter += 1.0 / float(input.cps)
						if battle.typing.target_id == &"":
							var targets := battle._living().filter(func(enemy: BattleEnemy) -> bool: return not enemy.word_pending)
							if book == &"flame": targets.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool: return a.burn < b.burn)
							if not targets.is_empty(): battle.typing.select_target(targets[0].id)
						if battle.typing.target_id != &"":
							battle.typing.feed(battle.typing.word[battle.typing.progress])
					battle.step(1.0 / 60.0)
					casts = battle.runtime.book_cast_count()
					if tick == 359: samples.cold6 = battle.runtime.actual_damage_q / 1024.0
					if tick == 1079: samples.damage18 = battle.runtime.actual_damage_q / 1024.0
					for enemy in battle._living():
						if enemy.burn == 127 or enemy.shock == 127 or enemy.vulnerability == 127: samples.saturation += 1
					if battle._living().is_empty() and scenario not in ["sustain", "reinforcements"]: break
				if battle.elapsed < 6.0: samples.cold6 = battle.runtime.actual_damage_q / 1024.0
				var report := {"book": str(book), "scenario": scenario, "cps": input.cps, "word_length": str(input.word).length(), "seconds": battle.elapsed, "casts": casts, "characters": battle.manual_characters, "damage": battle.runtime.actual_damage_q / 1024.0, "overkill": battle.runtime.overkill_damage_q / 1024.0, "killed": battle.enemies.size() - battle._living().size(), "spawned": battle.enemies.size(), "freezes": battle.runtime.freezes, "sources": battle.runtime.damage_by_source, "samples": samples}
				reports.append(report)
				battle.free()
	var directory := "res://.temp/four-books-20261009"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory.path_join("balance-%s.json" % Time.get_ticks_usec())
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"scope": "60Hz controlled finite targets, seed four-books-1, 100% correct TypingSession input, 3/6 cps and 3/5/7 letters; 100HP ordinary references and 5000HP durable single-body reference using enemy resistances, explicit positions, AI movement/attacks disabled, knockback retained. Boss label means isolated durable body with phase/reinforcements disabled; formal runs separately cover actual Bosses. No pickups, ultimate or defense; reinforcement scenario adds one ordinary reference every 3 seconds. Tailored relics use acquisition contract fixtures, not earned rewards. Not human play or full-run balance.", "reports": reports, "failures": failures}, "\t"))
	print("Four-book calibration: ", reports.size(), " cases, ", failures, " failures; ", path)
	quit(1 if failures else 0)


func _balance_enemy(battle: BattleSession, index: int, scenario: String, boss: bool) -> void:
	var angle := index * 2.399
	var radius := 360.0 if scenario == "sparse" else 100.0
	var at := Vector2(.66, .48) + Vector2.from_angle(angle) * radius / BattleSession.ARENA_SIZE
	var enemy := battle._spawn_enemy(load("res://game/content/enemies/ink_colossus.tres" if boss else "res://game/content/enemies/nib.tres"), at)
	# Explicit reference HP permits equal finite-target comparisons across schools.
	if boss:
		enemy.max_hp_q = 5000 * BattleSession.Q
		enemy.hp_q = enemy.max_hp_q
		enemy.boss = false # isolate single-body output from phase-triggered reinforcements
		enemy.radius = 42.0
	else:
		enemy.max_hp_q = 100 * BattleSession.Q
		enemy.hp_q = enemy.max_hp_q
	enemy.speed = 0.0
	enemy.stationary = true
	enemy.attack_clock = 9999.0
	enemy.word_pending = false
	enemy.combat_locked = true
	battle.typing.upsert_target(enemy.id, enemy.word)


func _run_tail() -> void:
	var compiler := BuildCompiler.new()
	var transaction := RunTransactionService.new(compiler)
	var reports: Array[Dictionary] = []
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("archive", "档案"), VocabularyEntry.new("frost", "霜"), VocabularyEntry.new("ash", "灰")]
	for book in [&"frost", &"storm", &"spirit", &"flame"]:
		var selection := BuildSelection.new()
		selection.book_id = book
		var state := RunCombatState.new()
		for id in [&"R006", &"R007", &"R028"]:
			var acquired := transaction.prepare_acquisition(selection, state, id, "tail-prior:%s:%s" % [book, id], "", {"shortest": 3, "longest": 7})
			_check(acquired.diagnostics.is_empty(), "tail fixture uses actual acquisition eligibility")
			selection = acquired.selection
			state = acquired.state
		var request := BattleStartRequest.new()
		request.build = compiler.compile(selection).build
		request.vocabulary = words
		request.vocabulary_index = VocabularyIndex.build(words)
		request.encounter = load("res://game/content/encounters/ink_colossus.tres")
		request.seed_text = "tail-boundary"
		request.progressive = false
		var battle := BattleSession.new()
		battle.start(request, state)
		battle.step(1.0 / 60.0)
		var pending_samples: Array[Dictionary] = []
		for word in 6:
			var target := battle.enemies[0]
			if not target.alive(): break
			var cast_distance := ((target.position - battle.player_position) * BattleSession.ARENA_SIZE).length()
			battle.typing.select_target(target.id)
			for character in target.word: battle.typing.feed(character)
			battle.step(1.0 / 60.0)
			var released_after := -1.0
			if not target.word_pending and battle.typing._targets.has(target.id): released_after = 1.0 / 60.0
			# Commit actual flights / renewal between words, before input stops.
			for tick in 120:
				battle.runtime.advance(1.0 / 60.0)
				battle._advance_effects(1.0 / 60.0)
				battle._advance_projectiles(1.0 / 60.0)
				battle._advance_blades(1.0 / 60.0)
				if released_after < 0.0 and not target.word_pending and battle.typing._targets.has(target.id):
					released_after = (tick + 2) / 60.0
			pending_samples.append({"cast": word + 1, "distance_px": cast_distance, "next_word_seconds": released_after})
		var manual := battle.manual_characters
		var casts := battle.runtime.book_cast_count()
		var damage_at_40 := 0
		for tick in 3600:
			# Isolate finite spell lifecycle from unrelated new enemy attacks/defense.
			battle.runtime.advance(1.0 / 60.0)
			battle._advance_effects(1.0 / 60.0)
			battle._advance_projectiles(1.0 / 60.0)
			battle._advance_blades(1.0 / 60.0)
			if tick == 2399: damage_at_40 = battle.runtime.actual_damage_q
		var active := battle.effects.size() + battle.projectiles.size() + battle.spirits.size() + battle.runtime.ongoing.size() + battle.runtime.fields.size() + battle.runtime.spirit_attacks.size()
		_check(active == 0 and damage_at_40 == battle.runtime.actual_damage_q, "%s input-derived effects fully retire and stop damage" % book)
		_check(battle.manual_characters == manual and battle.runtime.book_cast_count() == casts, "%s derived effects never invent new input or casts" % book)
		var report := {"book": str(book), "characters": manual, "casts": casts, "active_at_60_seconds": active, "damage_at_40": damage_at_40, "damage_at_60": battle.runtime.actual_damage_q, "word_pending_samples": pending_samples}
		reports.append(report)
		print("TAIL BOUNDARY ", JSON.stringify(report))
		battle.free()
	var path := "res://.temp/shrink/encounters/tail-%s.json" % Time.get_ticks_usec()
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"model": "Actual Unicode receipts with prior acquisition fixtures R006/R007/R028, then 60 seconds of the same fixed-step spell flight/status/blade paths with no further input and no new enemy AI or defense attacks. No fabricated damage, HP, target death or result. Rule isolation only, not balance or human-play evidence.", "reports": reports, "failures": failures}, "\t"))
	output.close()
	print("Tail evidence: ", path)
	quit(1 if failures else 0)
