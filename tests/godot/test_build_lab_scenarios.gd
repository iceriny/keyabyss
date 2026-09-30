extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func start(scenario: String) -> BattleSession:
	var request := BattleStartRequest.new()
	request.build = BuildCompiler.new().compile(BuildSelection.new()).build
	request.vocabulary = [VocabularyEntry.new("ink", "墨")]
	request.encounter = BuildLabScenarios.encounter(scenario)
	request.seed_text = "scenario-test"
	var session := BattleSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.start(request)
	BuildLabScenarios.arrange(session, scenario)
	return session


func _run() -> void:
	var nib := load("res://game/content/enemies/nib.tres") as EnemyCombatDefinition
	var quill := load("res://game/content/enemies/quill.tres") as EnemyCombatDefinition
	var nib_hp := nib.health
	var quill_hp := quill.health
	var priority := start("priority")
	check(priority.enemies.size() == 3 and priority.enemies[0].kind == &"nib" and priority.enemies[1].kind == &"quill", "目标优先级配置包含近战与远程威胁")
	var near := priority.enemies[0]
	var far := priority.enemies[1]
	var near_distance := ((near.position - priority.player_position) * BattleSession.ARENA_SIZE).length()
	var far_distance := ((far.position - priority.player_position) * BattleSession.ARENA_SIZE).length()
	check(near_distance > BattleEnemy.MELEE_REACH and near_distance < far_distance and far_distance < 480.0, "近敌未贴脸且远敌处于攻击射程")
	check(far.attack_clock >= far.warning_time and far.attack_clock < near.attack_clock, "远处羽笔较早蓄力且保留预警")
	priority._physics_process(0.2)
	check(far.aiming and far.hp_q > 0 and near.position != near.previous_position, "正式时间推进产生预警与逼近")
	var escort := start("escort")
	check(escort.enemies.size() == 4, "护卫情境含三只小怪和一个耐久目标")
	for index in 3:
		var weak := escort.enemies[index]
		check(weak.kind == &"nib" and weak.max_hp_q < nib_hp * 1024 and weak.max_hp_q < escort.enemies[3].max_hp_q, "围绕目标的小怪保持低生命")
		check(BattleSession.enemy_in_combat(weak) and not weak.combat_locked and weak.frozen_time == 0.0, "小怪使用正式可见战斗行为")
	check(escort.enemies[3].max_hp_q == 90 * 1024, "耐久目标仍为有限生命")
	var waves := start("waves")
	check(waves.encounter.wave_count == 3 and waves.encounter.wave_interval == 1.6 and waves.wave == 1, "三波沿用正式间歇配置")
	check(waves.enemies.size() == 3 and waves.enemies[0].max_hp_q == nib_hp * 1024, "波次使用普通敌人生命")
	var entry := waves.enemies[0].position
	BuildLabScenarios.arrange(waves, "waves")
	check(waves.enemies[0].position == entry and not BattleSession.enemy_in_combat(waves.enemies[0]), "波次使用正式边缘入场，不布置后续波")
	waves._physics_process(0.2)
	check(waves.wave == 1 and waves.enemies[0].alive(), "未清敌不绕过正式波次出口")
	check(nib.health == nib_hp and quill.health == quill_hp, "共享敌人资源未污染")
	for scenario in ["priority", "escort", "waves"]:
		check(not BuildLabScenarios.description(scenario).is_empty(), "每个情境都有决策说明")
	priority.queue_free()
	escort.queue_free()
	waves.queue_free()
	print("Build lab scenarios: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
