class_name TutorialLesson
extends Node
## Isolated practice setup; BattleSession remains the only fixed-step rule owner.

signal step_changed(index: int, total: int, title: String, instruction: String, progress: String, complete: bool)
signal goal_changed(ready: bool)

const LESSON_IDS := [&"basics", &"frost", &"flame", &"storm", &"spirit"]
const STEPS := {
	&"basics": [&"intro", &"parry", &"dodge", &"ultimate"],
	&"frost": [&"intro", &"freeze", &"shatter", &"mist", &"ultimate"],
	&"flame": [&"intro", &"block", &"burn", &"mist", &"ultimate"],
	&"storm": [&"intro", &"charge", &"dodge", &"ultimate"],
	&"spirit": [&"intro", &"mark", &"sleep", &"crane", &"ultimate"],
}
const TRAINING_HEALTH := 1000000
const WORDS := ["shade", "shard", "shine", "frost", "flame", "storm", "paper", "light", "spell", "bloom"]

var session: BattleSession
var book_id: StringName = &"frost"
var lesson_id: StringName
var completed := false
var step_index := 0
var ready_to_advance := false
var _manual_attempts: Dictionary[String, bool] = {}
var _casts := 0
var _empowered := false
var _seen: Dictionary[StringName, bool] = {}
var _hit_targets: Dictionary[StringName, bool] = {}
var _rear_cast := false
var _spirit_peak := 0
var _ultimate_started := 0.0
var _last_elapsed := 0.0
var _healing_remainder := 0.0
var _last_progress := ""


static func create_lesson(id: StringName) -> TutorialLesson:
	assert(id in LESSON_IDS, "Unknown practice lesson: %s" % id)
	var lesson := TutorialLesson.new()
	lesson.lesson_id = id
	lesson.book_id = &"frost" if id == &"basics" else id
	lesson.session = BattleSession.new()
	var selection := BuildSelection.new()
	selection.book_id = lesson.book_id
	var compiled := BuildCompiler.new().compile(selection)
	assert(compiled.success(), str(compiled.diagnostics))
	var request := BattleStartRequest.new()
	request.build = compiled.build
	for word: String in WORDS:
		request.vocabulary.append(VocabularyEntry.new(word, ""))
	request.vocabulary_index = VocabularyIndex.build(request.vocabulary)
	request.minimum_length = 5
	request.maximum_length = 5
	request.progressive = false
	request.difficulty = "story"
	request.seed_text = "practice:%s" % id
	request.encounter = BattleEncounter.new()
	request.encounter.wave_count = 1
	request.encounter.enemies.clear()
	for index in 3:
		var target := EnemyCombatDefinition.new()
		target.health = TRAINING_HEALTH
		target.speed = 0.0
		target.stationary = true
		target.mass = 1000.0
		target.attack_interval = 1000000.0
		request.encounter.enemies.append(target)
	# This request owns a fresh RunCombatState, with no expedition/profile wiring.
	lesson.session.start(request)
	for index in lesson.session.enemies.size():
		var enemy := lesson.session.enemies[index]
		enemy.position = Vector2(0.61 + index * 0.055, 0.5)
		enemy.previous_position = enemy.position
		enemy.attack_clock = 1000000.0
		lesson.session.typing.upsert_target(enemy.id, enemy.word)
	lesson.session._pickup_clock = 1000000.0
	lesson.session.typing.word_completed.connect(lesson._remember_completion)
	lesson.session.event_committed.connect(lesson._remember_event)
	lesson.session.state_changed.connect(lesson._observe_committed_step)
	return lesson


func refresh() -> void:
	_emit_step()


func current_step() -> StringName:
	return STEPS[lesson_id][step_index]


func step_count() -> int:
	return STEPS[lesson_id].size()


func advance() -> void:
	if completed or not ready_to_advance: return
	ready_to_advance = false
	if step_index == step_count() - 1:
		completed = true
		session.set_physics_process(false)
		session.threats.clear()
		session.hazards.clear()
	else:
		step_index += 1
		_seen.clear()
		_hit_targets.clear()
		_configure_step()
	_emit_step()


func _remember_completion(fact: WordCompletion) -> void:
	if fact.fully_manual():
		_manual_attempts[fact.attempt_id] = true
		if current_step() == &"block" and fact.target_id == session.enemies[2].id:
			_rear_cast = true


func _remember_event(event: Dictionary) -> void:
	match event.kind:
		&"cast":
			# The completion and paid cast must both exist; unfinished input never counts.
			if not _manual_attempts.is_empty():
				_casts += 1
				_manual_attempts.erase(_manual_attempts.keys()[0])
				_empowered = _empowered or bool(event.empowered)
		&"freeze": _seen[&"freeze"] = true
		&"spirit_summon":
			if _seen.has(&"sleep"): _seen[&"wake"] = true
		&"impact":
			if int(event.applied_q) <= 0: return
			_seen[event.source] = true
			if bool(event.empowered): _seen[&"empowered_hit"] = true
			if event.source in [&"frost_spear", &"storm_arc"]:
				_hit_targets[event.enemy] = true
			if current_step() == &"block" and _rear_cast and event.source == &"flame_burst" and event.enemy == session.enemies[0].id:
				_seen[&"blocked"] = true
		&"enemy_attack":
			if event.outcome == &"parry": _seen[&"parry"] = true
		&"enemy_shot":
			for threat in session.threats:
				if not threat.reflected: threat.damage_q = 2 * BattleSession.Q
		&"dodge": _seen[&"dodge"] = true
		&"ultimate":
			_seen[&"ultimate"] = true
			_ultimate_started = session.elapsed


func _observe_committed_step() -> void:
	if completed or session.result != 0:
		return
	var real_delta := session.elapsed - _last_elapsed
	_last_elapsed = session.elapsed
	# Low-damage mistakes remain real; practice restores health gradually.
	_healing_remainder += real_delta * 5.0 * BattleSession.Q
	var healing := floori(_healing_remainder)
	_healing_remainder -= healing
	session.runtime.heal(healing)
	# Charged continuations are queued after impact emission; inspect the committed step.
	for effect in session.effects:
		if effect.kind == &"storm_arc" and effect.arc_index > 0 and effect.arc_charge > 1.0:
			_seen[&"charged"] = true
	if current_step() == &"sleep" and session.spirit_blade_count() < _spirit_peak:
		_seen[&"sleep"] = true
	if current_step() == &"shatter" and not session.enemies[0].alive() and not _seen.has(&"frost_shatter"):
		# Missing the freeze window respawns the exercise instead of making it unwinnable.
		var retry := session.enemies[0]
		retry.hp_q = 120 * BattleSession.Q
		retry.cold = 0
		retry.frozen_time = 0.0
		retry.freeze_cooldown = 0.0
		retry.word_pending = false
		session.runtime._settled_deaths.erase(retry.id)
		session.runtime._pending_death_depth.erase(retry.id)
		session.typing.upsert_target(retry.id, retry.word)
	if current_step() == &"mist" and _seen.has(&"dodge"):
		var nearby := session.enemies[0]
		if book_id == &"frost" and nearby.cold > 0 and session.runtime.obscures(nearby):
			_seen[&"mist_effect"] = true
		if book_id == &"flame" and nearby.burn > 10 and _seen.has(&"flame_burn"):
			_seen[&"mist_effect"] = true
	if _step_complete():
		ready_to_advance = true
	if _progress() != _last_progress:
		_emit_step()


func _configure_step() -> void:
	var step := current_step()
	if step == &"sleep":
		_spirit_peak = session.spirit_blade_count()
		return
	if step == &"burn": return # The preceding blocked fireball supplies real residual burn.
	if step == &"mark": return # Keep the spirits earned by the initial manual input.
	if step == &"shatter":
		# A fragile frozen target makes a real death chain reachable without a long damage grind.
		_clear_flying_spells()
		session.enemies[0].hp_q = BattleSession.Q
		session.enemies[1].position = session.enemies[0].position + Vector2(75, 0) / BattleSession.ARENA_SIZE
		session.enemies[1].previous_position = session.enemies[1].position
		return
	# Stage the next exercise; no combat result or successful input is fabricated.
	session.player_position = Vector2(0.5, 0.5)
	session.previous_player_position = session.player_position
	session._dodge_time = 1.0
	session.dodge_window = 0.0
	session.hurt_window = 0.0
	session.perfect_dodge_remaining = 0.0
	_clear_flying_spells()
	session.threats.clear()
	session.runtime.fields.clear()
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.hp_q = enemy.max_hp_q
		session.runtime._settled_deaths.erase(enemy.id)
		session.runtime._pending_death_depth.erase(enemy.id)
		enemy.position = Vector2(0.61 + index * 0.055, 0.5)
		enemy.previous_position = enemy.position
		enemy.impulse = Vector2.ZERO
		enemy.cold = 0
		enemy.cold_grace = 0.0
		enemy.frozen_time = 0.0
		enemy.freeze_cooldown = 0.0
		enemy.burn = 0
		enemy.shock = 0
		enemy.attack_clock = 1000000.0
		enemy.aiming = false
		session.typing.upsert_target(enemy.id, enemy.word)
	if step == &"parry" or step == &"crane":
		var shooter := session.enemies[0]
		shooter.behavior = &"curve"
		shooter.warning_time = 1.2
		shooter.attack_interval = 5.0
		shooter.attack_clock = 1.8
	if step == &"mist":
		var nearby := session.enemies[0]
		nearby.position = session.player_position + Vector2(65 if book_id == &"frost" else 50, 0) / BattleSession.ARENA_SIZE
		nearby.previous_position = nearby.position
	if step == &"ultimate":
		for ultimate in session.ultimates: session.runtime.retire(ultimate.effect)
		session.ultimates.clear()
		session.ultimate_time = 0.0
		session.add_resonance(BattleSession.ULTIMATE_COST_Q - session.resonance_q)


func _clear_flying_spells() -> void:
	for effect in session.effects:
		session._release_word(effect, false)
		session.runtime.retire(effect)
	session.effects.clear()
	for projectile in session.projectiles:
		session._release_word(projectile.effect, false)
		session.runtime.retire(projectile.effect)
	session.projectiles.clear()


func _step_complete() -> bool:
	match current_step():
		&"intro":
			if _casts < 3 or not _empowered: return false
			if lesson_id == &"basics": return true
			match book_id:
				&"frost": return _seen.has(&"empowered_hit") and _hit_targets.size() >= 2
				&"flame": return _seen.has(&"flame_splash")
				&"storm": return _seen.has(&"storm_burst") and _hit_targets.size() >= 2
				&"spirit": return _seen.has(&"spirit_cross")
		&"parry", &"freeze": return _seen.has(current_step())
		&"shatter": return _seen.has(&"frost_shatter")
		&"block": return _seen.has(&"blocked")
		&"burn": return _seen.has(&"flame_burn")
		&"charge": return _seen.has(&"charged")
		&"mark": return _seen.has(&"spirit_mark") and _seen.has(&"spirit_blade") and session.enemies[0].vulnerability > 0
		&"sleep": return _seen.has(&"sleep") and _seen.has(&"wake")
		&"crane": return _seen.has(&"dodge") and _seen.has(&"paper_crane")
		&"mist": return _seen.has(&"mist_effect")
		&"dodge": return _seen.has(&"dodge") and (lesson_id == &"basics" or _seen.has(&"storm_dodge"))
		&"ultimate":
			if not _seen.has(&"ultimate") or session.elapsed - _ultimate_started < 2.0: return false
			match book_id:
				&"frost": return _seen.has(&"frost_ultimate") and session.run_state.shield_q > 0
				&"flame": return _seen.has(&"flame_wave") and _seen.has(&"flame_domain")
				&"storm": return _seen.has(&"storm_burst") and _seen.has(&"storm_arc")
				&"spirit": return _seen.has(&"spirit_blade") and session.spirit_blade_count() == session.spirit_capacity()
	return false


func _progress() -> String:
	if completed:
		return "练习完成"
	if ready_to_advance:
		match current_step():
			&"intro": return {&"basics": "三个词咒已完成", &"frost": "强化冰矛已贯穿训练靶", &"flame": "焰印已爆炸并留下火雾", &"storm": "电链与范围电爆已命中", &"spirit": "纸灵交叉斩已命中"}[lesson_id]
			&"parry": return "御术已接住真实敌弹"
			&"freeze": return "寒气已触发冻结"
			&"shatter": return "冻裂已伤及旁边的训练靶"
			&"block": return "后排施法的火弹已被前排挡住"
			&"burn": return "停笔后灼烧仍实际造成了伤害"
			&"charge": return "感电已被消耗，电链完成充能"
			&"mark": return "易伤已标记，纸灵自动攻击已命中"
			&"sleep": return "纸灵已休眠，再次完词已唤醒"
			&"crane": return "纸鹤已拦截敌弹并反伤发射者"
			&"mist": return "冰雾已积累寒气并遮蔽视线" if book_id == &"frost" else "闪避火雾已造成灼烧伤害"
			&"dodge": return "闪避雷径已伤害靶并施加感电" if book_id == &"storm" else "方向闪避已完成"
			&"ultimate": return {&"frost": "护盾已获得，领域冰锥已命中", &"flame": "火浪与持续火域都已造成伤害", &"storm": "终式期间施法已触发电爆与电链", &"spirit": "全部纸灵已唤醒并狂暴命中"}[book_id]
	match current_step():
		&"intro": return "完成词咒 %s / 3 · 强化命中 %s / 1" % [mini(_casts, 3), int(_seen.has(&"empowered_hit") or _seen.has(&"spirit_cross"))]
		&"parry": return "等敌弹靠近，再按 Space"
		&"freeze": return "前排寒气 %d / 91 · 连续完成它的词咒" % session.enemies[0].cold
		&"shatter": return "靶已冻结，完成词咒击破它" if session.enemies[0].frozen_time > 0.0 else "冻结已结束；连续施法再次冻结并击破"
		&"block": return "目标：后排词咒 %s" % session.enemies[2].word
		&"burn": return "暂时停笔，等灼烧实际扣血"
		&"charge": return "前排感电 %d · 连续命中直至充能" % session.enemies[0].shock
		&"mark": return "完成前排词咒，等待纸灵自动命中"
		&"sleep": return "已有纸灵休眠；完成词咒重新唤醒" if _seen.has(&"sleep") else "暂时停笔 · 纸灵维持剩余 %s 秒" % GameText.number(session.spirit_time)
		&"crane": return "等靶锁定你，再按 ↓；等纸鹤反伤" if session.enemies[0].aiming else "等待预警 · 纸鹤需拦截真实敌弹"
		&"mist": return "按 ←，把训练靶留在起点雾中"
		&"dodge": return "按 →，让闪避路径穿过训练靶" if book_id == &"storm" else "按方向键完成一次闪避"
		&"ultimate": return "终式期间继续完成前排词咒" if book_id == &"storm" and _seen.has(&"ultimate") else "已释放，等待领域实际生效" if _seen.has(&"ultimate") else "共鸣已满，单独按下并松开 Shift"
	return ""


func _emit_step() -> void:
	var title := ""
	var instruction := ""
	match current_step():
		&"intro":
			title = "完成词咒" if lesson_id == &"basics" else "施法与强化"
			instruction = "亲手完成三个词咒，每第三次强化施法。" if lesson_id == &"basics" else {
				&"frost": "冰锥能贯穿同线敌人；第三次成为更强、贯穿更多目标的冰矛。连续完成前排词咒三次，让冰矛实际命中。",
				&"flame": "火弹被前排挡住；第三次焰印爆炸，伤及附近敌人并留下火雾。连续完成前排词咒三次，触发焰印。",
				&"storm": "电链逐段衰减，同一条链不重复命中同一敌人；第三次附带范围电爆。连续完成前排词咒三次，击中敌群。",
				&"spirit": "完成词咒按亲手字符数唤醒纸灵；本房五字词每次唤醒一只，自动游击。第三次施法指挥交叉斩。连续完成前排词咒三次。",
			}[book_id]
			instruction += "\n未输入时 Tab 轮换，Shift+Tab 反向。输入后只换相同开头，保留进度；只有一个匹配时不切换。换不同开头先 Backspace 取消，再输入首字。Esc 暂停。"
		&"parry":
			title = "御术与反弹"
			instruction = "敌弹将碰到你时按 Space 御术。起手0.10秒内接住可触发完美御术，反弹敌弹并短暂放慢时间。失误可等下一颗重试。"
		&"freeze":
			title = "寒气与冻结"
			instruction = "寒气减慢移动与攻击；超过90点消耗60点，冻结会暂停敌人的动作。新加寒气后1秒不流失，此后每秒减少6点。连续完成前排词咒，实际触发冻结。"
		&"shatter":
			title = "冻裂连锁"
			instruction = "冻结期间死亡触发冻裂：炸伤附近敌人并施加寒气，可继续连锁。前排靶已剩少量生命；完成它的词咒，让旁边的靶受冻裂伤害。错过冻结窗口可连续施法再次冻结；未触发冻裂可继续重试。"
		&"block":
			title = "火弹被谁挡住"
			instruction = "锁定后排并不保证火弹穿过前排。按 Tab 切到最右靶，再完成其词咒：沿途前排会承受火弹。转火时要考虑站位；焰印的爆炸可以波及旁边的敌人。"
		&"burn":
			title = "停笔后的余火"
			instruction = "灼烧超过10点后，每0.15秒扣血并消耗5点，降至10点停止。暂时停笔，等前排实际受到灼烧伤害。橙色生命尾段估计剩余余火伤害，可据此转火。"
		&"charge":
			title = "感电为电链充能"
			instruction = "电链命中积累感电，也能接入更远的敌人。目标感电超过30点时，电链消耗10点充能：提高后续伤害，并多跳一次。连续完成前排词咒，实际触发充能。"
		&"mark":
			title = "标记与自动游击"
			instruction = "施法标记目标，易伤会提高它受到的伤害。纸灵自动游击标记目标，不必逐次指挥。再完成前排词咒，随后停笔，等纸灵自动击中它。"
		&"sleep":
			title = "维持与重新唤醒"
			instruction = "有效输入会刷新纸灵的维持时间；停笔超时后逐只休眠。先停笔等一只休眠，再完成一个词咒重新唤醒。持续输入能维持纸灵，也持续积累标记。"
		&"crane":
			title = "纸鹤拦截与反伤"
			instruction = "闪避在起点留下符文纸鹤，持续4秒。等训练靶预警、锁定你后按↓闪避：敌弹沿旧瞄准飞向纸鹤。纸鹤拦截一颗后反伤发射者并消失；朝它飞来的敌弹才会被拦截。"
		&"mist":
			title = "冰雾遮蔽" if book_id == &"frost" else "闪避留下火雾"
			instruction = "按←闪避，把近靶留在起点冰雾中。冰雾持续3秒，给雾内敌人积累寒气，并遮蔽远处敌人的新瞄准；已经锁定的弹道仍会发射。" if book_id == &"frost" else "按←闪避，把近靶留在起点火雾中。火雾持续2秒、不断施加灼烧；离开后余火仍会扣血。停笔等靶真正受到雾造成的灼烧伤害。"
		&"dodge":
			title = "闪避雷径" if book_id == &"storm" else "方向闪避"
			instruction = "按→穿过训练靶：闪避路径会伤害沿途敌人并施加30点感电。落点接近敌群时仍需留意后续攻击。" if book_id == &"storm" else "方向键朝指定方向闪避，Alt自动选择落点。消耗一次充能，获得1秒无敌；充能会恢复。现在按一个方向完成闪避。"
		&"ultimate":
			title = {&"frost": "冰河纪事", &"flame": "焚世余烬", &"storm": "雷鸣终章", &"spirit": "千纸夜行"}[book_id]
			instruction = "输入与成功防御积累共鸣。本次已补满；单独按下并松开Shift释放终式。\n" + {
				&"frost": "获得20点护盾；领域持续积累寒气，并从不同方向发射冰锥。等领域冰锥真实命中。",
				&"flame": "全场火浪立即伤害敌人；脚下火域持续施加灼烧，并独立造成伤害。等火浪和火域都实际命中。",
				&"storm": "领域持续施加感电，期间每次施法都附带电爆，并保留一条电链。释放后再完成前排词咒，触发终式施法。",
				&"spirit": "立即唤醒全部纸灵并使其狂暴，提升伤害、飞行速度与攻击频率。等狂暴纸灵实际击中目标。",
			}[book_id]
	instruction += "\n悬浮虚线术语可查看详细效果；达成目标后点击%s。" % ("完成练习" if step_index == step_count() - 1 else "下一步")
	if completed:
		instruction = "练习完成。可返回选择其他练习，或开始远征。"
	_last_progress = _progress()
	step_changed.emit(step_index, step_count(), title, instruction, _last_progress, completed)
	goal_changed.emit(ready_to_advance and not completed)
