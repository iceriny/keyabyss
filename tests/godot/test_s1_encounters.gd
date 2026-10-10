extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var itinerary: RunItinerary = load("res://game/content/s1_itinerary.tres")
	_check(itinerary.encounters.size() == 3, "first chapter has three rooms including its Boss")
	_check(itinerary.encounters[0].room_id != itinerary.encounters[1].room_id and itinerary.encounters[2].enemies[0].boss, "distinct rooms lead to the formal Boss")
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("abcdef", "测试"), VocabularyEntry.new("ghijkl", "测试"), VocabularyEntry.new("mnopqr", "测试"), VocabularyEntry.new("stuvwx", "测试")]
	for book in [&"frost", &"flame", &"storm", &"spirit"]:
		for room in itinerary.encounters:
			var battle := BattleSession.new()
			battle.encounter = room
			battle.start_baseline(book, words, "normal", "s1-test", false)
			for tick in 12000:
				battle.hurt_window = 10.0 # Isolate encounter/input completion from player skill.
				battle.step(1.0 / 60.0)
				if battle.result != 0: break
				if tick % 12 == 0:
					for enemy in battle.enemies:
						if enemy.alive() and battle.typing._targets.has(enemy.id):
							battle.typing.select_target(enemy.id)
							for character in enemy.word: battle.typing.feed(character)
							break
			_check(battle.result == 1 and battle.manual_characters > 0, "%s completes %s with real typing facts" % [book, room.room_id])
			battle.free()
	var boss_room := BattleSession.new()
	boss_room.encounter = itinerary.encounters[2]
	boss_room.start_baseline(&"frost", words, "normal", "boss", false)
	var boss := boss_room.enemies[0]
	boss.hp_q = boss.max_hp_q / 2
	boss.attack_clock = 0.0
	boss_room._advance_enemies(0.01)
	_check(boss.phase == 2 and boss_room.enemies.size() >= 2 and boss_room.enemies[1].behavior == &"charge", "phase two adds a separate typing target that charges")
	_check(boss_room.threats.size() == 9 and boss.delayed_attacks.size() == 1 and boss_room.hazards.size() == 1, "Boss commits a gapped ring, delayed fan and visible blast warning")
	var ram := boss_room.enemies[1]
	ram.position = Vector2(0.4, 0.5)
	ram.aimed_position = boss_room.player_position
	boss_room._resolve_attack(ram)
	boss_room._advance_enemy_motion(0.05)
	_check(ram.charge_time > 0.0 and ram.velocity.length() > 0.0, "ram warning becomes actual motion")
	ram.frozen_time = 1.0
	boss_room._advance_enemy_motion(0.01)
	_check(ram.charge_time == 0.0, "freeze interrupts a charge")
	boss_room.precision_slow_remaining = 1.5
	boss_room.dodge_charges = 0.0
	var clock := boss_room.runtime.clock
	boss_room.step(0.1)
	_check(is_equal_approx(boss_room.runtime.clock - clock, 0.01) and boss_room.dodge_charges > 0.02, "precision slows world while defense recovers in real time")
	boss_room.free()
	print("S1 encounters: %s failure(s)" % failures)
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
