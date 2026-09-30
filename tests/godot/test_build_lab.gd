extends SceneTree
## Native configuration, physical-key route, frozen build replacement and HDR output.

var lab: BuildLab
var failures := 0
var checks := 0
var evidence: String


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	evidence = "res://.temp/godot-m3/lab-%d" % Time.get_ticks_usec()
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	lab = preload("res://development/build_lab.tscn").instantiate() as BuildLab
	root.add_child(lab)
	await process_frame
	lab.selection = BuildSelection.new()
	lab.show_configuration()
	await process_frame
	check(not lab.launch.disabled and lab.compiler.catalog.ordered_ids().size() == 377, "Full native catalog is available through the formal compiler")
	lab.search.text = "T01"
	lab._refresh_rows()
	await process_frame
	var choose := lab.rows.get_child(0).get_child(0) as Button
	choose.pressed.emit()
	await process_frame
	check("T01" in lab.selection.talents and lab.details.text.contains("晶匣"), "Selecting content exposes its effect and updates the build")
	await capture("configuration")
	for book in BuildCompiler.BOOKS:
		lab.selection = BuildSelection.new()
		lab.selection.book_id = book
		lab.selection.talents = ["T01", "T03", "T13", "T19", "T21", "T22", "T31", "T45", "T46", "T52"]
		lab.selection.assets = {&"R172":1}
		lab.scenario = "resistance"
		lab._start_battle()
		await process_frame
		lab.session.set_physics_process(false)
		for index in lab.session.enemies.size():
			var enemy := lab.session.enemies[index]
			enemy.position = Vector2(0.64 + index * 0.1, 0.46 + index * 0.08)
			enemy.previous_position = enemy.position
			enemy.combat_locked = true
			enemy.hp_q = 1000 * 1024
			enemy.max_hp_q = enemy.hp_q
			enemy.attack_clock = 100.0
			enemy.frozen_time = 100.0
			enemy.word = "abcdefghijkl"
			lab.session.typing.upsert_target(enemy.id, enemy.word)
		lab.session.typing.select_target(lab.session.enemies[0].id)
		for character in "abcdefghijkl":
			key(character.to_upper().unicode_at(0), character.unicode_at(0))
			await process_frame
			lab.session.step(1.0 / 60)
		check(lab.session.manual_characters == 12, "Physical-key router generates only real manual receipts: " + str(book))
		for tick in 16:
			lab.session.step(1.0 / 60)
			await process_frame
		check(not lab.session.enemies[0].resistance_label.is_empty(), "Enemy characteristics are visible without relying on color")
		check(lab.battle.visuals.rule_visuals != null and lab.battle.enemy_words[lab.session.enemies[0].id]._trait != "", "Committed shells / fields / resistance project through native views")
		await capture(str(book) + "-paid-objects")
		var old_shell := lab.session.runtime.stored[0] if not lab.session.runtime.stored.is_empty() else null
		lab._pause()
		await process_frame
		check(paused and lab.inspector.text.contains("来源"), "Pause exposes the actual paid lots and event history")
		await capture(str(book) + "-inspector")
		lab.selection.talents.append("N01-01")
		lab._install_build()
		lab.session.set_physics_process(false)
		lab.session.step(1.0 / 60)
		if old_shell != null:
			check(old_shell.effect.build != lab.session.compiled_build, "Old objects retain their build after a safe-boundary replacement")
		if book == &"flame":
			for enemy in lab.session.enemies:
				enemy.hp_q = 100000 * 1024
				enemy.max_hp_q = enemy.hp_q
			var maximum_step := 0
			var maximum_objects := 0
			for cast_index in 40:
				var chosen := lab.session.enemies[cast_index % 3]
				lab.session.typing.upsert_target(chosen.id, "abcdefghijkl")
				lab.session.typing.select_target(chosen.id)
				for character in "abcdefghijkl": lab.session.typing.feed(character)
				for tick in 18:
					var began := Time.get_ticks_usec()
					lab.session.step(1.0 / 60)
					maximum_step = maxi(maximum_step, Time.get_ticks_usec() - began)
					maximum_objects = maxi(maximum_objects, lab.session.projectiles.size() + lab.session.runtime.stored.size() + lab.session.runtime.ongoing.size() + lab.session.runtime.fields.size() + lab.session.runtime.spirit_attacks.size())
					if tick % 6 == 0: await process_frame
			await capture("flame-content-load")
			check(lab.battle._feedback_labels.size() < 40, "Dense automatic hits aggregate readable damage feedback without losing rule events")
			for tick in 1800: lab.session.step(1.0 / 60)
			check(lab.session.projectiles.is_empty() and lab.session.effects.is_empty() and lab.session.runtime.stored.is_empty() and lab.session.runtime.ongoing.is_empty() and lab.session.runtime.fields.is_empty() and lab.session.runtime.spirit_attacks.is_empty(), "Window content load settles all automatic processes after input stops")
			var surface := "headless" if DisplayServer.get_name() == "headless" else "Forward+ window"
			print("M3 LAB LOAD: peak active=%d max fixed step=%dus; %s local sample" % [maximum_objects, maximum_step, surface])
		lab.session.finish_room(&"abandon")
		check(lab.session.ledger.active_lots().is_empty(), "Abandoned trial recovers every room-owned lot")
		lab.session.result = -1
		lab.show_configuration()
		await process_frame
	await review_interactions()
	paused = false
	lab.queue_free()
	await process_frame
	print("M3 lab: %d checks, %d failures; %s" % [checks, failures, "headless (no images)" if DisplayServer.get_name() == "headless" else "evidence " + evidence])
	quit(0 if failures == 0 else 1)


func review_interactions() -> void:
	lab.selection = BuildSelection.new()
	lab.selection.assets = {&"R017": 1, &"R008": 1}
	lab.scenario = "priority"
	lab._start_battle()
	lab.session.set_physics_process(false)
	lab.session.step(0.2)
	await process_frame
	check(lab.session.enemies[1].aiming and lab.session.enemies[0].kind == &"nib", "Priority scenario presents a real approaching enemy and a ranged warning")
	for tick in 20:
		lab.session.step(1.0 / 60)
		await process_frame
	check(lab.battle.enemy_words[lab.session.enemies[0].id].modulate.a > 0.9, "Priority words finish appearing before visual inspection")
	await capture("priority-encounter")
	var first := lab.session.enemies[0]
	first.hp_q = 1000 * 1024
	first.max_hp_q = first.hp_q
	first.word = "abcdefghijklmn"
	lab.session.typing.upsert_target(first.id, first.word)
	lab.session.typing.select_target(first.id)
	for character in first.word:
		key(character.to_upper().unicode_at(0), character.unicode_at(0))
		await process_frame
		lab.session.step(1.0 / 60)
	var second := lab.session.enemies[1]
	second.word = "abacus"
	lab.session.typing.upsert_target(second.id, second.word)
	lab.session.typing.select_target(second.id)
	for character in "ab":
		key(character.to_upper().unicode_at(0), character.unicode_at(0))
		await process_frame
		lab.session.step(1.0 / 60)
	await process_frame
	check(lab.battle.hint_label.visible and lab.battle.hint_label.text.contains("Ctrl 补全"), "Available assistance is explained beside the active word")
	await capture("assist-ready")
	key(KEY_CTRL)
	await process_frame
	lab.session.step(1.0 / 60)
	check(lab.session.manual_characters == 16 and lab.session.completed_words == 1 and lab.session.typing.progress == 0, "Window Ctrl completes only the human prefix without a second full-manual reward")
	for tick in 60:
		lab.session.step(1.0 / 60)
		await process_frame
	check(lab.session.runtime.actual_damage_q > 0, "Result inspection follows an actual paid hit")
	lab._pause()
	await process_frame
	check(lab.inspector.text.contains("实际扣血") and lab.inspector.text.contains("过量伤害") and lab.inspector.text.contains("实际治疗"), "Inspector separates effective results from resource balances")
	await capture("effective-results")
	for scenario in ["escort", "waves"]:
		lab.selection = BuildSelection.new()
		lab.scenario = scenario
		lab._start_battle()
		lab.session.set_physics_process(false)
		lab.session.step(0.2)
		for tick in 20:
			lab.session.step(1.0 / 60)
			await process_frame
		check(lab.session.enemies.size() == (4 if scenario == "escort" else 3), "Native battle page accepts scenario composition: " + scenario)
		if scenario == "escort": check(lab.battle.wave_label.text.contains("/ 4"), "HUD uses actual enemy count instead of a fixed three")
		await capture(scenario + "-encounter")
	lab.session.finish_room(&"abandon")
	lab.session.result = -1


func key(code: int, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.unicode = unicode_value
	event.pressed = true
	Input.parse_input_event(event)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var encoded := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width(): encoded.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	encoded.save_png(evidence.path_join(label + ".png"))
	print("Captured " + label)
