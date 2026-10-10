class_name ArchiveGate
extends Control
## Transient HDR stage; the lens never samples the underlying interactive UI.
signal entered
signal cue_requested(cue: String)
signal arrival_progress(value: float)
signal welcome_ready

var sound: ArchiveAudio
var reduced_motion := false
var can_skip := false
var started := false
var finished := false
var skipping := false
# These values belong to the native AnimationPlayer timeline.
var elapsed := 0.0
var wave_progress := 0.0
var wave_energy := 0.0
var wave_strength := 18.0
var wave_width := 28.0
var flare := 0.0
var seal_alpha := 1.0
var seal_scale := 1.0
var orbit_energy := 0.04
var rotation_speed := 1.0
var home_visibility := 0.0
var _clock := 0.0
var _rotation_clock := 0.0
var _draw_state := Vector4(-1.0,-1.0,-1.0,-1.0)
var _last_arrival := -1.0
var _forming := false
var _formation := 1.0
var _loading_ring: Node2D
var _loading_feedback: Control
var _loading_labels: Array[Label] = []
var stage_viewport: SubViewport
var stage: Control
var timeline: AnimationPlayer
var dust: GPUParticles2D
var orbit: Control
var outer_runes: Control
var mark: Control
var inscriptions: Control
var title: Label
var subtitle: Label
var prompt: Label
var phase_label: Label
var phase_small: Label
var wave: TextureRect
var wave_material: ShaderMaterial

static func create() -> ArchiveGate:
	var scene := load("res://ui/scenes/archive_gate.tscn") as PackedScene
	return scene.instantiate() as ArchiveGate


func _ready() -> void:
	stage_viewport = $RitualViewport
	stage = $RitualViewport/Stage
	$RitualViewport/Stage/Backdrop.reduced_motion = reduced_motion
	stage.draw.connect(_draw_stage)
	orbit = $RitualViewport/Stage/SigilLight/Orbit
	outer_runes = $RitualViewport/Stage/OuterRuneLight/Runes
	orbit.modulate.a = orbit_energy
	mark = $RitualViewport/Stage/ConnectionLight/Mark
	inscriptions = $RitualViewport/Stage/InscriptionLight/Details
	title = $RitualViewport/Stage/Title
	subtitle = $RitualViewport/Stage/Subtitle
	prompt = $RitualViewport/Stage/Prompt
	dust = $RitualViewport/Stage/ArchiveDust
	wave = $Wave
	wave_material = wave.material as ShaderMaterial
	phase_label = $PhaseLabel
	phase_small = $PhaseSmall
	timeline = $RitualTimeline
	orbit.set("reduced_motion", reduced_motion)
	outer_runes.set("reduced_motion", reduced_motion)
	mark.set("reduced_motion", reduced_motion)
	inscriptions.set("reduced_motion", reduced_motion)
	dust.process_material = dust.process_material.duplicate(true)
	(dust.process_material as ParticleProcessMaterial).color = Color(0.90, 0.71, 0.39, 0.24)
	dust.visible = not reduced_motion
	dust.speed_scale = 0.0 if reduced_motion else 1.0
	timeline.animation_finished.connect(func(_animation: StringName) -> void: _finish())
	resized.connect(_layout)
	get_window().size_changed.connect(_layout, CONNECT_DEFERRED)
	_layout()

func _layout() -> void:
	if stage == null:
		return
	var pixel_scale := get_global_transform_with_canvas().get_scale().abs()
	stage_viewport.size = Vector2i((size * pixel_scale).ceil().max(Vector2.ONE))
	stage_viewport.canvas_transform = Transform2D(0.0, pixel_scale, 0.0, Vector2.ZERO)
	stage_viewport.oversampling_override = maxf(1.0, ceilf(pixel_scale.x))
	stage.size = size
	var unit := size.y / 1080.0
	var center := Vector2(size.x * 0.5, size.y * 0.385)
	orbit.size = Vector2.ONE * 600.0 * unit
	orbit.position = center - orbit.size * 0.5
	outer_runes.size = orbit.size
	outer_runes.position = orbit.position
	var mark_size := 306.0 * unit
	mark.size = Vector2.ONE * mark_size
	mark.position = center - mark.size * 0.5 - Vector2(0, 30.0 * unit)
	mark.pivot_offset = mark.size * 0.5
	inscriptions.size = mark.size
	inscriptions.position = mark.position
	inscriptions.pivot_offset = mark.pivot_offset
	var text_width := minf(size.x * 0.8, 640.0)
	var text_left := (size.x - text_width) * 0.5
	title.position = Vector2(text_left, center.y + 245.0 * unit)
	title.size = Vector2(text_width, 94.0 * unit)
	title.add_theme_font_size_override("font_size", roundi(76.0 * unit))
	subtitle.position = Vector2(text_left, center.y + 351.0 * unit)
	subtitle.size = Vector2(text_width, 30.0 * unit)
	subtitle.add_theme_font_size_override("font_size", roundi(20.0 * unit))
	prompt.position = Vector2(text_left, center.y + 481.0 * unit)
	prompt.size = Vector2(text_width, 32.0 * unit)
	prompt.add_theme_font_size_override("font_size", roundi(19.0 * unit))
	prompt.text = "任 意 键 继 续"
	wave.size = size
	wave_material.set_shader_parameter("viewport_size", size)
	wave_material.set_shader_parameter("wave_center", center)
	phase_label.position = Vector2(text_left, size.y * 0.83)
	phase_label.size = Vector2(text_width, 36.0)
	phase_small.position = Vector2(text_left, phase_label.position.y + 42.0)
	phase_small.size = Vector2(text_width, 24.0)
	dust.position = size * 0.5
	(dust.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	dust.visibility_rect = Rect2(-size * 0.5, size)
	stage.queue_redraw()

func _input(event: InputEvent) -> void:
	if _forming:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	if not key and not click:
		return
	if key and (event as InputEventKey).keycode == KEY_F11:
		return
	get_viewport().set_input_as_handled()
	if not started:
		started = true
		_cue("ui.enter")
		prompt.visible = false
		if reduced_motion:
			_begin_skip(0.24)
		else:
			phase_label.visible = true
			phase_small.visible = true
			timeline.play("awaken")
	elif can_skip and not skipping and elapsed >= 0.35:
		_begin_skip(0.65)

func _process(delta: float) -> void:
	if finished:
		return
	if not reduced_motion and not skipping:
		_clock += delta
		_rotation_clock += delta * rotation_speed
	for geometry: Control in [orbit, outer_runes, mark, inscriptions]:
		geometry.set("clock", _rotation_clock)
	(title.material as ShaderMaterial).set_shader_parameter("clock", _clock)
	for layer: CanvasGroup in [$RitualViewport/Stage/SigilLight, $RitualViewport/Stage/OuterRuneLight, $RitualViewport/Stage/ConnectionLight, $RitualViewport/Stage/InscriptionLight]:
		(layer.material as ShaderMaterial).set_shader_parameter("clock", _clock)
	if not started and not reduced_motion:
		prompt.modulate.a = 0.775 + 0.225 * cos(_clock * TAU / 3.2)
	mark.scale = Vector2.ONE * seal_scale
	mark.modulate = Color(1.0 + flare, 1.0 + flare, 1.0 + flare, seal_alpha)
	inscriptions.scale = mark.scale
	inscriptions.modulate = mark.modulate
	title.modulate.a = seal_alpha
	subtitle.modulate.a = seal_alpha
	orbit.modulate.a = orbit_energy
	outer_runes.modulate.a = 0.60 * seal_alpha * (1.0 + flare * 0.3)
	if _forming:
		var emerging := smoothstep(0.18, 0.88, _formation)
		mark.modulate.a *= emerging
		inscriptions.modulate.a *= smoothstep(0.34, 0.94, _formation)
		orbit.modulate.a *= emerging
		outer_runes.modulate.a *= smoothstep(0.22, 0.72, _formation)
		if not reduced_motion:
			mark.scale *= lerpf(0.82, 1.0, emerging)
			inscriptions.scale = mark.scale
		_loading_ring.modulate.a = 1.0 - smoothstep(0.14, 0.60, _formation)
		_loading_feedback.modulate.a = 1.0 - smoothstep(0.0, 0.24, _formation)
		prompt.modulate.a = smoothstep(0.78, 1.0, _formation)
		if reduced_motion:
			title.modulate.a *= smoothstep(0.15, 0.9, _formation)
			subtitle.modulate.a *= smoothstep(0.15, 0.9, _formation)
			for label in _loading_labels:
				label.modulate.a = 1.0 - smoothstep(0.0, 0.65, _formation)
	var extent := Vector2(size.x * 0.5, size.y * 0.52).length()
	wave_material.set_shader_parameter("wave_radius", lerpf(minf(size.x, size.y) * 0.33, extent * 1.35, wave_progress))
	wave_material.set_shader_parameter("wave_energy", wave_energy)
	wave_material.set_shader_parameter("strength_pixels", wave_strength)
	wave_material.set_shader_parameter("band_width", wave_width)
	wave_material.set_shader_parameter("flare", flare)
	if home_visibility != _last_arrival:
		_last_arrival = home_visibility
		arrival_progress.emit(home_visibility)
	var draw_state := Vector4(seal_scale,seal_alpha,1.0 if started else 0.0,wave_progress)
	if draw_state != _draw_state:
		_draw_state = draw_state
		stage.queue_redraw()


func reveal_from_loading(loading: DepartureRitual) -> void:
	_forming = true
	_formation = 0.0
	# Only the welcome runs while Bootstrap keeps the application suspended.
	process_mode = Node.PROCESS_MODE_ALWAYS
	loading.set_process(false)
	# Loading lives in the output CanvasLayer; Stage uses GameDisplay's logical
	# coordinates. Preserve the rendered placement across that scale boundary.
	var into_stage := get_global_transform_with_canvas().affine_inverse() * loading.get_global_transform_with_canvas()
	var output_scale := into_stage.get_scale()
	var backdrop := loading.get_node("Backdrop") as RitualBackdrop
	_clock = backdrop.clock
	_rotation_clock = _clock
	var retired := stage.get_node("Backdrop")
	retired.name = "RetiredBackdrop"
	retired.queue_free()
	backdrop.reparent(stage, false)
	stage.move_child(backdrop, 0)
	_loading_ring = loading.get_node("LoadingRunes") as Node2D
	var ring_transform := into_stage * _loading_ring.transform
	_loading_ring.reparent(stage, false)
	_loading_ring.transform = ring_transform
	_loading_feedback = loading.feedback
	var feedback_position := into_stage * _loading_feedback.position
	_loading_feedback.reparent(stage, false)
	_loading_feedback.position = feedback_position
	_loading_feedback.scale *= output_scale
	var duration := 0.32 if reduced_motion else 1.6
	var reveal := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_property(self, "_formation", 1.0, duration)
	reveal.tween_property(backdrop, "formation", 1.0, duration)
	# One title grows in place; two copies never crossfade over each other.
	for pair: Array in [[title, loading.get_node("Book")], [subtitle, loading.get_node("Chapter")]]:
		var label := pair[0] as Label
		var source := pair[1] as Label
		var source_position := into_stage * source.position
		if reduced_motion:
			source.reparent(stage, false)
			source.position = source_position
			source.scale *= output_scale
			_loading_labels.append(source)
			continue
		var destination := label.position
		var ratio := float(source.get_theme_font_size("font_size")) / label.get_theme_font_size("font_size") * output_scale.y
		label.pivot_offset = label.size * 0.5
		label.position = into_stage * (source.position + source.size * 0.5) - label.size * 0.5
		label.position.y = source_position.y - label.pivot_offset.y * (1.0 - ratio)
		label.scale = Vector2.ONE * ratio
		reveal.tween_property(label, "position", destination, duration)
		reveal.tween_property(label, "scale", Vector2.ONE, duration)
	dust.modulate.a = 0.0
	reveal.tween_property(dust, "modulate:a", 1.0, duration)
	_process(0.0)
	loading.hide()
	reveal.chain().tween_callback(func() -> void:
		_forming = false
		_loading_ring.queue_free()
		_loading_feedback.queue_free()
		_loading_ring = null
		_loading_feedback = null
		for label in _loading_labels: label.queue_free()
		_loading_labels.clear()
		loading.completed.emit()
		loading.queue_free()
		process_mode = Node.PROCESS_MODE_INHERIT
		welcome_ready.emit()
	)

func _ritual_cue(phase: String, cue: String) -> void:
	phase_label.text = phase
	_cue(cue)

func _cue(cue: String) -> void:
	if cue_requested.has_connections():
		cue_requested.emit(cue)
	elif sound != null:
		sound.play_cue(cue)

func _begin_skip(duration: float) -> void:
	skipping = true
	timeline.pause()
	dust.speed_scale = 0.0
	var fade := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(self, "modulate:a", 0.0, duration)
	fade.tween_property(self, "home_visibility", 1.0, duration)
	fade.chain().tween_callback(_finish)

func _finish() -> void:
	if finished:
		return
	finished = true
	arrival_progress.emit(1.0)
	entered.emit()
	queue_free()

func _draw_stage() -> void:
	if not started:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.385)
	var extent := Vector2(size.x * 0.5, size.y * 0.52).length()
	var ring_radius := lerpf(minf(size.x, size.y) * 0.33, extent * 1.35, wave_progress)
	for band: Vector2 in [Vector2(10.0, 0.003), Vector2(5.0, 0.007), Vector2(2.0, 0.012)]:
		stage.draw_arc(center, ring_radius, 0.0, TAU, 256, Color(0.77, 0.85, 0.93, band.y * seal_alpha), band.x, true)
	for i in 240:
		var angle := float(i) * TAU / 240.0
		stage.draw_circle(center + Vector2.from_angle(angle) * ring_radius * 1.24, 0.8, Color(0.77, 0.85, 0.93, 0.026 * seal_alpha))
	stage.draw_arc(center, ring_radius * 1.54, 0.0, TAU, 256, Color(0.77, 0.85, 0.93, 0.002 * seal_alpha), 5.0, true)
