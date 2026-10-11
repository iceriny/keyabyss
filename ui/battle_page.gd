class_name BattlePage
extends Control
## Fixed HUD and target words float over the arena; only words accept mouse selection.

signal pause_requested

var session: BattleSession
var settings: AppSettings
var stage: BattleStage
var atmosphere: ShaderMaterial
var visuals: BattleVisuals
var audio: BattleAudio
var school_color: Color
var book_title: String
var book_ultimate: String
var book_icon: TextureRect
var health_label: Label
var health_value: Label
var health_bar: ColorRect
var shield_label: Label
var shield_bar: ColorRect
var dodge_label: Label
var chapter_label: Label
var wave_label: Label
var timer_label: Label
var room_dots: Label
var cast_label: Label
var cast_word: RichTextLabel
var ultimate_indicator: UltimateIndicator
var bottom_label: Label
var progress_label: Label
var hint_label: Label
var pause_button: Button
var warnings: BattleThreatOverlay
var cadence_label: Label
var defense_label: Label
var enemy_words: Dictionary[StringName, BattleWord] = {}
var word_exclusions: Array[Rect2] = []
var _camera_offset := Vector2.ZERO
var _feedback_labels: Array[Label] = []
var _damage_feedback: Dictionary[String, Dictionary] = {}
var hud: Control
var hud_details: Control
var defense_keys: KeyHint
var cast_progress: ColorRect
var _cast_progress_target := 0.0
var _cast_progress_display := 0.0
var _cast_progress_word := ""
var slow_lens: BattleSlowLens
var _refresh_pending := false


static func create(battle: BattleSession, options: AppSettings, book: BookPresentation) -> BattlePage:
	var page := load("res://ui/scenes/battle_page.tscn").instantiate() as BattlePage
	page._configure(battle, options, book)
	return page


func _configure(battle: BattleSession, options: AppSettings, book: BookPresentation) -> void:
	session = battle
	settings = options
	school_color = book.color
	book_title = book.title
	book_ultimate = book.ultimate
	session.name = "BattleSession"
	add_child(session)
	stage = $BattleStage
	slow_lens = $SlowLens
	slow_lens.capture = $SlowCapture
	stage._bind_scene()
	stage.set_quality(settings.quality)
	var background := stage.scenery.get_node("Atmosphere") as ColorRect
	background.light_mask = 2
	(background.material as ShaderMaterial).set_shader_parameter("school_color", school_color)
	(background.material as ShaderMaterial).set_shader_parameter("motion", 0.0 if settings.reduce_motion else 1.0)
	atmosphere = background.material as ShaderMaterial
	visuals = $BattleStage/World/Scenery/BattleWorld
	visuals.configure(session, school_color, settings.quality, settings.reduce_motion)
	visuals.fluid_quality = settings.fluid_quality
	visuals.fluid_material = book.fluid_material
	visuals.fluid_effects = book.fluid_effects
	warnings = $BattleThreats
	warnings.session = session
	warnings.quality = settings.quality
	warnings.reduced_motion = settings.reduce_motion
	$BattleCompass.session = session
	$BattleCompass.reduced_motion = settings.reduce_motion
	audio = $BattleAudio
	audio.enabled = settings.sound
	audio.effects_volume = settings.effects_volume
	book_icon = $HUD/BookSeal
	hud = $HUD
	book_icon.texture = book.artwork
	var heading: Label = $HUD/BattleHeading
	heading.text = book_title
	heading.add_theme_color_override("font_color", school_color)
	health_label = $HUD/PlayerHealth
	health_value = $HUD/HealthValue
	health_bar = $HUD/HealthFill
	shield_label = $HUD/PlayerShield
	shield_bar = $HUD/ShieldFill
	dodge_label = $HUD/Dodge
	chapter_label = $HUD/BattleChapter
	if not session.run_id.is_empty():
		chapter_label.text = "第 %d 章 · 第 %d 页" % [session.encounter.chapter_number, (session.run_state.room_serial - 1) % 3 + 1]
	room_dots = $HUD/RoomProgress
	wave_label = $HUD/BattleWave
	timer_label = $HUD/BattleTimer
	progress_label = $HUD/BattleProgress
	cadence_label = $HUD/BookCadence
	defense_label = $HUD/DefenseStatus
	pause_button = $HUD/Pause
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	bottom_label = $HUD/BattleMode
	bottom_label.text = session.encounter.display_name + " · " + RunSession.DIFFICULTY_NAMES[RunSession.DIFFICULTIES.find(session.difficulty)]
	if session.loop_index > 0: bottom_label.text += " · 第 %d 周目" % (session.loop_index + 1)
	cast_label = $HUD/CastLabel
	cast_word = $HUD/CastWord
	cast_word.add_theme_font_size_override("normal_font_size", 30)
	ultimate_indicator = $HUD/Ultimate
	ultimate_indicator.configure(session, settings, book)
	ultimate_indicator.activated.connect(func() -> void: session.queue_action(&"ultimate"))
	hint_label = $HUD/BattleHint
	defense_label.text = ""
	var defense_stack := VBoxContainer.new()
	defense_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defense_label.add_child(defense_stack)
	defense_keys = KeyHint.create("Space", "御术")
	defense_stack.add_child(defense_keys)
	defense_stack.add_child(KeyHint.create_row([{ "key": "↑↓←→", "description": "闪避" }, { "key": "Alt", "description": "自动择位" }]))
	pause_button.text = ""
	pause_button.add_child(KeyHint.create("Esc", "暂停"))
	cast_progress = ColorRect.new()
	cast_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_material := preload("res://ui/materials/cast_progress.tres").duplicate() as ShaderMaterial
	cast_progress.material = progress_material
	hud.add_child(cast_progress)
	cast_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cast_progress.offset_left = -180
	cast_progress.offset_right = 180
	cast_progress.offset_top = -19
	cast_progress.offset_bottom = -7
	hud_details = $HUD/HudDetails
	hud_details.draw.connect(_draw_details)
	_ensure_targets()
	session.state_changed.connect(_request_refresh)
	session.typing.changed.connect(_request_refresh)
	session.typing.character_judged.connect(func(_attempt: String, _word: String, correct: bool) -> void:
		if not correct:
			audio.play_input("mistake", size)
	)
	session.typing.feedback_requested.connect(func(cue: StringName) -> void: audio.play_input(str(cue), size))
	session.event_committed.connect(_present)


func _word_targets() -> Array:
	var targets: Array = []
	targets.append_array(session.enemies)
	targets.append_array(session.pickups)
	return targets


func _ensure_targets() -> void:
	var active: Dictionary = {}
	for enemy in _word_targets():
		active[enemy.id] = true
		if enemy_words.has(enemy.id):
			continue
		var word_label := preload("res://ui/scenes/battle_word.tscn").instantiate() as BattleWord
		word_label.name = "Word_" + str(enemy.id)
		word_label.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var changed: bool = session.typing.target_id != enemy.id or session.typing.progress > 0
				session.typing.select_target(enemy.id)
				if changed and session.typing.target_id == enemy.id:
					audio.play_input("target", size)
		)
		$TargetWords.add_child(word_label)
		enemy_words[enemy.id] = word_label
	for id in enemy_words.keys():
		if not active.has(id):
			enemy_words[id].queue_free()
			enemy_words.erase(id)


func _ready() -> void:
	resized.connect(_layout)
	_layout()
	_refresh()


func apply_options() -> void:
	warnings.quality = settings.quality
	warnings.reduced_motion = settings.reduce_motion
	audio.enabled = settings.sound
	audio.effects_volume = settings.effects_volume
	stage.set_quality(settings.quality)
	visuals.set_options(settings.quality, settings.reduce_motion)
	visuals.fluid.set_options(settings.fluid_quality, settings.reduce_motion)
	$BattleCompass.reduced_motion = settings.reduce_motion
	atmosphere.set_shader_parameter("motion", 0.0 if settings.reduce_motion else 1.0)
	_refresh()


func _layout() -> void:
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.position = Vector2(BattleStage.arena_origin(size).x, 0.0)
	hud.size = Vector2(BattleSession.ARENA_SIZE.x * BattleStage.arena_scale(size), size.y)
	for world: Control in [visuals, warnings]:
		world.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		world.position = BattleStage.arena_origin(size)
		world.size = BattleSession.ARENA_SIZE
		world.scale = Vector2.ONE * BattleStage.arena_scale(size)
	_place_targets()


func _request_refresh() -> void:
	_refresh_pending = true


func _refresh() -> void:
	_refresh_pending = false
	if health_label == null:
		return
	var started := DebugLog.begin()
	_ensure_targets()
	atmosphere.set_shader_parameter("visual_time", session.world_time)
	atmosphere.set_shader_parameter("player_uv", BattleStage.arena_point(session.player_position, size) / size)
	atmosphere.set_shader_parameter("activity", minf(1.0, session.typing.progress * 0.14))
	health_label.text = "生命"
	health_value.text = "%d / %d" % [ceili(float(session.player_hp_q) / SpellResourceLedger.Q), ceili(float(session.player_max_hp_q) / SpellResourceLedger.Q)]
	health_bar.size.x = $HUD/HealthTrack.size.x * float(session.player_hp_q) / session.player_max_hp_q
	shield_label.text = "护盾  %d" % ceili(session.run_state.shield_q / 1024.0)
	shield_label.visible = session.run_state.shield_q > 0
	shield_bar.visible = shield_label.visible
	$HUD/ShieldTrack.visible = shield_label.visible
	shield_bar.size.x = $HUD/ShieldTrack.size.x * minf(1.0, session.run_state.shield_q / float(60 * 1024))
	var charge_marks := ""
	for index in 2 + session.compiled_build.value(&"dodge_capacity"):
		charge_marks += "◆" if session.dodge_charges >= index + 1 else "◇"
	dodge_label.text = "闪避  " + charge_marks
	progress_label.text = "施法  %d" % session.completed_words
	var cycle: int = session.compiled_build.value(&"cadence", BattleSession.MAIN_SPELL_CYCLES[session.book_id])
	var cadence: String = {&"frost": "霜印", &"flame": "焰印", &"storm": "雷印", &"spirit": "灵印"}[session.book_id]
	var counter := session.runtime.book_cast_count() % cycle
	cadence_label.text = cadence
	cadence_label.modulate = Color("ffe7b2") if counter == cycle - 1 else Color.WHITE
	defense_keys.description = "御术%s" % ["  %.1fs" % session.parry_cooldown if session.parry_cooldown > 0.0 else ""]
	var living := 0
	for enemy in session.enemies:
		if enemy.alive():
			living += 1
	timer_label.text = "%02d:%02d  ·  %d 击破" % [floori(session.elapsed / 60.0), floori(fmod(session.elapsed, 60.0)), session.enemies.size() - living]
	wave_label.text = "下一波 · %.1f 秒" % session.intermission if session.intermission >= 0.0 else "第 %d / %d 波 · %s侧来袭 · 存活 %d" % [session.wave, session.encounter.wave_count, session.arrival_direction, living]
	var selected_enemy := session.enemy_by_id(session.typing.target_id)
	cast_label.text = ("残响续写" if selected_enemy != null and not selected_enemy.alive() else "正在施法") if session.typing.target_id != &"" else "输入词咒"
	if session.typing.target_id != &"":
		var boundary := session.typing.display_boundary()
		var text := "[center][color=#ffb567]%s[/color][color=#e9ece5]%s[/color][/center]" % [session.typing.word.left(boundary), session.typing.word.substr(boundary)]
		if cast_word.text != text: cast_word.text = text
	else:
		cast_word.text = ""
	if selected_enemy != null:
		hint_label.text = session.word_meaning(session.typing.word)
		if not selected_enemy.resistance_label.is_empty():
			hint_label.text += "\n" + selected_enemy.resistance_label
		hint_label.visible = not hint_label.text.is_empty()
	else:
		hint_label.text = ""
	hint_label.visible = not hint_label.text.is_empty()
	_cast_progress_target = float(session.typing.progress) / maxf(1.0, session.typing.word.length())
	var attempt := "%s:%s" % [session.typing.target_id, session.typing.word]
	if attempt != _cast_progress_word or _cast_progress_target < _cast_progress_display:
		_cast_progress_display = 0.0
		_cast_progress_word = attempt
	for enemy in session.enemies:
		var word_label := enemy_words[enemy.id]
		var selected := session.typing.target_id == enemy.id
		var display_word := session.typing.word if selected else enemy.word
		word_label.configure(display_word, session.word_meaning(display_word), settings.show_meaning, selected, session.typing.display_boundary() if selected else 0, settings.reduce_motion, enemy.resistance_label, [])
		word_label.z_index = 1 if selected else 0
		word_label.visible = not display_word.is_empty() and ((enemy.alive() and not enemy.word_pending and (selected or BattleSession.enemy_in_combat(enemy))) or (selected and not enemy.alive()))
		word_label.modulate.a = smoothstep(0.0, 0.28, enemy.word_age)
	for pickup in session.pickups:
		var word_label := enemy_words[pickup.id]
		var selected := session.typing.target_id == pickup.id
		word_label.configure(pickup.word, session.word_meaning(pickup.word), settings.show_meaning, selected, session.typing.display_boundary() if selected else 0, settings.reduce_motion, "反制" if pickup.kind == &"rune" else "爆墨", [])
		word_label.z_index = 1 if selected else 0
		word_label.visible = pickup.alive() or selected
		word_label.modulate.a = smoothstep(0.0, 0.28, pickup.age)
	DebugLog.end(&"battle.ui_refresh", started)


func _process(delta: float) -> void:
	if _refresh_pending: _refresh()
	var started := DebugLog.begin()
	slow_lens.update_effect(session, delta, settings.reduce_motion, settings.quality)
	_cast_progress_display = _cast_progress_target if settings.reduce_motion else lerpf(_cast_progress_display, _cast_progress_target, 1.0 - exp(-delta * 18.0))
	(cast_progress.material as ShaderMaterial).set_shader_parameter("progress", _cast_progress_display)
	_camera_offset = visuals.camera_offset
	$BattleCompass.position = BattleStage.arena_point(session.previous_player_position.lerp(session.player_position, Engine.get_physics_interpolation_fraction()), size) + _camera_offset
	stage.output.position = _camera_offset
	warnings.position = BattleStage.arena_origin(size) + _camera_offset
	_place_targets(delta)
	hud_details.queue_redraw()
	DebugLog.end(&"battle.ui_layout", started)


func _place_targets(delta: float = 0.0) -> void:
	var occupied: Array[Rect2] = word_exclusions.duplicate()
	var arena_scale := BattleStage.arena_scale(size)
	# HUD global coordinates include the UI scale; words use this page's coordinates.
	var page_transform := get_global_transform().affine_inverse()
	# One continuous reading field leaves no pockets between HUD groups.
	var top_limit := 12.0
	for control: Control in [dodge_label, progress_label, wave_label, pause_button]:
		top_limit = maxf(top_limit, (page_transform * control.get_global_rect()).end.y + 12.0)
	var bottom_limit := size.y
	for control: Control in [cast_label, bottom_label, ultimate_indicator]:
		bottom_limit = minf(bottom_limit, (page_transform * control.get_global_rect()).position.y - 12.0)
	var ordered := _word_targets()
	# Entity order is stable: selection only changes the reading emphasis, not layout priority.
	for enemy in ordered:
		var point := slow_lens.project(BattleStage.arena_point(enemy.previous_position.lerp(enemy.position, Engine.get_physics_interpolation_fraction()), size) + _camera_offset)
		var word_label := enemy_words[enemy.id]
		var head_radius: float = BattleActorVisual.word_clearance(enemy) if enemy is BattleEnemy else enemy.radius
		var bounds := Rect2(point + Vector2(-word_label.size.x * 0.5, -head_radius * arena_scale - word_label.size.y - 8), word_label.size)
		var arena_left := BattleStage.arena_origin(size).x
		bounds.position.x = clampf(bounds.position.x, arena_left + 8.0, maxf(arena_left + 8.0, arena_left + BattleSession.ARENA_SIZE.x * arena_scale - bounds.size.x - 8.0))
		bounds.position.y = clampf(bounds.position.y, top_limit, maxf(top_limit, bottom_limit - bounds.size.y))
		var ideal := bounds.position
		if word_label.visible:
			var obstacles := occupied
			var previous := ideal + word_label.layout_offset
			# Keep a committed destination, rather than feeding the in-flight easing back
			# into the solver. A small gain cannot repeatedly switch avoidance sides.
			var candidates: Array[Vector2] = [previous, ideal]
			for obstacle in obstacles:
				if bounds.intersects(obstacle.grow(6.0)) or Rect2(previous, bounds.size).intersects(obstacle.grow(6.0)):
					candidates.append(Vector2(obstacle.end.x + 6.0, ideal.y))
					candidates.append(Vector2(obstacle.position.x - bounds.size.x - 6.0, ideal.y))
					candidates.append(Vector2(ideal.x, obstacle.position.y - bounds.size.y - 6.0))
					candidates.append(Vector2(ideal.x, obstacle.end.y + 6.0))
			var best := INF
			for candidate in candidates:
				candidate.x = clampf(candidate.x, arena_left + 8.0, arena_left + BattleSession.ARENA_SIZE.x * arena_scale - bounds.size.x - 8.0)
				candidate.y = clampf(candidate.y, top_limit, maxf(top_limit, bottom_limit - bounds.size.y))
				var trial := Rect2(candidate, bounds.size)
				var cost := candidate.distance_squared_to(ideal) + candidate.distance_squared_to(previous) * 0.35
				if candidate.distance_squared_to(previous) > 1.0:
					cost += 24.0 * 24.0
				for obstacle in obstacles:
					if trial.intersects(obstacle.grow(4.0)):
						cost += trial.intersection(obstacle.grow(4.0)).get_area() * 100.0
				if cost < best:
					best = cost
					bounds.position = candidate
		word_label.place(ideal, bounds.position - ideal, delta)
		if word_label.visible:
			occupied.append(bounds)


func _present(event: Dictionary) -> void:
	visuals.present(event)
	audio.present(event, size)
	if event.kind == &"impact" and event.source != &"flame_burn":
		var response := " 抵抗" if event.get("resistance", false) else (" 弱点" if event.get("weakness", false) else "")
		var key := str(event.enemy) + response
		var now := Time.get_ticks_msec()
		var group: Dictionary = _damage_feedback.get(key, {})
		if not group.is_empty() and now <= group.until and is_instance_valid(group.label):
			group.amount_q += event.damage_q
			var label: Label = group.label
			label.text = str(roundi(float(group.amount_q) / BattleSession.Q)) + response
			label.size = label.get_minimum_size() + Vector2(8, 0)
		else:
			var label := _float_feedback(str(roundi(float(event.damage_q) / BattleSession.Q)) + response, event.at, school_color, 18)
			_damage_feedback[key] = {"label":label, "amount_q":event.damage_q, "until":now + 180}
	elif event.kind == &"counter_pulse":
		var perfect: bool = event.get("grade", &"success") == &"perfect"
		_float_feedback("完美御术" if perfect else "御术", event.at, Color("ffe4a0") if perfect else Color("b9d6ce"), 23 if perfect else 19)
	elif event.kind == &"perfect_dodge":
		_float_feedback("完美闪避", event.at, Color("e8dcb5"), 23)
	elif event.kind == &"enemy_attack" and event.outcome == &"hit":
		_float_feedback("−%d" % roundi(float(event.damage_q) / BattleSession.Q), event.at, Color("eeae9f"), 23)


func _float_feedback(value: String, at: Vector2, tint: Color, font_size: int) -> Label:
	var label := PageShell.label(self, value, font_size, tint)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = label.get_minimum_size() + Vector2(8, 0)
	label.position = slow_lens.project(BattleStage.arena_point(at, size) + _camera_offset) + (Vector2(32 - label.size.x * 0.5, -28) if font_size == 18 else Vector2(-label.size.x * 0.5, -76))
	# New text moves upward faster than older text, so stack above current bounds.
	for attempt in _feedback_labels.size() + 1:
		var shifted := false
		for active in _feedback_labels:
			if label.get_rect().grow(3).intersects(active.get_rect()):
				label.position.y = active.position.y - label.size.y - 6.0
				shifted = true
		if not shifted:
			break
	label.position.x = clampf(label.position.x, 8.0, maxf(8.0, size.x - label.size.x - 8.0))
	label.position.y = clampf(label.position.y, 38.0, maxf(38.0, size.y - label.size.y - 8.0))
	_feedback_labels.append(label)
	label.add_theme_color_override("font_shadow_color", Color("081018"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	var tween := BattleVisualClock.tween_for(visuals).set_parallel()
	if not settings.reduce_motion:
		tween.tween_property(label, "position:y", label.position.y - 30, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.25)
	tween.chain().tween_callback(func() -> void:
		_feedback_labels.erase(label)
		for key in _damage_feedback.keys():
			if _damage_feedback[key].label == label: _damage_feedback.erase(key)
		label.queue_free()
	)
	return label


func _draw_details() -> void:
	if health_bar == null:
		return
	# Fine breaks preserve exact fill width; decoration never changes meter values.
	var health_track: ColorRect = $HUD/HealthTrack
	for x in range(1, 20):
		var at := health_track.position + Vector2(x * health_track.size.x / 20.0, 0)
		hud_details.draw_line(at, at + Vector2(0, health_track.size.y), Color("101b20", 0.5), 1)
	var cycle: int = session.compiled_build.value(&"cadence", BattleSession.MAIN_SPELL_CYCLES[session.book_id])
	for i in cycle:
		var at := cadence_label.position + Vector2(i * 18, 24)
		hud_details.draw_line(at, at + Vector2(13, 0), school_color if i < session.runtime.book_cast_count() % cycle else Color("4b595e", 0.6), 2.0, true)
	for i in session.encounter.wave_count:
		var at := Vector2(hud.size.x * 0.5 - 36 + i * 28, 65)
		hud_details.draw_line(at, at + Vector2(19, 0), Color("dec692") if i < session.wave else Color("48575e"), 3.0, true)
	for enemy in _word_targets():
		var word := enemy_words[enemy.id]
		if word.visible:
			var center := slow_lens.project(BattleStage.arena_point(enemy.previous_position.lerp(enemy.position, Engine.get_physics_interpolation_fraction()), size) + _camera_offset) - hud.position
			var label_end := word.position - hud.position + Vector2(word.size.x * 0.5, word.size.y)
			if center.y < word.position.y + word.size.y * 0.5:
				label_end.y -= word.size.y
			var toward := center - label_end
			var radius: float = enemy.radius * BattleStage.arena_scale(size)
			if toward.length() > radius + 24.0:
				hud_details.draw_line(label_end, center - toward.normalized() * (radius + 3.0), Color("a0b4b7", 0.16 * word.modulate.a), 0.7, true)
