extends SceneTree
## Runtime regression for input ownership, first/repeat entry, and animated layers.
var app: KeyabyssApp
var failures: int = 0
var evidence: String
var cues: Array[String] = []
var theme_notifications := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--battle-transitions" in OS.get_cmdline_user_args():
		await _review_battle_transitions()
		return
	if "--async-saves" in OS.get_cmdline_user_args():
		await _review_async_saves()
		return
	if "--page-stalls" in OS.get_cmdline_user_args():
		await _review_page_stalls()
		return
	if "--book-switch" in OS.get_cmdline_user_args():
		await _review_book_switch()
		return
	evidence = "res://.temp/legacy-ui-review/presentation-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	await _create_app()
	var gate := _gate()
	_check(gate != null and not gate.can_skip, "first visit owns input and cannot skip the ritual")
	gate.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	await _key(KEY_F11)
	_check(app.settings.fullscreen and not gate.started and cues.is_empty(), "F11 changes display without starting the ritual")
	await _key(KEY_F11)
	await create_timer(.15).timeout
	await _capture("01-ready")
	await _key(KEY_A,97)
	await create_timer(.42).timeout
	await _key(KEY_ENTER)
	_check(is_instance_valid(gate) and not gate.skipping and app.router.buffer.is_empty(), "entry gesture and early second key cannot leak into menu commands")
	await _capture("02-first-wave")
	while is_instance_valid(gate) and gate.elapsed < 2.65:
		await process_frame
	await _capture("03-heavy-wave")
	while is_instance_valid(gate):
		await process_frame
	_check(cues == ["ui.enter","ui.ritualRise","ui.ritualImpact","ui.ritualChime"], "ritual cues occur once in source order")
	_check(app.route == "home" and app.router.context == InputRouter.Context.MENU and app.settings.intro_complete, "ritual hands input back to the archive and persists completion")
	await _capture("04-arrived")
	var rear_book := app.archive.cards[3]
	var rear_material := app.archive.artworks[3].material as ShaderMaterial
	var resting_blur: float = rear_material.get_shader_parameter("blur_pixels")
	await _mouse_at(root.get_screen_transform() * rear_book.get_global_transform() * (rear_book.size * .5))
	await create_timer(.08).timeout
	_check(app.archive.hover_amount[3] > 0.0 and app.archive.hover_amount[3] < .9 and float(rear_material.get_shader_parameter("blur_pixels")) < resting_blur, "hover clarity and brightness ease toward the pointer instead of snapping")
	await create_timer(.65).timeout
	_check(app.archive.hover_amount[3] > .98 and float(rear_material.get_shader_parameter("blur_pixels")) < .1, "hovered rear book becomes clear after settling")
	await _capture("04-hover-clear")
	await _mouse_at(Vector2(5,5))
	await create_timer(.08).timeout
	_check(app.archive.hover_amount[3] > .05 and app.archive.hover_amount[3] < .95, "pointer exit smoothly restores depth blur")
	var menu_button := app.archive.menu.find_child("Vocab", true, false) as OpenButton
	await _mouse_at(root.get_screen_transform() * menu_button.get_global_transform() * (menu_button.size * 0.5))
	await create_timer(.4).timeout
	await _capture("04-menu-hover")
	app.queue_free()
	await process_frame
	await _create_app()
	gate = _gate()
	cues.clear()
	gate.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	_check(gate.can_skip, "repeat visit enables skip from persisted completion")
	await _key(KEY_ENTER)
	await create_timer(.4).timeout
	await _key(KEY_ENTER)
	await create_timer(.75).timeout
	_check(not is_instance_valid(gate) and cues == ["ui.enter"], "skip dissolves the current frame and cancels remaining ritual cues")
	app.settings.reduce_motion = true
	app.settings.save_settings()
	app.queue_free()
	await process_frame
	await _create_app()
	gate = _gate()
	cues.clear()
	gate.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	await _key(KEY_ENTER)
	await create_timer(.35).timeout
	_check(not is_instance_valid(gate) and cues == ["ui.enter"] and app.archive.modulate.a == 1., "reduced motion reaches a visible interactive home without light waves")
	app.archive.set_prepared(true)
	await process_frame
	_check(app.archive.left_wing.is_visible_in_tree() and app.archive.deployment == 1. and app.archive.title_group.modulate.a == 0., "reduced motion unfolds readable preparation without displacement or overlapping background text")
	await _capture("05-prepared")
	var original_theme := app.root.theme
	var original_color := app.archive.accent
	var room_rect := app.archive.effects._book_plane.get_rect()
	var emblem_position := app.archive.seal_layers[0].position
	app.archive.select_book(1)
	_check(app.archive.accent.is_equal_approx(original_color), "book selection starts from the displayed accent without a color jump")
	_check(app.archive.effects._book_plane.get_rect() == room_rect and app.archive.seal_layers[1].position == emblem_position and app.archive.seal_weights[0] == 1.0, "room geometry stays anchored while school emblems begin from existing weights")
	await create_timer(.3).timeout
	var intermediate := app.archive.accent
	var intermediate_weights := app.archive.seal_weights.duplicate()
	_check(intermediate_weights[0] > 0.0 and intermediate_weights[1] > 0.0 and is_equal_approx(intermediate_weights[0]+intermediate_weights[1],1.0), "school emblems crossfade without resetting the room or doubling opacity")
	_check(not intermediate.is_equal_approx(original_color) and not intermediate.is_equal_approx(ArchiveHome.BOOKS[1].color), "theme passes through intermediate colors even with reduced motion")
	_check(app.root.theme == original_theme and app.root.theme.get_color("accent", "Archive").is_equal_approx(intermediate) and (app.archive.floor_plane.material as ShaderMaterial).get_shader_parameter("school_color").is_equal_approx(intermediate), "UI and scenery share the interpolated accent without replacing the theme")
	app.archive.select_book(2)
	_check(app.archive.accent.is_equal_approx(intermediate), "interrupted color transition resumes from its current color")
	_check(app.archive.seal_weights == intermediate_weights, "rapid selection preserves the currently blended emblems")
	app._guide()
	_check(app.page.accent.is_equal_approx(intermediate), "page opened during transition inherits its current color")
	await create_timer(.3).timeout
	await _capture("06-theme-transition")
	await create_timer(1.0).timeout
	_check(app.archive.accent.is_equal_approx(ArchiveHome.BOOKS[2].color) and app.page.accent.is_equal_approx(app.archive.accent), "archive and open page settle on the last selected book color")
	_check(is_equal_approx(app.archive.seal_weights[2],1.0) and not app.archive.seal_layers[0].visible and app.archive.effects._book_plane.get_rect() == room_rect, "old emblems retire and the room remains fixed after transition")
	print("Presentation checks: %d failure(s) | %s" % [failures,evidence])
	quit(0 if failures == 0 else 1)

func _review_battle_transitions() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1920, 1080)
	var preparation := load("res://ui/scenes/render_preparation.tscn").instantiate() as RenderPreparation
	var feedback := load("res://ui/scenes/loading_feedback.tscn").instantiate() as LoadingFeedback
	root.add_child(feedback)
	root.add_child(preparation)
	await preparation.prepare(feedback)
	feedback.hide()
	var directory := "res://.temp/battle-transitions-20261019/%d" % Time.get_ticks_usec()
	var results: Array[Dictionary] = []
	for extreme: bool in [false, true]:
		var group := "extreme" if extreme else "baseline"
		evidence = directory.path_join(group)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
		await _create_app()
		if is_instance_valid(app.welcome_gate):
			app.welcome_gate.queue_free()
			app.welcome_gate = null
		app.archive.modulate.a = 1.0
		app._home(false)
		app.settings.reduce_motion = false
		var frames: Array[float] = []
		var clock := {"last": Time.get_ticks_usec()}
		var sample := func() -> void:
			var now := Time.get_ticks_usec()
			frames.append((now - int(clock.last)) / 1000.0)
			clock.last = now
		DebugLog._spans.clear()
		process_frame.connect(sample)
		app._start_battle()
		while app.route not in ["battle", "pause"]: await process_frame
		process_frame.disconnect(sample)
		results.append({"group": group, "phase": "departure", "frames_ms": frames.duplicate(), "max_frame_ms": frames.max()})
		if app.route == "pause": app._resume()
		var session := app.battle.session
		session.set_physics_process(false)
		var count := 18 if extreme else 6
		while session.enemies.size() < count: session._spawn_enemy(FirstVisitSetup.ENEMY_TYPES[0], Vector2(.5, .5))
		for index in session.enemies.size():
			var enemy := session.enemies[index]
			enemy.position = Vector2(.5, .5) + Vector2.from_angle(TAU * index / count) * 300.0 / BattleSession.ARENA_SIZE
			enemy.previous_position = enemy.position
			enemy.combat_locked = true
			enemy.attack_clock = 100.0
		for index in (256 if extreme else 96):
			session._emit_enemy_threat(session.enemies[index % count], TAU * index / 256, index, 120.0, 5.0)
		# Commit real death facts/feedback; this fixture supplies damage, not player input.
		var experience := 0
		for enemy in session.enemies:
			if experience >= app.run.rewards.next_threshold: break
			experience += session._enemy_definitions[enemy.id].experience
			session.commit_damage(enemy, enemy.hp_q, enemy.hp_q, &"frost", session.player_position)
		frames.clear()
		clock.last = Time.get_ticks_usec()
		process_frame.connect(sample)
		await app._observe_battle_progression()
		_check(app.route == "reward" and app.run.phase == "BATTLE_REWARD", group + " committed death experience opens reward")
		_check(not session.is_physics_processing() and app.battle.hud.modulate.a < .3 and app.page.content_layer.modulate.a == 0.0, group + " stopped combat eases into a transparent first reward frame")
		var elapsed := session.elapsed
		await create_timer(.12).timeout
		_check(app.page.content_layer.modulate.a > 0.0 and app.page.content_layer.modulate.a < 1.0 and session.elapsed == elapsed, group + " reward fades in while gameplay remains stopped")
		await create_timer(.35).timeout
		process_frame.disconnect(sample)
		results.append({"group": group, "phase": "reward", "frames_ms": frames.duplicate(), "max_frame_ms": frames.max()})
		_check(app.page.body.find_child("RewardChoices", true, false).get_child_count() == app.run.offer.candidates.size(), group + " complete offer retains every choice")
		_check(app.fps_display.visible and app.fps_display.sample_ready, group + " top-right FPS is active")
		await _capture("reward-fps")
		var closing := app.page
		var id: StringName = StringName(app.run.offer.candidates[0])
		await app._choose_reward(id, str(app.run.offer.id), null)
		_check(app.route == "reward_return" and closing.closing and not session.is_physics_processing(), group + " saved selection starts dismissal before resuming rules")
		await create_timer(.3).timeout
		_check(not is_instance_valid(closing) and app.battle.hud.modulate.a == 1.0 and app.battle.stage.output.modulate == Color.WHITE, group + " return restores original battle appearance")
		_check(app.run.selection.assets.get(id, 0) > 0 or app.run.selection.instances.any(func(asset: CombatAssetInstance) -> bool: return asset.content_id == id), group + " selected relic is installed")
		_check(app.route in ["battle", "pause"] and session.is_physics_processing(), group + " input returns after reveal with focus-loss pause respected")
		app.queue_free()
		paused = false
		await process_frame
		FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify({"failures": failures, "results": results}, "\t"))
	print("Battle transitions: failures=", failures, " evidence=", directory)
	quit(0 if failures == 0 else 1)


func _review_async_saves() -> void:
	evidence = "res://.temp/async-saves-20261019/%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	await _create_app()
	app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.settings.first_setup_complete = true
	app.settings.show_fps = true
	app._apply_visual_settings()
	if is_instance_valid(app.welcome_gate):
		app.welcome_gate.queue_free()
		app.welcome_gate = null
	app.archive.modulate.a = 1.0
	app._home(false)
	var source := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source-profile="): source = argument.trim_prefix("--source-profile=")
	assert(not source.is_empty())
	var rows: Array[Dictionary] = []
	var entries: Array[VocabularyEntry] = []
	for word in ["ash", "mist", "page", "ember", "frost", "paper"]:
		entries.append(VocabularyEntry.new(word, "存档测试"))
	var prepared := VocabularyIndex.build(entries)
	for stress in [false, true]:
		for background in [false, true]:
			var group := "extreme" if stress else "baseline"
			var mode := "async" if background else "sync"
			app.profile_base_path = evidence.path_join(group + "-" + mode)
			app.saves = SaveRepository.new(&"normal", app.profile_base_path)
			DirAccess.make_dir_recursive_absolute(app.saves.path.get_base_dir())
			if stress: assert(DirAccess.copy_absolute(source, app.saves.path) == OK)
			var load_action := app.saves.load_profile_async.bind(self) if background else app.saves.load_profile
			var load_row := await _measure_save_action(load_action, group, mode, "load")
			app.profile = load_row.result
			load_row.erase("result")
			rows.append(load_row)
			assert(not app.profile.has_pending_run())
			app.run = RunSession.new(app.saves, app.profile)
			app.run.save_tree = self if background else null
			await create_timer(.6).timeout
			rows.append(await _measure_save_action(app.run.begin.bind(&"frost", app.settings), group, mode, "begin"))
			var start_row := await _measure_save_action(app.run.start_room.bind(entries, prepared), group, mode, "room")
			var request: BattleStartRequest = start_row.result
			start_row.erase("result")
			rows.append(start_row)
			var session := BattleSession.new()
			session.start(request, app.run.combat)
			root.add_child(session)
			session.set_physics_process(false)
			rows.append(await _measure_save_action(app.run.suspend_battle.bind(session), group, mode, "checkpoint"))
			rows.append(await _measure_save_action(app.run.end_run.bind(session), group, mode, "append"))
			session.queue_free()
			app.profile = app.run.profile
			var reopened := SaveRepository.new(&"normal", app.profile_base_path).load_profile()
			_check(reopened != null and reopened.revision == app.profile.revision and reopened.records.size() == app.profile.records.size() and not reopened.has_pending_run(), group + " " + mode + " independently reopens committed result")
			FileAccess.open(evidence.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	# Exercise the actual app departure and quit paths with the large profile.
	app._start_battle()
	await create_timer(4.0).timeout
	_check(is_instance_valid(app.battle) and (app.route == "battle" or (app.route == "pause" and app.paused_route == "battle")), "async departure releases into battle or its focus-loss pause")
	_check(app.fps_display.visible and app.fps_display.sample_ready, "top-right FPS is visible and sampling")
	app._pause()
	await _capture("async-battle-paused-fps")
	# Close during a real transaction: quit must wait, then checkpoint the battle.
	var pending := {}
	_collect_ui_write(app.run.suspend_battle.bind(app.battle.session), pending)
	_check(app._saving, "transaction holds input while background write is pending")
	_check(app.root.get_child(-1) == app._save_input_cover and app._save_input_cover.visible and not app.router.is_processing_input(), "save cover owns pointer order and keyboard input is held")
	var duplicate := {"called": false}
	await app._run_write(func() -> bool:
		duplicate.called = true
		return true)
	_check(not duplicate.called, "duplicate UI transaction is not executed")
	await app._quit_game()
	var final_profile := SaveRepository.new(&"normal", app.profile_base_path).load_profile()
	_check(not pending.is_empty() and pending.ok and not app.saves.is_saving() and final_profile.has_pending_run(), "close waits for active save and leaves a resumable checkpoint")
	print("Async UI saves: failures=", failures, " evidence=", evidence)
	quit(0 if failures == 0 else 1)


func _collect_ui_write(action: Callable, result: Dictionary) -> void:
	result.ok = await app._run_write(action)


func _measure_save_action(action: Callable, group: String, mode: String, operation: String) -> Dictionary:
	await create_timer(.2).timeout
	await process_frame
	var clock := {"previous": Time.get_ticks_usec(), "pending": true, "pending_frames": 0}
	var frames: Array[float] = []
	var sample := func() -> void:
		var now := Time.get_ticks_usec()
		frames.append((now - int(clock.previous)) / 1000.0)
		clock.previous = now
		if clock.pending: clock.pending_frames += 1
	process_frame.connect(sample)
	var started := Time.get_ticks_usec()
	var result: Variant = await app._run_write(action)
	var latency_ms := (Time.get_ticks_usec() - started) / 1000.0
	clock.pending = false
	await process_frame
	await process_frame
	process_frame.disconnect(sample)
	_check(result is ProfileState or result is BattleStartRequest or (result is bool and result), group + " " + mode + " " + operation + " succeeds")
	var row := {"group":group, "mode":mode, "operation":operation, "latency_ms":latency_ms, "frames_ms":frames, "max_frame_ms":frames.max(), "pending_frames":clock.pending_frames}
	print("ASYNC_SAVE_PERF ", JSON.stringify(row))
	if result is ProfileState or result is BattleStartRequest: row.result = result
	return row


func _review_page_stalls() -> void:
	evidence = "res://.temp/page-stalls-20261018/%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.settings.first_setup_complete = true
	app.settings.resolution = Vector2i(1920,1080)
	app.settings.sound = false
	app.settings.show_fps = true
	app.settings.ambience = false
	app.settings_prepared = true
	app.presentation_enabled = false
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.profile_base_path = evidence.path_join("profiles")
	var source := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source-profile="): source = argument.trim_prefix("--source-profile=")
	assert(not source.is_empty())
	var isolated := SaveRepository.new(&"normal", app.profile_base_path)
	DirAccess.make_dir_recursive_absolute(isolated.path.get_base_dir())
	assert(DirAccess.copy_absolute(source, isolated.path) == OK)
	root.add_child(app)
	await create_timer(2.0).timeout
	var all_records := app.profile.records.duplicate()
	var rows: Array[Dictionary] = []
	for stress: bool in [false, true]:
		app.profile.records.assign(all_records if stress else all_records.slice(0,1))
		for destination: String in ["history", "words", "route", "reward"]:
			await process_frame
			var started := Time.get_ticks_usec()
			DebugLog._spans.clear()
			match destination:
				"history": app._run_records()
				"words": app._vocabulary_page()
				_: app._open(destination, "测试页面", "", false)
			var row := {"group":"extreme" if stress else "baseline", "page":destination, "call_ms":float(Time.get_ticks_usec()-started)/1000.0, "scopes":DebugLog._spans.duplicate()}
			var previous := started
			var frames: Array[float] = []
			for frame in (90 if stress else 60):
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append(float(now-previous)/1000.0)
				previous = now
			row["frames"] = frames
			row["max_ms"] = frames.max()
			rows.append(row)
			print("PAGE_PERF ", destination, " ", row.group, " call=", row.call_ms, " max=", row.max_ms, " scopes=", row.scopes)
			FileAccess.open(evidence.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(rows))
			if destination == "history":
				var entries := 0
				for button in app.page.find_children("*", "Button", true, false):
					if str(button.get_meta("word_command", "")).begins_with("entry"): entries += 1
				_check(entries == app.profile.records.size(), "all history rows finish building")
				_check(app._history_detail.get_meta("record") == app.profile.records[-1], "latest history is selected without being overwritten by row construction")
			if destination == "words":
				var preview_grid := app.vocab_detail.get_children().filter(func(node: Node) -> bool: return node is GridContainer)[0] as GridContainer
				_check(preview_grid.get_child_count() == mini(40, app.selected_entries.size()), "all vocabulary preview pairs finish building")
			app._home(false)
			await create_timer(.3).timeout
	app._run_records()
	await process_frame
	app._record_detail(app.profile.records[0], false)
	app._record_detail(app.profile.records[-1], false)
	await create_timer(1.0).timeout
	_check(app._history_detail.get_meta("record") == app.profile.records[-1], "rapid history selection keeps the final record")
	await _capture("history-settled")
	app._home(false)
	app._vocabulary_page()
	await process_frame
	app._home(false)
	await create_timer(.2).timeout
	_check(app.route == "home" and not is_instance_valid(app.page), "leaving during incremental construction stays on home")
	app.queue_free()
	await process_frame
	print("Page stall evidence: ", evidence)
	quit(0 if failures == 0 else 1)


func _review_book_switch() -> void:
	evidence = "res://.temp/book-switch-20261018/%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.settings.first_setup_complete = true
	app.settings.resolution = Vector2i(1920, 1080)
	app.settings.vsync = false
	app.settings.sound = false
	app.settings.show_fps = true
	app.settings.ambience = false
	app.settings_prepared = true
	app.presentation_enabled = false
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.profile_base_path = evidence.path_join("profiles")
	root.add_child(app)
	await create_timer(3.0).timeout
	for control in app.root.find_children("*", "Control", true, false):
		control.theme_changed.connect(func() -> void: theme_notifications += 1)
	var report := {"groups": [], "resolution": str(root.size), "quality": app.settings.quality, "fluid": app.settings.fluid_quality}
	for stress: bool in [false, true]:
		var rows: Array[Dictionary] = []
		var selections: Array[float] = []
		var start := Time.get_ticks_usec()
		var last := start
		var next_switch := 0.5
		var count := 0
		var interval := 0.12 if stress else 1.5
		var limit := 12 if stress else 4
		var duration := 0.5 + interval * (limit - 1) + 1.6
		theme_notifications = 0
		while float(Time.get_ticks_usec() - start) / 1000000.0 < duration:
			await process_frame
			var now := Time.get_ticks_usec()
			var elapsed := float(now - start) / 1000000.0
			rows.append({"t": elapsed, "ms": float(now-last)/1000.0, "theme_notifications": theme_notifications})
			last = now
			if count < limit and elapsed >= next_switch:
				var select_start := Time.get_ticks_usec()
				app.archive.select_book((app.archive.selected + 1) % 4)
				selections.append(float(Time.get_ticks_usec()-select_start)/1000.0)
				count += 1
				next_switch += interval
		_check(count == limit, "all requested selections execute")
		_check(app.archive.accent.is_equal_approx(ArchiveHome.BOOKS[app.archive.selected].color), "last selected accent settles")
		var times: Array[float] = []
		for row in rows: times.append(row.ms)
		times.sort()
		var summary := {"name": "extreme" if stress else "baseline", "p50": times[int(times.size()*.5)], "p95": times[int(times.size()*.95)], "max": times[-1], "notifications": theme_notifications, "selection_ms": selections, "rows": rows}
		report.groups.append(summary)
		FileAccess.open(evidence.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report))
		print("BOOK_SWITCH ", summary.name, " p50=", summary.p50, " p95=", summary.p95, " max=", summary.max, " theme=", theme_notifications)
		await create_timer(.5).timeout
	# Functional checks are outside both timing windows.
	var palette := app.root.theme
	var layout_probe := app.archive.counter
	var stable_changes := [0]
	layout_probe.theme_changed.connect(func() -> void: stable_changes[0] += 1)
	var button := app.archive.prepare_button as OpenButton
	var original_mesh := button._gold.mesh
	var original_font := button.get_theme_font("font")
	app.archive.select_book((app.archive.selected + 1) % 4)
	await create_timer(.3).timeout
	var intermediate := app.archive.accent
	_check(not intermediate.is_equal_approx(ArchiveHome.BOOKS[app.archive.selected].color), "color transition retains intermediate colors")
	_check(button._light_material.get_shader_parameter("accent").is_equal_approx(intermediate), "button light follows the current animated color")
	_check(button._gold.mesh == original_mesh and button.get_theme_font("font") == original_font, "color animation preserves gold geometry and fonts")
	_check(stable_changes[0] == 0, "unrelated counter receives no theme invalidation during color animation")
	await _capture("switch-intermediate")
	app._guide()
	await create_timer(.25).timeout
	var input := LineEdit.new()
	app.page.body.add_child(input)
	var text_input := TextEdit.new()
	app.page.body.add_child(text_input)
	await process_frame
	await process_frame
	app.archive.select_book((app.archive.selected + 1) % 4)
	await create_timer(.3).timeout
	intermediate = app.archive.accent
	_check(app.root.theme == palette and palette.get_color("accent", "Archive").is_equal_approx(intermediate), "shared palette identity and live accent remain available")
	_check(input.get_theme_color("caret_color").is_equal_approx(intermediate.lerp(Color.WHITE,.45)) and text_input.get_theme_color("selection_color").is_equal_approx(Color(intermediate,.3)), "native text inputs refresh caret and selection colors")
	_check(app.page.accent.is_equal_approx(intermediate), "page opened during transition tracks the current color")
	app.archive.reduced_motion = true
	app.archive.select_book((app.archive.selected + 1) % 4)
	_check(app.archive.orbit == app.archive.orbit_target, "reduced motion switches book position immediately")
	await create_timer(1.1).timeout
	_check(app.archive.accent.is_equal_approx(ArchiveHome.BOOKS[app.archive.selected].color) and app.page.accent.is_equal_approx(app.archive.accent), "interrupted reduced-motion transition settles on last selected book")
	app._home(false)
	await create_timer(.4).timeout
	await _capture("switch-settled")
	report["failures"] = failures
	FileAccess.open(evidence.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report))
	print("Book switch checks: %d failure(s) | %s" % [failures, evidence])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _create_app() -> void:
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.settings.sound = false
	app.settings.show_fps = true
	app.settings.resolution = Vector2i(1920, 1080)
	app.settings_prepared = true
	app.profile_base_path = evidence.path_join("profiles")
	# This fixture exercises the welcome and archive; configuration has its own
	# first-entry interaction coverage in test_ui_refinement --setup-feedback.
	app.settings.first_setup_complete = true
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	root.add_child(app)
	await process_frame
	while not app.initialized: await process_frame

func _gate() -> ArchiveGate:
	for child in app.root.get_children():
		if child is ArchiveGate:
			return child as ArchiveGate
	return null

func _key(code: Key, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _mouse_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var encoded := Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			encoded.set_pixel(x,y,source.get_pixel(x,y).linear_to_srgb())
	encoded.save_png(evidence.path_join(label+".png"))

func _check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ")+label)
	if not condition:
		failures += 1
