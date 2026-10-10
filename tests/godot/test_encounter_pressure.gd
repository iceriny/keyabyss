extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("abcdef", "测试"), VocabularyEntry.new("ghijkl", "测试")]
	var modes := ["story", "normal", "hard", "nightmare", "apocalypse"]
	for rank in modes.size():
		var battle := BattleSession.new()
		battle.encounter = load("res://game/content/encounters/lost_library_1.tres")
		battle.start_baseline(&"storm", words, modes[rank], "quota", false)
		var quota := 22 + rank * 6
		_check(battle._room_quota == quota, "%s uses baseline first-room quota" % modes[rank])
		_check(battle.enemies.size() == (1 if rank < 2 else mini(3, rank)), "%s starts with a small batch" % modes[rank])
		_check(battle.enemies[0].max_hp_q == roundi(43 * BattleSession.MODE_HEALTH[rank] * battle.Q), "%s ordinary health follows its own mode scale" % modes[rank])
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
		_check(battle.result == 1 and battle._spawned == quota and battle.enemies.size() == quota and phases.size() == 3, "%s clears exactly its quota through the actual fixed-step spawner and three waves" % modes[rank])
		print("%s quota=%s spawned=%s peak=%s elapsed=%.2f" % [modes[rank], quota, battle._spawned, peak, battle.elapsed])
		battle.free()
	var boss_battle := BattleSession.new()
	boss_battle.encounter = load("res://game/content/encounters/ink_colossus.tres")
	boss_battle.start_baseline(&"storm", words, "normal", "pressure", false)
	var boss := boss_battle.enemies[0]
	boss_battle._emit_pattern(boss, &"ring")
	_check(is_equal_approx(boss_battle.threats[0].velocity.length(), 83 * 1.5 * 0.9 * (1 + 2 * 0.032)), "first Boss normal bullet speed matches physical stage pressure")
	_check(is_equal_approx(boss.attack_interval, 3.2 * 1.3 / (1 + 2 * 0.022)), "Boss interval uses warning scale independently of damage")
	var q := boss_battle.Q
	boss_battle._counter_contact(boss)
	_check(boss_battle.resonance_q == 3 * q, "successful parry gives three resonance once")
	boss_battle.free()
	print("Encounter pressure: %s failure(s)" % failures)
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
