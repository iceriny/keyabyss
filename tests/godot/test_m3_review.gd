extends SceneTree

const Q := 1024
const WORD := "abcdefghijklmn"
const FIXTURE := preload("res://tests/godot/combat_fixture.gd")
var checks := 0
var failures := 0
var sessions: Array[BattleSession] = []
var active: BattleSession
var router: InputRouter
var compiler := BuildCompiler.new()
var assist_actions := 0


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func room(assets: Dictionary[StringName, int] = {}) -> BattleSession:
	var choice := BuildSelection.new()
	choice.book_id = &"frost"
	choice.assets = assets
	var compiled := compiler.compile(choice)
	check(compiled.success(), "Review fixture compiles with only its necessary relics")
	if not compiled.success(): return null
	var request := BattleStartRequest.new()
	request.build = compiled.build
	request.vocabulary = [VocabularyEntry.new(WORD, "测试")]
	request.encounter = BattleEncounter.new()
	request.encounter.wave_count = 1
	var session := BattleSession.new()
	sessions.append(session)
	root.add_child(session)
	session.set_physics_process(false)
	session.start(request)
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.combat_locked = true
		enemy.position = Vector2(0.68 + index * 0.07, 0.43 + index * 0.06)
		enemy.previous_position = enemy.position
		enemy.hp_q = 5000 * Q
		enemy.max_hp_q = enemy.hp_q
		enemy.resistances = [0, 0, 0, 0, 0]
		enemy.frozen_time = 100.0
		enemy.attack_clock = 100.0
		session.typing.upsert_target(enemy.id, WORD)
	active = session
	router.typing = session.typing
	router.configure(InputRouter.Context.TYPING)
	return session


func _action(action: StringName) -> void:
	if action == &"assist": assist_actions += 1
	active.queue_action(action)


func key(code: int, unicode: int = 0, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	event.echo = echo
	event.ctrl_pressed = code == KEY_CTRL
	Input.parse_input_event(event)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	released.echo = false
	Input.parse_input_event(released)
	await process_frame


func type_text(text: String) -> void:
	for character in text: await key(character.to_upper().unicode_at(0), character.unicode_at(0))


func manual_word(session: BattleSession) -> void:
	session.typing.select_target(session.enemies[0].id)
	await type_text(WORD)
	session.step(1.0 / 60)


func prefix(session: BattleSession) -> void:
	session.typing.select_target(session.enemies[1].id)
	await type_text("ab")
	session.step(1.0 / 60)


func _input_completion() -> void:
	var session := room({&"R017": 1})
	await manual_word(session)
	check(session.completed_words == 1 and session.manual_characters == 14, "Fourteen physical Unicode inputs complete exactly one manual word")
	check(session.runtime._available_work() == 14 * Q, "Manual completion funds assistance through the real typing chain")
	await prefix(session)
	check(session.typing.progress == 2 and session.completed_words == 1, "Real prefix remains editable instead of automatically truncating")
	var before := session.runtime._available_work()
	var count := assist_actions
	await key(KEY_CTRL)
	await key(KEY_CTRL)
	check(assist_actions == count + 2 and session.typing.progress == 2, "Ctrl reaches the router but waits for the fixed step")
	session.step(1.0 / 60)
	check(session.typing.progress == 0 and session.manual_characters == 16 and session.completed_words == 1, "Assisted letters add no physical receipts or full manual word reward")
	check(session.runtime._available_work() == before - 12 * Q + 2 * Q, "Duplicate queued Ctrl consumes one assistance fee and only supplies the human prefix")


func _stale_intents() -> void:
	for change in ["cancel", "target", "word", "continue"]:
		var session := room({&"R017": 1})
		await manual_word(session)
		await prefix(session)
		var before := session.runtime._available_work()
		await key(KEY_CTRL)
		match change:
			"cancel": session.typing.cancel()
			"target": session.typing.select_target(session.enemies[2].id)
			"word":
				session.typing.cancel()
				session.typing.upsert_target(session.enemies[1].id, "abacus")
				session.typing.select_target(session.enemies[1].id)
				await type_text("ab")
			"continue": await type_text("c")
		session.step(1.0 / 60)
		check(session.runtime._available_work() == before and session.completed_words == 1, "Changed %s invalidates old Ctrl intent without payment" % change)
		if change == "continue": check(session.typing.progress == 3, "Continued physical input survives stale assistance")
	var poor := room({&"R017": 1})
	await prefix(poor)
	await key(KEY_CTRL)
	await key(KEY_CTRL)
	poor.step(1.0 / 60)
	check(poor.typing.progress == 2 and poor.runtime._available_work() == 0 and poor.completed_words == 0, "Insufficient assistance keeps progress and does not manufacture work")
	await type_text(WORD.substr(2))
	poor.step(1.0 / 60)
	check(poor.completed_words == 1 and poor.manual_characters == 14, "Rejected assistance still permits ordinary manual completion")


func _input_ownership() -> void:
	var session := room({&"R017": 1})
	await manual_word(session)
	await prefix(session)
	var before := session.runtime._available_work()
	var count := assist_actions
	await key(KEY_CTRL, 0, true)
	session.step(1.0 / 60)
	check(assist_actions == count and session.typing.progress == 2 and session.runtime._available_work() == before, "Ctrl echo cannot request or charge assistance")
	for context: InputRouter.Context in [InputRouter.Context.MENU, InputRouter.Context.MODAL]:
		router.configure(context)
		await key(KEY_CTRL)
		session.step(1.0 / 60)
		check(assist_actions == count and session.runtime._available_work() == before, "Menu and modal contexts retain input ownership")
	router.configure(InputRouter.Context.MENU)
	paused = true
	await key(KEY_CTRL)
	paused = false
	check(assist_actions == count, "Paused menu cannot queue assistance")
	router.configure(InputRouter.Context.TYPING)
	var editor := LineEdit.new()
	root.add_child(editor)
	editor.grab_focus()
	check(root.gui_get_focus_owner() == editor, "Text ownership fixture has actual GUI focus")
	await key(KEY_CTRL)
	session.step(1.0 / 60)
	check(assist_actions == count and session.typing.progress == 2 and session.runtime._available_work() == before, "Focused native text editing cannot trigger assistance")
	editor.release_focus()
	editor.queue_free()


func _counter_supply() -> void:
	var empty := room({&"R008": 1})
	for index in 3:
		var response := empty.runtime.counter("empty-counter:%s" % index, (100 + index * 1000) * Q, empty.enemies[0].id, empty.player_position)
		var total := response.lot.amount_q
		for reserved in empty.runtime._counter_reserve: total += reserved.lot.amount_q
		check(response.lot.amount_q <= Q and total <= (index + 1) * Q and empty.runtime._available_work() == 0, "Repeated unfunded counters remain small regardless of incoming damage")
	var funded := room({&"R008": 1})
	await manual_word(funded)
	var before := funded.runtime._available_work()
	var response := funded.runtime.counter("funded-counter", 10000 * Q, funded.enemies[0].id, funded.player_position)
	var funded_total := response.lot.amount_q
	for reserved in funded.runtime._counter_reserve: funded_total += reserved.lot.amount_q
	var expected := Q + 6 * 4 * (Q + funded.compiled_build.value(&"parry_efficiency_q"))
	check(before == 14 * Q and funded.runtime._available_work() == before - 6 * Q and funded_total == expected, "Typing pays at most six work units and followup shares the same converted response")
	var balance := funded.runtime._available_work()
	var spent := funded.ledger.raw_spent_q
	check(funded.runtime.counter("funded-counter", 100000 * Q, funded.enemies[0].id, funded.player_position) == null and funded.runtime._available_work() == balance and funded.ledger.raw_spent_q == spent, "Replayed enemy attack ID cannot claim another funded counter")
	var comparison := room({&"R008": 1})
	await manual_word(comparison)
	var smaller := comparison.runtime.counter("small-counter", 2 * Q, comparison.enemies[0].id, comparison.player_position)
	var smaller_total := smaller.lot.amount_q
	for reserved in comparison.runtime._counter_reserve: smaller_total += reserved.lot.amount_q
	check(smaller_total == funded_total, "Equal typing supply creates equal counter budget against small and huge enemy attacks")


func _effective_statistics() -> void:
	var session := room()
	var enemy := session.enemies[0]
	enemy.hp_q = 5 * Q
	FIXTURE.hit(session, enemy, 100 * Q, &"counter", session.player_position)
	check(session.runtime.actual_damage_q == 5 * Q and session.runtime.overkill_damage_q == 95 * Q, "One hundred damage against five HP records five effective and ninety-five overkill")
	check(session.runtime.damage_by_source.get(&"counter", 0) == 5 * Q, "Source contribution reports actual HP removed")
	session.runtime.heal(100 * Q)
	check(session.runtime.healed_q == 0, "Healing at full life adds no effective healing")
	session.player_hp_q -= 3 * Q
	session.runtime.heal(100 * Q)
	check(session.runtime.healed_q == 3 * Q and session.player_hp_q == session.player_max_hp_q, "Effective healing is capped by missing life")
	var unused := FIXTURE.effect(session, &"counter", session.enemies[1].id, 7 * Q, 0.0, session.player_position)
	session.effects.append(unused)
	var result := session.finish_room(&"abandon")
	check(result.actual_damage_q == 5 * Q and result.overkill_damage_q == 95 * Q and result.healed_q == 3 * Q and result.unused_power_q == 7 * Q, "Room result copies effective, overkill, healing and unused outcomes")
	session.runtime.damage_by_source[&"counter"] = 999 * Q
	check(result.damage_by_source.get(&"counter", 0) == 5 * Q, "Room result source accounting is an independent snapshot")


func _run() -> void:
	router = InputRouter.new()
	router.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(router)
	router.action_requested.connect(_action)
	await process_frame
	await _input_completion()
	await _stale_intents()
	await _input_ownership()
	await _counter_supply()
	_effective_statistics()
	router.set_process_input(false)
	for session in sessions:
		if session.room_result == null: session.finish_room(&"abandon")
		check(session.ledger.active_lots().is_empty(), "Review room cleans every non-handoff resource")
		session.queue_free()
	router.queue_free()
	await process_frame
	print("M3 review: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
