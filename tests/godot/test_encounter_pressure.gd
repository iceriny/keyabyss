extends SceneTree

var failures := 0
var checks := 0
const MODES := ["story", "normal", "hard", "nightmare", "apocalypse"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("abcdef", "测试"), VocabularyEntry.new("ghijkl", "测试")]
	if "--flight-boundaries" in OS.get_cmdline_user_args():
		_check_segment_boundary(words)
		_check_page_cleanup(words)
		_check_formal_page_handoff(words)
		_check_reentrant_clear(words)
		print("Flight boundaries: %s checks, %s failure(s)" % [checks, failures])
		quit(1 if failures else 0)
		return
	for rank in MODES.size():
		for chapter_number in [1, 2, 3]:
			var fan := BattleSession.new()
			fan.start_baseline(&"storm", words, MODES[rank], "center-lane", false)
			fan.chapter = chapter_number
			var caster := fan.enemies[0]
			caster.position = Vector2(0.5, 0.25)
			caster.aimed_position = fan.player_position
			fan._emit_pattern(caster, &"fan")
			_check(fan.threats.size() % 2 == 1 and fan.threats.size() != 4, "fan has an odd number of lanes in every mode/chapter")
			var center := fan.threats[floori(fan.threats.size() * 0.5)]
			_check(center.velocity.normalized().dot(((caster.aimed_position - caster.position) * fan.ARENA_SIZE).normalized()) > 0.9999, "fan center aims at the player")
			fan.free()
		var battle := BattleSession.new()
		battle.encounter = load("res://game/content/encounters/lost_library_1.tres")
		battle.start_baseline(&"storm", words, MODES[rank], "quota", false)
		var quota: int = [15, 19, 23, 27, 31][rank]
		_check(battle._room_quota == quota, "%s uses its finite first-room quota" % MODES[rank])
		_check(battle.enemies.size() == (1 if rank < 2 else mini(3, rank)), "%s starts with a small batch" % MODES[rank])
		_check(battle.enemies[0].max_hp_q == roundi(43 * [0.72, 0.9, 1.24, 1.42, 5.3][rank] * battle.Q), "%s ordinary health follows its own mode scale" % MODES[rank])
		var opening_cap := battle._enemy_cap
		battle._room_world_time = 120.0
		battle._advance_encounter(0.0)
		_check(battle._enemy_cap == opening_cap, "elapsed time alone cannot raise first-segment concurrency")
		battle._room_world_time = 0.0
		var phases: Dictionary = {}
		var peak := 0
		for tick in 24000:
			battle.hurt_window = 10.0 # Rule isolation; this does not establish difficulty balance.
			battle.step(1.0 / 60.0)
			phases[battle.wave] = true
			peak = maxi(peak, battle._living().size())
			_check(battle._living().size() <= battle._enemy_cap, "spawn batches obey the real alive cap")
			for enemy in battle._living():
				if BattleSession.enemy_in_combat(enemy): battle.commit_damage(enemy, 10000 * battle.Q, 10000 * battle.Q, &"fixture", battle.player_position)
			if battle.result != 0: break
		_check(battle.result == 1 and battle._spawned == quota and battle.enemies.size() == quota and phases.size() == 2, "%s clears exactly its quota through the actual fixed-step spawner and two segments" % MODES[rank])
		var opening_fact: RewardFact
		for fact: RewardFact in battle.reward_facts:
			if JSON.parse_string(fact.fact_id)[3] == "enemy_0":
				opening_fact = fact
				break
		_check(opening_fact != null and opening_fact.base_experience == 5, "restored room quotas retain the original kill income")
		print("%s quota=%s spawned=%s peak=%s elapsed=%.2f" % [MODES[rank], quota, battle._spawned, peak, battle.elapsed])
		battle.free()
	var boss_battle := BattleSession.new()
	boss_battle.encounter = load("res://game/content/encounters/ink_colossus.tres")
	boss_battle.start_baseline(&"storm", words, "normal", "pressure", false)
	var boss := boss_battle.enemies[0]
	boss_battle._emit_pattern(boss, &"ring")
	_check(is_equal_approx(boss_battle.threats[0].velocity.length(), 83 * 1.5 * 1.06), "Boss uses the shared predictable bullet speed")
	_check(is_equal_approx(boss.attack_interval, 3.2 * 1.19), "Boss uses the shared attack timing")
	var q := boss_battle.Q
	boss_battle._counter_contact(boss)
	_check(boss_battle.resonance_q == 3 * q, "successful parry gives three resonance once")
	boss_battle.free()
	_check_pace(words)
	_check_density()
	_check_segment_boundary(words)
	_check_page_cleanup(words)
	_check_formal_page_handoff(words)
	_check_reentrant_clear(words)
	print("Encounter pressure: %s checks, %s failure(s)" % [checks, failures])
	quit(1 if failures else 0)


func _check_pace(words: Array[VocabularyEntry]) -> void:
	var selection := BuildSelection.new()
	var build := BuildCompiler.new().compile(selection).build
	var reference: Array[float] = []
	for mode: String in MODES:
		for chapter_number in [1, 2, 3]:
			for loop_number in [0, 3]:
				var request := BattleStartRequest.new()
				request.build = build
				request.vocabulary = words
				request.vocabulary_index = VocabularyIndex.build(words)
				request.encounter = load("res://game/content/encounters/lost_library_1.tres").duplicate()
				request.encounter.chapter_number = chapter_number
				request.difficulty = mode
				request.loop_index = loop_number
				request.seed_text = "shared-pace"
				var battle := BattleSession.new()
				battle.start(request)
				var enemy := battle.enemies[0]
				enemy.position = Vector2(0.7, 0.5)
				enemy.combat_locked = true
				battle._advance_enemy_motion(0.1)
				var ram := battle._spawn_enemy(load("res://game/content/enemies/ram.tres"), Vector2(0.7, 0.5))
				ram.aimed_position = battle.player_position
				battle._resolve_attack(ram)
				battle._emit_pattern(enemy, &"single")
				var pace: Array[float] = [enemy.speed, enemy.velocity.length(), enemy.attack_interval, ram.charge_speed, ram.charge_time, ram.warning_time, battle.threats[0].velocity.length()]
				if reference.is_empty(): reference = pace
				for index in pace.size():
					_check(is_equal_approx(pace[index], reference[index]), "%s/chapter%s/loop%s retains motion and attack timing %s" % [mode, chapter_number, loop_number, index])
				battle.free()


func _check_density() -> void:
	var words: Array[VocabularyEntry] = []
	for word: String in ["archive", "bloom", "crystal", "dream", "ember", "frost", "garden", "hollow", "ink", "jade", "leaf", "mist", "night", "ocean", "paper", "quill", "root", "spell", "thorn", "veil", "wind"]:
		words.append(VocabularyEntry.new(word, "测试"))
	for rank in MODES.size():
		var battle := BattleSession.new()
		battle.encounter = load("res://game/content/encounters/final_court_2.tres")
		battle.start_baseline(&"storm", words, MODES[rank], "density", false)
		_check(battle._room_quota == [28, 32, 36, 40, 44][rank], "third chapter uses the shorter two-segment workload")
		var peak := 0
		var bullet_peak := 0
		for tick in 5400:
			battle.hurt_window = 10.0
			var spawned_before := battle._spawned
			battle.step(1.0 / 60.0)
			peak = maxi(peak, battle._living().size())
			bullet_peak = maxi(bullet_peak, battle.threats.size())
			_check(battle._living().size() <= [6, 8, 8, 10, 14][rank], "durable enemies and summoned children respect the late-room ceiling")
			_check(battle._spawned - spawned_before <= [1, 2, 3, 5, 5][rank], "replenishment keeps its original wave batch within the alive cap")
		_check(peak >= 4 and battle.result == 0, "density fixture exercises an uncleared live encounter")
		print("%s third-chapter idle: quota=%s peak=%s bullets=%s" % [MODES[rank], battle._room_quota, peak, bullet_peak])
		battle.free()
		# Exercise exact saturation: summons wait, and a splitter can only replace itself.
		battle = BattleSession.new()
		battle.encounter = load("res://game/content/encounters/lost_library_1.tres")
		battle.start_baseline(&"storm", words, MODES[rank], "summon-cap", false)
		var brood := battle._spawn_enemy(load("res://game/content/enemies/brood.tres"), Vector2(0.6, 0.5))
		var split := battle._spawn_enemy(load("res://game/content/enemies/split.tres"), Vector2(0.65, 0.5))
		split.combat_locked = true
		while battle._living().size() < battle._enemy_cap:
			battle._spawn_enemy(load("res://game/content/enemies/nib.tres"), Vector2(0.7, 0.5))
		battle._resolve_attack(brood)
		_check(brood.spawn_count == 0 and battle._living().size() == battle._enemy_cap, "brood waits at the alive cap")
		battle.commit_damage(split, 10000 * battle.Q, 10000 * battle.Q, &"fixture", battle.player_position)
		_check(battle._living().size() == battle._enemy_cap and battle.enemies[-1].small, "split death fills the one released slot without exceeding the cap")
		battle.free()
		battle = BattleSession.new()
		battle.encounter = load("res://game/content/encounters/lost_library_1.tres")
		battle.start_baseline(&"storm", words, MODES[rank], "brood-workload", false)
		brood = battle._spawn_enemy(load("res://game/content/enemies/brood.tres"), Vector2(0.6, 0.5))
		for attack in 8:
			battle._resolve_attack(brood)
			for child in battle._living():
				if child.small:
					child.combat_locked = true
					battle.commit_damage(child, 10000 * battle.Q, 10000 * battle.Q, &"fixture", battle.player_position)
		_check(brood.spawn_count == 5 and battle._living().size() <= battle._enemy_cap, "brood retains all five summons when slots are available")
		battle.free()
		battle = BattleSession.new()
		battle.encounter = load("res://game/content/encounters/ink_colossus.tres")
		battle.start_baseline(&"storm", words, MODES[rank], "guards", false)
		var boss := battle.enemies[0]
		boss.phase = 2
		for attack in 10: battle._resolve_attack(boss)
		_check(battle._living().size() == 3 + rank, "Boss retains its original guard count")
		battle.free()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _check_segment_boundary(words: Array[VocabularyEntry]) -> void:
	var battle := BattleSession.new()
	battle.encounter = load("res://game/content/encounters/lost_library_1.tres")
	battle.start_baseline(&"spirit", words, "normal", "overlap", false)
	var survivor := battle.enemies[0]
	var bullet := BattleThreat.new()
	bullet.position = Vector2(0.1, 0.1)
	bullet.life = 100.0
	battle.threats.append(bullet)
	battle._advance_encounter(120.0)
	_check(battle.wave == 1 and survivor.alive(), "elapsed time cannot advance an uncleared segment")
	battle._room_quota = battle._spawned * battle.encounter.wave_count
	for enemy in battle._living():
		enemy.combat_locked = true
		battle.commit_damage(enemy, 10000 * battle.Q, 10000 * battle.Q, &"fixture", battle.player_position)
	for tick in 360:
		battle.step(1.0 / 60.0)
		if battle.wave == 2: break
	_check(battle.wave == 2 and battle.threats.has(bullet) and bullet.life < 100.0, "the actual clear/intermission transition preserves and advances launched flight")
	battle.free()


func _check_page_cleanup(words: Array[VocabularyEntry]) -> void:
	var previous := BattleSession.new()
	previous.encounter = load("res://game/content/encounters/lost_library_1.tres")
	previous.start_baseline(&"spirit", words, "normal", "clear", false)
	previous.threats.append(BattleThreat.new())
	var paid := previous.ledger.earn("paid-flight", &"fixture", previous.compiled_build.identity(), SpellLot.Kind.POWER, 10 * previous.Q, &"flight")
	var effect := previous.runtime._effect(paid, &"frost_spear", previous.enemies[0].id, Vector2(0.2, 0.1), previous.compiled_build)
	previous.projectiles.append(BattleProjectile.new(effect))
	previous._summon_spirit()
	previous._end(true)
	_check(previous.threats.is_empty() and previous.projectiles.is_empty() and previous.effects.is_empty() and previous.spirits.is_empty(), "page victory clears enemy and player flight before the route")
	_check(paid.amount_q == 0 and previous.runtime.fields.is_empty() and previous.runtime.spirit_attacks.is_empty(), "page cleanup settles paid lots and running fields exactly once")
	var result := previous.finish_room(&"victory")
	_check(result == previous.room_result, "repeated settlement keeps its original cleanup receipt")
	previous.free()


func _check_formal_page_handoff(words: Array[VocabularyEntry]) -> void:
	# Explicit victory fixtures isolate the save/reward/route handoff contract.
	var path := "res://.temp/difficulty-probe/page-handoff-%d" % Time.get_ticks_usec()
	var repository := SaveRepository.new(&"normal", path)
	var run := RunSession.new(repository, repository.load_profile())
	var settings := AppSettings.new()
	settings.progressive = false
	_check(run.begin(&"spirit", settings), "formal page handoff begins an isolated expedition")
	var prepared := VocabularyIndex.build(words)
	var bullet := BattleThreat.new()
	bullet.position = Vector2(0.1, 0.1)
	bullet.life = 12.0
	var current: BattleSession
	for serial in 4:
		var request := run.start_room(words, prepared)
		_check(request != null, "formal next-page request commits")
		if request == null: break
		current = BattleSession.new()
		current.start(request, run.combat)
		run.install_room_opening(current)
		if serial == 0: current.threats.append(bullet)
		_check(current.threats.has(bullet) == (serial == 0), "formal page %d starts without previous-page flight" % (serial + 1))
		if serial == 3:
			_check(current.encounter.chapter_number == 2, "formal next chapter starts with a cleared battlefield")
			current.free()
			break
		current._end(true)
		_check(run.finish_room(current), "formal page settlement commits after clearing flight")
		current.free()
		_check(run.take_route("rest"), "formal page rest commits without carrying flight")


func _check_reentrant_clear(words: Array[VocabularyEntry]) -> void:
	var battle := BattleSession.new()
	battle.start_baseline(&"storm", words, "normal", "reentrant-clear", false)
	var selection := BuildSelection.new()
	selection.book_id = &"storm"
	selection.assets = {&"R034": 1, &"R057": 1}
	var compiled := BuildCompiler.new().compile(selection)
	_check(compiled.success(), "overload/reflect fixture compiles its real relic effects")
	battle.install_prepared_build(compiled.build)
	var target := battle.enemies[0]
	target.position = Vector2(0.6, 0.5)
	target.previous_position = target.position
	target.combat_locked = true
	target.hp_q = 10000 * battle.Q
	target.max_hp_q = target.hp_q
	battle.runtime._conduct(target)
	battle.runtime._conduct(target)
	for index in 3:
		var bullet := BattleThreat.new()
		bullet.position = target.position
		bullet.attack_id = "clear-fixture-%s" % index
		if index == 1:
			bullet.reflected = true
			var lot := battle.ledger.earn("reflected-fixture", &"fixture", compiled.build.identity(), SpellLot.Kind.POWER, battle.Q, &"reflection")
			bullet.effect = battle.runtime._effect(lot, &"counter", target.id, target.position, compiled.build)
		battle.threats.append(bullet)
	var hp_before := target.hp_q
	battle._advance_threats(1.0 / 60.0)
	_check(battle.threats.is_empty() and target.hp_q < hp_before - battle.Q, "reflected contact triggers real overload and safely clears both earlier and later bullets exactly once")
	battle.free()
