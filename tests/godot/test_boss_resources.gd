extends SceneTree
## Run against source and with --main-pack <PCK>, using the editor executable
## and this script's absolute path. Verifies the actual exported resource data.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var itinerary: RunItinerary = load("res://game/content/s2_itinerary.tres")
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("abcdef", "测试")]
	for index in [2, 5, 8]:
		var room := itinerary.encounters[index]
		var definition := room.enemies[0]
		print("Boss resource: %s | health=%s" % [room.room_id, str(definition.boss_health)])
		_check(definition.boss and definition.boss_health.size() == BattleSession.MODE_HEALTH.size(), "%s has all difficulty health values" % room.room_id)
		if definition.boss_health.size() != BattleSession.MODE_HEALTH.size():
			continue
		for rank in RunSession.DIFFICULTIES.size():
			var battle := BattleSession.new()
			battle.encounter = room
			battle.start_baseline(&"storm", words, RunSession.DIFFICULTIES[rank], "boss-resource-check", false)
			_check(battle.enemies.size() == 1 and battle.enemies[0].boss, "%s/%s spawns its Boss" % [room.room_id, RunSession.DIFFICULTIES[rank]])
			if battle.enemies.size() == 1:
				var expected := roundi(definition.boss_health[rank] * pow(1.7, room.chapter_number - 1) * SpellResourceLedger.Q)
				_check(battle.enemies[0].max_hp_q == expected, "Boss uses the configured difficulty and chapter health")
			battle.step(1.0 / 60.0)
			_check(battle.result == 0, "Boss room cannot immediately complete without combat")
			battle.free()
	print("Boss resources: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
