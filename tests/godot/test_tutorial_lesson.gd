extends SceneTree
## Exercise real typing receipts, paid casts, collisions and queued player actions.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var archive_bytes: Dictionary[String, PackedByteArray] = {}
	var profiles: Array[ProfileState] = []
	var profile_snapshots: Array[Dictionary] = []
	for mode in [&"normal", &"god"]:
		var repository := SaveRepository.new(mode)
		var profile := repository.load_profile()
		profiles.append(profile)
		profile_snapshots.append(profile.to_dict())
		for suffix: String in ["", ".bak", ".tmp"]:
			var path := repository.path + suffix
			archive_bytes[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	for id in TutorialLesson.LESSON_IDS:
		_exercise(id)
		var early_exit := TutorialLesson.create_lesson(id)
		_cast(early_exit)
		_check(not early_exit.completed and early_exit.session.room_result == null, "%s early exit has no settlement" % id)
		early_exit.session.free()
		early_exit.free()
	_retry_entry_points()
	for index in profiles.size():
		_check(profiles[index].to_dict() == profile_snapshots[index], "practice leaves the loaded profile unchanged")
	for path in archive_bytes:
		var current := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		_check(current == archive_bytes[path], "practice completion/exit leaves archive bytes unchanged: %s" % path)
	print("TUTORIAL_LESSON: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _exercise(id: StringName) -> void:
	var lesson := TutorialLesson.create_lesson(id)
	var session := lesson.session
	var notices: Array[Dictionary] = []
	var facts: Array[WordCompletion] = []
	var events: Array[Dictionary] = []
	lesson.step_changed.connect(func(index: int, total: int, title: String, instruction: String, progress: String, complete: bool) -> void:
		notices.append({"index": index, "total": total, "title": title, "instruction": instruction, "progress": progress, "complete": complete})
	)
	session.typing.word_completed.connect(func(fact: WordCompletion) -> void: facts.append(fact))
	session.event_committed.connect(func(event: Dictionary) -> void: events.append(event))
	lesson.refresh()
	_check(notices.size() == 1 and notices[0].index == 0 and notices[0].total == lesson.step_count(), "%s initial step is explicit and zero-based" % id)
	_check(session.get_parent() == null and not session.god_mode and session.compiled_build.asset_instances().is_empty(), "%s isolated baseline session owns no God mode or relics" % id)
	var hp_before := session.enemies[0].hp_q
	_advance(lesson, 120)
	_check(lesson.step_index == 0 and session.manual_characters == 0 and session.enemies[0].hp_q == hp_before, "%s time alone cannot advance or damage the targets" % id)
	session.typing.feed(session.enemies[0].word[0])
	session.step(1.0 / 60.0)
	_check(session.typing.target_id != &"" and session.typing.progress == 1, "%s first character locks a real target" % id)
	session.typing.cancel()
	session.queue_action(&"parry")
	session.queue_action(&"ultimate")
	_advance(lesson, 90)
	_check(lesson.step_index == 0 and not lesson.completed, "%s unfinished input and actions cannot skip the first step" % id)
	if id != &"basics":
		for index in 2:
			_cast(lesson)
		lesson.advance()
		_check(lesson.step_index == 0 and facts.size() == 2 and session.completed_words == 2, "%s requires three real completed words" % id)
	_word(lesson)
	if id in [&"frost", &"flame"]:
		_check(lesson.current_step() == &"intro", "%s third input must wait for its empowered projectile to hit" % id)
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 180)
	_check(lesson.current_step() == &"intro" and lesson.ready_to_advance and facts.size() == (1 if id == &"basics" else 3) and facts.all(func(fact: WordCompletion) -> bool: return fact.fully_manual()), "%s first goal uses the required fully manual paid casts and native impacts" % id)
	if id != &"basics":
		_check(events.any(func(event: Dictionary) -> bool: return event.kind == &"cast" and event.empowered), "%s third cast is genuinely empowered" % id)
	_continue(lesson, &"intro")
	match id:
		&"basics":
			_switching(lesson)
			_defense(lesson, events)
			session.queue_action(&"dodge_right")
			_wait(lesson, func() -> bool: return lesson.ready_to_advance, 120)
			_continue(lesson, &"dodge")
		&"frost": _frost(lesson, events)
		&"flame": _flame(lesson, events)
		&"storm": _storm(lesson, events)
		&"spirit": _spirit(lesson, events)
	_check(lesson.current_step() == &"ultimate" and session.resonance_q == BattleSession.ULTIMATE_COST_Q, "%s real mechanic exercises unlock a filled teaching resonance meter" % id)
	var ultimate_events := events.size()
	_advance(lesson, 180)
	_check(not lesson.completed and not lesson.ready_to_advance and lesson.current_step() == &"ultimate", "%s full resonance does not auto-release or complete" % id)
	session.queue_action(&"ultimate")
	session.step(1.0 / 60.0)
	_check(not lesson.completed and session.ultimate_time > 0.0 and session.resonance_q == 0, "%s Shift commits and pays the actual ultimate before observation" % id)
	if id == &"storm":
		_advance(lesson, 150)
		_check(not lesson.completed and not _impact(events, &"storm_burst", ultimate_events), "storm ultimate field alone cannot replace a paid word burst")
		_word(lesson)
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 300)
	match lesson.book_id:
		&"frost": _check(_impact(events, &"frost_ultimate", ultimate_events) and session.run_state.shield_q > 0, "%s ultimate actually hits and grants shield" % id)
		&"flame": _check(_impact(events, &"flame_wave", ultimate_events) and _impact(events, &"flame_domain", ultimate_events), "flame ultimate has both real wave and domain damage")
		&"storm": _check(_impact(events, &"storm_burst", ultimate_events) and _impact(events, &"storm_arc", ultimate_events), "storm ultimate manual cast has a real burst and electric chain")
		&"spirit": _check(_impact(events, &"spirit_blade", ultimate_events) and session.spirit_blade_count() == session.spirit_capacity(), "spirit ultimate wakes a full flock and lands real frenzied hits")
	_continue(lesson, &"ultimate")
	_check(lesson.completed and not session.is_physics_processing() and session.result == 0 and session.room_result == null, "%s completion pauses practice without a formal victory" % id)
	_check(session.threats.is_empty() and session.hazards.is_empty() and session.enemies.size() == 3, "%s ends with no danger or natural spawns" % id)
	_check(notices[-1].complete and notices[-1].index == lesson.step_count() - 1, "%s final interface explicitly reports completion" % id)
	session.free()
	lesson.free()
	var repeat := TutorialLesson.create_lesson(id)
	_check(repeat.step_index == 0 and not repeat.completed and repeat.session.manual_characters == 0 and repeat.session.resonance_q == 0, "%s repeat starts a fresh independent practice" % id)
	repeat.session.free()
	repeat.free()


func _retry_entry_points() -> void:
	# Retry uses a fresh session at the current step, without earlier casts or statuses.
	for id: StringName in [&"frost", &"flame", &"spirit", &"storm"]:
		var step: StringName = {&"frost": &"shatter", &"flame": &"burn", &"spirit": &"sleep", &"storm": &"dodge"}[id]
		var lesson := TutorialLesson.create_lesson(id, TutorialLesson.STEPS[id].find(step))
		var session := lesson.session
		_check(lesson.current_step() == step and not lesson.ready_to_advance and session.manual_characters == 0, "%s retry preserves the requested step with no fabricated input" % id)
		_advance(lesson, 120)
		_check(not lesson.ready_to_advance, "%s retry does not complete from staged prerequisites alone" % id)
		match id:
			&"frost":
				for attempt in 6:
					if lesson.ready_to_advance: break
					_cast(lesson)
			&"flame":
				_word(lesson)
				_wait(lesson, func() -> bool: return lesson.ready_to_advance, 180)
			&"spirit":
				_word(lesson)
				var awake := session.spirit_blade_count()
				_wait(lesson, func() -> bool: return session.spirit_blade_count() < awake, 900)
				_check(not lesson.ready_to_advance and lesson._progress().contains("唤醒"), "fresh sleep retry still needs a manual wake after actual sleep")
				_word(lesson)
				_wait(lesson, func() -> bool: return lesson.ready_to_advance, 120)
			&"storm":
				session.queue_action(&"dodge_right")
				_wait(lesson, func() -> bool: return lesson.ready_to_advance, 120)
		_check(lesson.ready_to_advance, "%s can finish its retried mechanic through real combat actions" % id)
		session.free()
		lesson.free()


func _switching(lesson: TutorialLesson) -> void:
	var session := lesson.session
	var typing := session.typing
	_check(lesson.current_step() == &"switch" and session.enemies.map(func(enemy: BattleEnemy) -> String: return enemy.word) == ["shade", "shard", "flame"], "switching has a deterministic visible example")
	_advance(lesson, 60)
	_check(not lesson.ready_to_advance, "time cannot satisfy a target-switch exercise")
	_word(lesson)
	_advance(lesson, 35)
	_check(lesson._switch_phase == 0 and typing.word == "shade" and not lesson.ready_to_advance, "finishing an example word restages the exercise instead of making it unwinnable")
	typing.cycle_target()
	session.step(1.0 / 60.0)
	_check(lesson._switch_phase == 1 and typing.word == "shard", "empty-input Tab updates the next instruction immediately")
	for letter in "sha":
		typing.feed(letter)
		session.step(1.0 / 60.0)
	_check(not lesson.ready_to_advance, "shared letters alone do not prove a switch")
	typing.cycle_target()
	session.step(1.0 / 60.0)
	_check(typing.word == "shade" and typing.progress == 3 and lesson.ready_to_advance, "shared-opening switch preserves the actual three typed letters")
	_continue(lesson, &"switch")
	typing.feed("f")
	typing.cycle_target()
	session.step(1.0 / 60.0)
	_check(typing.word.begins_with("sha") and not lesson.ready_to_advance, "a different opening cannot bypass cancellation")
	typing.cancel()
	typing.feed("f")
	session.step(1.0 / 60.0)
	_check(typing.word == "flame" and typing.progress == 1 and lesson.ready_to_advance, "cancellation and a new first letter select the actual different-opening target")
	_continue(lesson, &"cancel")
	_check(typing.progress == 0 and typing.target_id == &"", "the next mechanism begins without leftover partial input")


func _defense(lesson: TutorialLesson, events: Array[Dictionary]) -> void:
	var session := lesson.session
	# Let the first real shot land. Damage must exist, and failure must not advance.
	for frame in 900:
		if events.any(func(event: Dictionary) -> bool: return event.kind == &"enemy_attack" and event.outcome == &"hit"):
			break
		session.step(1.0 / 60.0)
	_check(session.player_hp_q < session.player_max_hp_q and lesson.current_step() == &"parry" and not lesson.ready_to_advance, "failed defense deals real damage and remains retryable")
	_check(events.any(func(event: Dictionary) -> bool: return event.kind == &"warning"), "practice incoming shot uses the enemy's real warning")
	for frame in 1800:
		if lesson.ready_to_advance: break
		for threat in session.threats:
			if not threat.reflected and ((threat.position - session.player_position) * BattleSession.ARENA_SIZE).length() < 40.0 and session.parry_cooldown <= 0.0:
				session.queue_action(&"parry")
				break
		session.step(1.0 / 60.0)
	_check(events.any(func(event: Dictionary) -> bool: return event.kind == &"enemy_attack" and event.outcome == &"parry"), "basics advances on an actual projectile parry")
	_continue(lesson, &"parry")


func _frost(lesson: TutorialLesson, events: Array[Dictionary]) -> void:
	var session := lesson.session
	_check(lesson.current_step() == &"freeze", "frost intro waits for reinforced piercing impacts")
	var freeze_events := events.size()
	_advance(lesson, 120)
	_check(lesson.current_step() == &"freeze" and not lesson.ready_to_advance, "frost idle time cannot fabricate a freeze")
	for attempt in 5:
		if lesson.ready_to_advance: break
		_word(lesson)
		_wait(lesson, func() -> bool: return not session.enemies[0].word_pending or lesson.ready_to_advance, 120)
	_continue(lesson, &"freeze")
	_check(lesson.current_step() == &"shatter" and session.enemies[0].frozen_time > 0.0 and session.enemies[0].hp_q == BattleSession.Q, "frost prepares a fragile target only after real freezing")
	_check(events.slice(freeze_events).any(func(event: Dictionary) -> bool: return event.kind == &"freeze"), "frost freeze is an actual committed control effect")
	var shatter_events := events.size()
	# Reading the instruction can outlast freezing; a failed kill must remain retryable.
	_advance(lesson, 180)
	_check(lesson.current_step() == &"shatter" and session.enemies[0].frozen_time <= 0.0, "frost shatter allows a player to read past the original freeze window")
	_word(lesson, 0, 30)
	_wait(lesson, func() -> bool: return not session.enemies[0].word_pending, 180)
	_check(lesson.current_step() == &"shatter" and not lesson.ready_to_advance and session.enemies[0].alive() and not _impact(events, &"frost_shatter", shatter_events), "an unfrozen failed kill cannot fake shatter and restores a retryable target")
	for attempt in 5:
		if lesson.ready_to_advance: break
		_word(lesson)
		_wait(lesson, func() -> bool: return not session.enemies[0].word_pending or lesson.ready_to_advance, 120)
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 120)
	_check(_impact(events, &"frost_shatter", shatter_events) and events.slice(shatter_events).any(func(event: Dictionary) -> bool: return event.kind == &"death"), "frozen death causes real nearby shatter damage")
	_continue(lesson, &"shatter")
	_mist(lesson, events, &"ice_mist")


func _flame(lesson: TutorialLesson, events: Array[Dictionary]) -> void:
	var session := lesson.session
	_check(lesson.current_step() == &"block", "flame intro waits for the real empowered explosion")
	_advance(lesson, 120)
	_check(lesson.current_step() == &"block" and not lesson.ready_to_advance, "flame cannot demonstrate blocking without a rear-target word")
	var blocked_events := events.size()
	var rear_hp := session.enemies[2].hp_q
	_word(lesson, 2)
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 180)
	_check(_impact(events, &"flame_burst", blocked_events, session.enemies[0].id) and session.enemies[2].hp_q == rear_hp, "a paid rear-target fireball is genuinely blocked by the front target")
	# Reading the completed explanation must not make the next exercise unwinnable.
	_advance(lesson, 1800)
	_check(session.enemies[0].burn <= 10, "reading delay exhausts the previous fireball's real burn")
	_continue(lesson, &"block")
	_check(lesson._progress().contains("点燃") and not lesson.ready_to_advance, "expired residual burn asks for new input instead of waiting forever")
	_word(lesson)
	var burn_events := events.size()
	var manual := session.manual_characters
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 180)
	_check(_impact(events, &"flame_burn", burn_events) and session.manual_characters == manual, "flame residual burn damages after input stops")
	_check(lesson._burn_ticks >= 3 and session.enemies[0].hp_q < session.enemies[0].max_hp_q * 0.95, "burn practice waits for multiple real health losses on a readable scale")
	_continue(lesson, &"burn")
	_check(session.enemies[0].max_hp_q == TutorialLesson.TRAINING_HEALTH * BattleSession.Q, "later mechanics restore the durable practice target")
	_mist(lesson, events, &"fire_field")


func _mist(lesson: TutorialLesson, events: Array[Dictionary], kind: StringName) -> void:
	var session := lesson.session
	_check(lesson.current_step() == &"mist", "%s reaches its native mist exercise" % lesson.lesson_id)
	_advance(lesson, 120)
	_check(lesson.current_step() == &"mist" and not lesson.ready_to_advance, "%s mist needs a player dodge and actual target effects" % lesson.lesson_id)
	# Geometry fixture: move the target outside the real mist, without inventing effects.
	session.enemies[0].position = Vector2(0.8, 0.2)
	session.enemies[0].previous_position = session.enemies[0].position
	session.queue_action(&"dodge_left")
	session.step(1.0 / 60.0)
	_check(session.runtime.fields.any(func(field: SpellField) -> bool: return field.effect.kind == kind), "%s failed attempt still creates a real mist" % lesson.lesson_id)
	_advance(lesson, 240)
	_check(lesson.current_step() == &"mist" and not lesson.ready_to_advance, "%s creating an empty mist cannot complete the exercise" % lesson.lesson_id)
	# Put the same live target into the next dodge's origin for a real retry.
	session.enemies[0].position = session.player_position + Vector2(65 if lesson.book_id == &"frost" else 50, 0) / BattleSession.ARENA_SIZE
	session.enemies[0].previous_position = session.enemies[0].position
	var mist_events := events.size()
	session.queue_action(&"dodge_left")
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 180)
	if lesson.book_id == &"flame":
		_check(_impact(events, &"flame_burn", mist_events), "flame mist completes on real burn damage rather than field creation")
	else:
		_check(session.enemies[0].cold > 0 and session.runtime.obscures(session.enemies[0]), "ice mist actually applies cold and obscures its target before progression")
	_continue(lesson, &"mist")
	_advance(lesson, 10)
	_check(session.player_position.is_equal_approx(Vector2(0.5, 0.5)), "%s staging ends the old dodge instead of drifting back to its prior endpoint" % lesson.lesson_id)


func _storm(lesson: TutorialLesson, events: Array[Dictionary]) -> void:
	var session := lesson.session
	_check(lesson.current_step() == &"charge", "storm intro includes a real third-cast burst and chain impacts")
	_advance(lesson, 120)
	_check(lesson.current_step() == &"charge" and not lesson.ready_to_advance, "storm charge cannot come from idle time")
	var charge_events := events.size()
	for attempt in 5:
		if lesson.ready_to_advance: break
		_cast(lesson)
	_check(lesson.current_step() == &"charge" and lesson.ready_to_advance and _impact(events, &"storm_arc", charge_events), "storm charge requires repeated real chain hits")
	var primary_hits: Array[int] = []
	for event in events.slice(charge_events):
		if event.kind == &"impact" and event.source == &"storm_arc" and event.enemy == session.enemies[0].id:
			primary_hits.append(int(event.applied_q))
	_check(primary_hits.size() >= 2 and primary_hits[1] > roundi(primary_hits[0] * 1.2), "charged storm arc actually increases primary damage beyond ordinary cast cadence")
	_continue(lesson, &"charge")
	session.queue_action(&"dodge_down")
	_advance(lesson, 180)
	_check(lesson.current_step() == &"dodge" and not lesson.ready_to_advance, "a storm dodge whose path misses the targets cannot advance")
	session.queue_action(&"dodge_up")
	_advance(lesson, 180)
	_check(lesson.current_step() == &"dodge" and not lesson.ready_to_advance, "returning to center still needs an actual lightning path hit")
	var dodge_events := events.size()
	session.queue_action(&"dodge_right")
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 120)
	_check(_impact(events, &"storm_dodge", dodge_events), "storm right dodge lands actual path damage")
	_continue(lesson, &"dodge")


func _spirit(lesson: TutorialLesson, events: Array[Dictionary]) -> void:
	var session := lesson.session
	_check(lesson.current_step() == &"mark", "spirit intro includes real cross-strike impacts")
	var mark_events := events.size()
	_word(lesson)
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 240)
	_check(_impact(events, &"spirit_mark", mark_events) and _impact(events, &"spirit_blade", mark_events) and session.enemies[0].vulnerability > 0, "spirit marking raises vulnerability and guides actual autonomous hits")
	_advance(lesson, 1500)
	_check(session.spirit_blade_count() == 0, "reading delay lets all the actual spirits fall asleep")
	_continue(lesson, &"mark")
	_check(lesson._progress().contains("先唤醒") and not lesson.ready_to_advance, "sleeping flock on entry asks for a real summon before observing sleep")
	_word(lesson)
	_check(session.spirit_blade_count() > 0 and not lesson.ready_to_advance, "restarting the sleep example summons spirits without fabricating sleep or completion")
	var peak := session.spirit_blade_count()
	var manual := session.manual_characters
	_wait(lesson, func() -> bool: return session.spirit_blade_count() < peak, 900)
	_check(lesson.current_step() == &"sleep" and not lesson.ready_to_advance and session.spirit_blade_count() < peak and session.manual_characters == manual, "spirit actually sleeps after input stops, and does not auto-wake")
	var wake_events := events.size()
	_word(lesson)
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 120)
	_check(events.slice(wake_events).any(func(event: Dictionary) -> bool: return event.kind == &"spirit_summon"), "a new fully manual word really wakes a sleeping spirit")
	_continue(lesson, &"sleep")
	_check(lesson.current_step() == &"crane" and not session.enemies[0].aiming, "crane waits for an actual new enemy warning")
	_advance(lesson, 20)
	_check(lesson.current_step() == &"crane" and not lesson.ready_to_advance, "idle crane time cannot invent an interception")
	_wait(lesson, func() -> bool: return session.enemies[0].aiming and session.enemies[0].attack_clock <= 0.3 and session.dodge_charges >= 1.0, 900)
	_check(session.enemies[0].aiming, "spirit retry waits for real committed aiming")
	var crane_events := events.size()
	session.queue_action(&"dodge_down")
	session.step(1.0 / 60.0)
	_check(lesson.current_step() == &"crane" and not lesson.ready_to_advance and session.runtime.fields.any(func(field: SpellField) -> bool: return field.effect.kind == &"paper_crane"), "creating a crane alone cannot complete interception")
	_wait(lesson, func() -> bool: return lesson.ready_to_advance, 600)
	_check(_impact(events, &"paper_crane", crane_events) and events.slice(crane_events).any(func(event: Dictionary) -> bool: return event.kind == &"spirit_intercept"), "a real incoming projectile is intercepted and reflects real crane damage")
	_continue(lesson, &"crane")


func _cast(lesson: TutorialLesson) -> void:
	_word(lesson)
	_advance(lesson, 35)


func _word(lesson: TutorialLesson, target_index: int = 0, frames_per_character: int = 1) -> void:
	var session := lesson.session
	var target := session.enemies[target_index]
	for frame in 90:
		if session.typing._targets.has(target.id): break
		session.step(1.0 / 60.0)
	_check(target.alive() and session.typing._targets.has(target.id), "%s requested target exposes a living word" % lesson.lesson_id)
	session.typing.select_target(target.id)
	var word := session.typing.word
	for letter in word:
		session.typing.feed(letter)
		_advance(lesson, frames_per_character)


func _wait(lesson: TutorialLesson, predicate: Callable, frames: int) -> void:
	for frame in frames:
		if bool(predicate.call()) or lesson.completed: break
		lesson.session.step(1.0 / 60.0)


func _impact(events: Array[Dictionary], source: StringName, start: int = 0, target: StringName = &"") -> bool:
	for index in range(start, events.size()):
		var event := events[index]
		if event.kind == &"impact" and event.source == source and int(event.applied_q) > 0 and (target == &"" or event.enemy == target):
			return true
	return false


func _advance(lesson: TutorialLesson, frames: int) -> void:
	for frame in frames:
		if lesson.completed: break
		lesson.session.step(1.0 / 60.0)


func _continue(lesson: TutorialLesson, expected: StringName) -> void:
	_check(lesson.current_step() == expected and lesson.ready_to_advance, "%s %s completes its actual goal before explicit continuation" % [lesson.lesson_id, expected])
	var index := lesson.step_index
	_advance(lesson, 12)
	_check(lesson.step_index == index and not lesson.completed and lesson.ready_to_advance, "%s %s keeps its explanation after success until Next is selected" % [lesson.lesson_id, expected])
	lesson.advance()
	_check(lesson.completed if index == lesson.step_count() - 1 else lesson.step_index == index + 1, "%s %s advances exactly once through the explicit interface" % [lesson.lesson_id, expected])


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
