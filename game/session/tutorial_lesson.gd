class_name TutorialLesson
extends Node
## Isolated practice setup; BattleSession remains the only fixed-step rule owner.

signal step_changed(index: int, total: int, title: String, instruction: String, progress: String, complete: bool)
signal goal_changed(ready: bool)

const LESSON_IDS := [&"basics", &"frost", &"flame", &"storm", &"spirit"]
const STEPS := {
	&"basics": [&"intro", &"switch", &"cancel", &"parry", &"dodge", &"ultimate"],
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
var _burn_ticks := 0
var _burn_damage_q := 0
var _ultimate_started := 0.0
var _last_elapsed := 0.0
var _healing_remainder := 0.0
var _last_progress := ""
var _switch_phase := 0
var _previous_target: StringName
var _previous_progress := 0


static func create_lesson(id: StringName, initial_step: int = 0) -> TutorialLesson:
	assert(id in LESSON_IDS, "Unknown practice lesson: %s" % id)
	assert(initial_step >= 0 and initial_step < STEPS[id].size(), "Unknown practice step: %s" % initial_step)
	var lesson := TutorialLesson.new()
	lesson.lesson_id = id
	lesson.step_index = initial_step
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
	lesson.session.typing.changed.connect(lesson._observe_typing)
	if initial_step > 0: lesson._configure_step()
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
		if current_step() == &"switch" and not _seen.has(&"switch"):
			_seen[&"restart_switch"] = true
		if current_step() == &"block" and fact.target_id == session.enemies[2].id:
			_rear_cast = true


func _observe_typing() -> void:
	var typing := session.typing
	if current_step() == &"switch":
		if _switch_phase == 0 and typing.target_id == session.enemies[1].id and typing.progress == 0 and _previous_target == session.enemies[0].id:
			_switch_phase = 1
		elif _switch_phase == 1 and _previous_progress == 3 and typing.progress == 3 and typing.word.begins_with("sha") and typing.target_id != _previous_target:
			_seen[&"switch"] = true
	elif current_step() == &"cancel":
		if _previous_progress > 0 and typing.progress == 0 and typing.target_id == &"":
			_seen[&"cancelled"] = true
		if _seen.has(&"cancelled") and typing.target_id == session.enemies[2].id and typing.progress > 0:
			_seen[&"cancel"] = true
	_previous_target = typing.target_id
	_previous_progress = typing.progress


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
			if current_step() == &"burn" and event.source == &"flame_burn" and not ready_to_advance:
				_burn_ticks += 1
				_burn_damage_q += int(event.applied_q)
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
	if current_step() == &"switch" and _seen.has(&"restart_switch"):
		_seen.erase(&"restart_switch")
		_configure_step()
	# Low-damage mistakes remain real; practice restores health gradually.
	_healing_remainder += real_delta * 5.0 * BattleSession.Q
	var healing := floori(_healing_remainder)
	_healing_remainder -= healing
	session.runtime.heal(healing)
	# Charged continuations are queued after impact emission; inspect the committed step.
	for effect in session.effects:
		if effect.kind == &"storm_arc" and effect.arc_index > 0 and effect.arc_charge > 1.0:
			_seen[&"charged"] = true
	if current_step() == &"sleep":
		var awake := session.spirit_blade_count()
		_spirit_peak = maxi(_spirit_peak, awake)
		if awake < _spirit_peak: _seen[&"sleep"] = true
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
	if step == &"cancel" and session.typing.progress > 0 and session.typing.word.begins_with("sha"):
		return # Continue from the shared opening already typed.
	if step == &"sleep":
		_spirit_peak = session.spirit_blade_count()
		return
	if step == &"burn":
		# Use a readable, real health bar for the burn forecast; fresh input can reignite it.
		_clear_flying_spells()
		session.enemies[0].max_hp_q = 240 * BattleSession.Q
		session.enemies[0].hp_q = session.enemies[0].max_hp_q
		return
	if step == &"mark": return # Keep the spirits earned by the initial manual input.
	if step == &"shatter":
		# A fragile frozen target makes a real death chain reachable without a long damage grind.
		_clear_flying_spells()
		session.enemies[0].hp_q = (1 if session.enemies[0].frozen_time > 0.0 else 120) * BattleSession.Q
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
	session.typing.cancel()
	session.threats.clear()
	session.runtime.fields.clear()
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.max_hp_q = TRAINING_HEALTH * BattleSession.Q
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
	if step in [&"switch", &"cancel"]:
		_switch_phase = 0
		for index in session.enemies.size():
			var target := session.enemies[index]
			target.word = ["shade", "shard", "flame"][index]
			target.word_age = 1.0
			session.typing.upsert_target(target.id, target.word)
		session.typing.select_target(session.enemies[0].id)
		_seen.erase(&"cancelled") # Restaging is not a cancellation performed by the player.
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
			if lesson_id == &"basics": return _casts >= 1
			if _casts < 3 or not _empowered: return false
			match book_id:
				&"frost": return _seen.has(&"empowered_hit") and _hit_targets.size() >= 2
				&"flame": return _seen.has(&"flame_splash")
				&"storm": return _seen.has(&"storm_burst") and _hit_targets.size() >= 2
				&"spirit": return _seen.has(&"spirit_cross")
		&"switch", &"cancel", &"parry", &"freeze": return _seen.has(current_step())
		&"shatter": return _seen.has(&"frost_shatter")
		&"block": return _seen.has(&"blocked")
		&"burn": return _burn_ticks >= 3
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
			&"intro": return {&"basics": "法术已击出", &"frost": "冰矛穿过了多个目标", &"flame": "焰印爆炸，留下了火雾", &"storm": "电链和电爆击中了敌群", &"spirit": "纸灵一起攻击了目标"}[lesson_id]
			&"switch": return "已换目标，sha 保留了下来"
			&"cancel": return "已开始输入 flame"
			&"parry": return "挡住了敌弹"
			&"freeze": return "敌人冻住了"
			&"shatter": return "冻裂伤到了旁边的敌人"
			&"block": return "火弹打中了前排，后排没有受伤"
			&"burn": return "余火又烧掉了 %s 点生命" % GameText.number(float(_burn_damage_q) / BattleSession.Q)
			&"charge": return "电链增强了，还能多击中一个目标"
			&"mark": return "纸灵正在自动攻击标记的目标"
			&"sleep": return "纸灵又醒了"
			&"crane": return "纸鹤挡住敌弹，反击了敌人"
			&"mist": return "雾中的敌人积累了寒气" if book_id == &"frost" else "火雾让敌人持续掉血"
			&"dodge": return "闪避路径击中了敌人，让它带上了感电" if book_id == &"storm" else "已完成闪避"
			&"ultimate": return {&"frost": "获得了护盾，冰锥击中了敌人", &"flame": "火浪和火域都伤到了敌人", &"storm": "施法引发了电爆和电链", &"spirit": "全部纸灵醒来，攻击了敌人"}[book_id]
	match current_step():
		&"intro": return "输入敌人头顶的词咒" if lesson_id == &"basics" else "完成左边词咒 · 已施法 %s / 3" % mini(_casts, 3)
		&"switch":
			if _switch_phase == 0: return "按 Tab 换到 shard"
			if session.typing.progress == 3: return "按 Tab，保留 sha 换目标"
			return "输入 sha" if session.typing.progress < 3 else "按 Backspace，重新输入 sha"
		&"cancel": return "输入 f，选择 flame" if _seen.has(&"cancelled") else "按 Backspace 取消当前输入" if session.typing.progress > 0 else "先输入 sha"
		&"parry": return "等敌弹靠近，再按 Space"
		&"freeze": return "左边敌人寒气 %d / 91" % session.enemies[0].cold
		&"shatter": return "完成左边词咒，击碎冰冻敌人" if session.enemies[0].frozen_time > 0.0 else "继续攻击左边敌人，把它冻住再击败"
		&"block": return "输入最右边的 %s" % session.enemies[2].word
		&"burn": return "停笔，看看血条上的橙色部分" if session.enemies[0].burn > 10 else "完成左边词咒，点燃敌人"
		&"charge": return "左边敌人感电 %d / 31" % session.enemies[0].shock
		&"mark": return "完成左边词咒，然后停笔"
		&"sleep":
			if _seen.has(&"sleep"): return "完成一个词咒，唤醒纸灵"
			if session.spirit_blade_count() == 0: return "完成左边词咒，先唤醒纸灵"
			return "停笔等待 · 约 %d 秒后纸灵会睡着" % ceili(session.spirit_time)
		&"crane":
			if session.runtime.fields.any(func(field: SpellField) -> bool: return field.effect.kind == &"paper_crane"):
				return "纸鹤已留下，等它挡住敌弹"
			return "现在按 ↓ 闪避" if session.enemies[0].aiming else "等敌人开始瞄准"
		&"mist": return "按 ← 闪避"
		&"dodge": return "按 → 穿过左边敌人" if book_id == &"storm" else "按方向键完成一次闪避"
		&"ultimate": return "继续完成左边词咒" if book_id == &"storm" and _seen.has(&"ultimate") else "终式已释放" if _seen.has(&"ultimate") else "共鸣已满，按一下 Shift"
	return ""


func _emit_step() -> void:
	var title := ""
	var instruction := ""
	match current_step():
		&"intro":
			title = "完成词咒" if lesson_id == &"basics" else "施法与强化"
			instruction = "词咒就是敌人头顶的单词。输入完整单词，就会向它施法。" if lesson_id == &"basics" else {
				&"frost": "冰锥会穿过一条线上的敌人。每第三次施法变成更强的冰矛，能穿过更多敌人。",
				&"flame": "每第三次施法打出焰印，爆炸伤到附近敌人，并留下一团火雾。",
				&"storm": "电链会连着攻击多个敌人。每第三次施法还会引发电爆，伤到目标周围的敌人。",
				&"spirit": "完成词咒会唤醒纸灵，它们会自动攻击。每第三次施法，它们会一起攻击当前目标。",
			}[book_id]
		&"switch":
			title = "换一个目标"
			instruction = "还没开始输入时，Tab 可以换到另一个敌人。" if _switch_phase == 0 else "shade 和 shard 都以 sha 开头。切换时，已经输入的 sha 会保留。"
		&"cancel":
			title = "换到不同开头的单词"
			instruction = "flame 不以 sha 开头，Tab 不会切到它。想改选它，需要先取消当前输入。"
		&"parry":
			title = "御术与反弹"
			instruction = "敌弹靠近时按空格，用御术挡住它。赶在碰到你的那一刻防御，还能把敌弹反弹回去。"
		&"freeze":
			title = "寒气与冻结"
			instruction = "连续攻击左边敌人，让寒气积满，它就会冻住。停得太久寒气会减少，所以尽量集中攻击。"
		&"shatter":
			title = "击碎冻住的敌人"
			instruction = "击败冻住的敌人会触发冻裂，伤到旁边的敌人。集中攻击左边的残血敌人，试着把它冻住再击碎。"
		&"block":
			title = "火弹被谁挡住"
			instruction = "火弹飞向你选中的敌人，途中遇到其他敌人，就会先打中它。"
		&"burn":
			title = "停笔后的余火"
			instruction = "燃烧的敌人会持续掉血。血条上的橙色部分表示预计还会烧掉的生命，可以据此决定是否换目标。"
		&"charge":
			title = "电链变得更强"
			instruction = "连续攻击左边敌人，积累感电。感电足够时，再命中的电链会更强，还能多击中一个敌人。"
		&"mark":
			title = "让纸灵继续攻击"
			instruction = "施法会给目标加上易伤，让它受到更多伤害。纸灵会继续自动攻击它，不用反复下令。"
		&"sleep":
			title = "停笔与唤醒"
			instruction = "停笔一段时间，纸灵会逐只睡着。等一只睡着后，再完成一个词咒，把它唤醒。"
		&"crane":
			title = "纸鹤挡弹反击"
			instruction = "闪避会在原地留下符文纸鹤。等敌人瞄准后按 ↓，让它的弹打向纸鹤：纸鹤挡下一颗敌弹，就会反击发射它的敌人。"
		&"mist":
			title = "冰雾遮蔽" if book_id == &"frost" else "闪避留下火雾"
			instruction = "按 ← 闪避，在原地留下冰雾。雾中的敌人会积累寒气，远处敌人也更难瞄准你；已经射来的敌弹仍要躲开。" if book_id == &"frost" else "按 ← 闪避，在原地留下火雾。旁边的敌人会被点燃，离开火雾后也会继续掉血。"
		&"dodge":
			title = "闪避也能攻击" if book_id == &"storm" else "方向闪避"
			instruction = "闪避路径会伤到沿途敌人，并让它们带上感电。" if book_id == &"storm" else "按方向键朝对应方向闪避，闪避后有1秒不会受伤。闪避次数用完后，需要等它恢复。"
		&"ultimate":
			title = "释放终式"
			instruction = ("输入与防御会积累共鸣，积满后按一下 Shift 释放终式。\n" if lesson_id == &"basics" else "") + {
				&"frost": "你会获得护盾，周围会不断发射冰锥并积累寒气。",
				&"flame": "火浪伤到全场敌人，随后留下持续伤害敌人的火域。",
				&"storm": "周围敌人不断积累感电。再完成一个词咒，每次施法都能引发电爆。",
				&"spirit": "全部纸灵立即醒来，飞得更快、攻击更频繁，伤害也更高。",
			}[book_id]
	if completed:
		instruction = "练习完成。可返回选择其他练习，或开始远征。"
	_last_progress = _progress()
	step_changed.emit(step_index, step_count(), title, instruction, _last_progress, completed)
	goal_changed.emit(ready_to_advance and not completed)
