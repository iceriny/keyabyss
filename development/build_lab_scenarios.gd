class_name BuildLabScenarios
extends RefCounted
## Initial room conditions only; movement, attacks and wave exits remain formal.


static func encounter(scenario: String) -> BattleEncounter:
	assert(scenario in ["priority", "escort", "waves"], "Unknown build lab scenario: " + scenario)
	var room := BattleEncounter.new()
	room.enemies = []
	room.wave_count = 3 if scenario == "waves" else 1
	room.wave_interval = 1.6
	if scenario == "escort":
		for index in 3:
			var weak := _enemy("nib")
			weak.health = 12
			room.enemies.append(weak)
		var durable := _enemy("quill")
		durable.health = 90
		room.enemies.append(durable)
	else:
		for kind in ["nib", "quill", "guard"]:
			room.enemies.append(_enemy(kind))
	return room


static func arrange(session: BattleSession, scenario: String) -> void:
	assert(scenario in ["priority", "escort", "waves"], "Unknown build lab scenario: " + scenario)
	if scenario == "waves" or session.wave != 1:
		return
	var offsets: Array[Vector2] = [Vector2(190, -30), Vector2(390, 40), Vector2(-290, 130)]
	var clocks: Array[float] = [1.5, 1.05, 2.6]
	if scenario == "escort":
		offsets = [Vector2(290, -70), Vector2(290, 70), Vector2(430, 0), Vector2(360, 0)]
		clocks = [1.8, 2.2, 2.6, 1.4]
	assert(session.enemies.size() == offsets.size(), "Scenario composition does not match initial wave")
	for index in offsets.size():
		var enemy := session.enemies[index]
		enemy.position = BattleSession.clamp_player(session.player_position + offsets[index] / BattleSession.ARENA_SIZE)
		enemy.previous_position = enemy.position
		enemy.attack_clock = clocks[index]


static func description(scenario: String) -> String:
	match scenario:
		"priority":
			return "近处的笔尖正在逼近，远处的羽笔很快开始蓄力。先清近敌，还是先打断远处威胁？控制、直接击杀与提前部署攻击都可以争取输入时间。"
		"escort":
			return "三只脆弱笔尖围着耐久羽笔。先清开周围小怪，还是集中处理羽笔？观察范围攻击、集中攻击与控制各自能争取多少安全输入时间。"
		"waves":
			return "三段普通敌人连续到来。立即用尽力量，还是保留后手？观察已部署的攻击、储备和回收能否接上下一段。"
	assert(false, "Unknown build lab scenario: " + scenario)
	return ""


static func _enemy(kind: String) -> EnemyCombatDefinition:
	return load("res://game/content/enemies/%s.tres" % kind).duplicate(true) as EnemyCombatDefinition
