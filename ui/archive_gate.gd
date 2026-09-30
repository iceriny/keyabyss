class_name ArchiveGate
extends Control
## Transient HDR stage; the lens never samples the underlying interactive UI.
signal entered
signal cue_requested(cue: String)
signal arrival_progress(value: float)

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
var orbit_energy := 0.008
var home_visibility := 0.0
var _clock := 0.0
var _draw_state := Vector3(-1.0,-1.0,-1.0)
var _last_arrival := -1.0
var stage_viewport: SubViewport
var stage: Control
var timeline: AnimationPlayer
var dust: GPUParticles2D
var orbit: Control
var mark: Control
var title: Label
var subtitle: Label
var prompt: Label
var prompt_hint: Label
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
	stage.draw.connect(_draw_stage)
	orbit = $RitualViewport/Stage/Orbit
	mark = $RitualViewport/Stage/Mark
	title = $RitualViewport/Stage/Title
	subtitle = $RitualViewport/Stage/Subtitle
	prompt = $RitualViewport/Stage/Prompt
	prompt_hint = $RitualViewport/Stage/PromptHint
	dust = $RitualViewport/Stage/ArchiveDust
	wave = $Wave
	wave_material = wave.material as ShaderMaterial
	phase_label = $PhaseLabel
	phase_small = $PhaseSmall
	timeline = $RitualTimeline
	orbit.set("reduced_motion", reduced_motion)
	mark.set("reduced_motion", reduced_motion)
	dust.process_material = dust.process_material.duplicate(true)
	(dust.process_material as ParticleProcessMaterial).color = Color(0.90, 0.81, 0.63, 0.3)
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
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	orbit.size = Vector2.ONE * minf(size.x * 0.78, 740.0)
	orbit.position = center - orbit.size * 0.5
	var mark_size := clampf(minf(size.x, size.y) * 0.26, 230.0, 340.0)
	mark.size = Vector2.ONE * mark_size
	mark.position = Vector2(size.x * 0.5 - mark_size * 0.5, size.y * 0.5 - mark_size * 1.12 + 50)
	mark.pivot_offset = mark.size * 0.5
	var text_width := minf(size.x * 0.8, 640.0)
	var text_left := (size.x - text_width) * 0.5
	title.position = Vector2(text_left, size.y * 0.5 + mark_size * 0.02 + 50)
	title.size = Vector2(text_width, 80.0)
	subtitle.position = Vector2(text_left, title.position.y + 82.0)
	subtitle.size = Vector2(text_width, 35.0)
	prompt.position = Vector2(text_left, subtitle.position.y + 76.0)
	prompt.size = Vector2(text_width, 40.0)
	prompt_hint.position = Vector2(text_left, prompt.position.y + 42.0)
	prompt_hint.size = Vector2(text_width, 30.0)
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
		prompt_hint.visible = false
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
	orbit.set("clock", _clock)
	mark.set("clock", _clock)
	if not started and not reduced_motion:
		prompt.modulate.a = 0.775 + 0.225 * cos(_clock * TAU / 3.2)
	mark.scale = Vector2.ONE * seal_scale
	mark.modulate = Color(1.0 + flare, 1.0 + flare, 1.0 + flare, seal_alpha)
	title.modulate.a = seal_alpha
	subtitle.modulate.a = seal_alpha
	orbit.modulate.a = orbit_energy
	var extent := Vector2(size.x * 0.5, size.y * 0.52).length()
	wave_material.set_shader_parameter("wave_radius", lerpf(minf(size.x, size.y) * 0.08, extent * 1.15, wave_progress))
	wave_material.set_shader_parameter("wave_energy", wave_energy)
	wave_material.set_shader_parameter("strength_pixels", wave_strength)
	wave_material.set_shader_parameter("band_width", wave_width)
	wave_material.set_shader_parameter("flare", flare)
	if home_visibility != _last_arrival:
		_last_arrival = home_visibility
		arrival_progress.emit(home_visibility)
	var draw_state := Vector3(seal_scale,seal_alpha,1.0 if started else 0.0)
	if draw_state != _draw_state:
		_draw_state = draw_state
		stage.queue_redraw()

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
	stage.draw_rect(Rect2(Vector2.ZERO, size), Color("080e16"))
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	for i in 10:
		var fraction := float(i + 1) / 10.0
		stage.draw_circle(center, minf(size.x, size.y) * (0.15 + fraction * 0.62), Color(0.33, 0.47, 0.42, 0.005 * (1.0 - fraction)))
	var ring_radius := minf(size.x, size.y) * 0.33 * seal_scale
	stage.draw_arc(center, ring_radius, 0.0, TAU, 256, Color(0.77, 0.85, 0.93, 0.047 * seal_alpha), 1.0, true)
	for i in 240:
		var angle := float(i) * TAU / 240.0
		stage.draw_circle(center + Vector2.from_angle(angle) * ring_radius * 1.24, 0.8, Color(0.77, 0.85, 0.93, 0.026 * seal_alpha))
	stage.draw_arc(center, ring_radius * 1.54, 0.0, TAU, 256, Color(0.77, 0.85, 0.93, 0.004 * seal_alpha), 1.0, true)
	if not started:
		for i in 32:
			var x := float(i) / 32.0
			stage.draw_line(Vector2(size.x * 0.5 - 100 + x * 200, prompt.position.y - 24), Vector2(size.x * 0.5 - 100 + (x + 1.0 / 32.0) * 200, prompt.position.y - 24), Color(0.77, 0.67, 0.40, pow(sin(x * PI) * 0.44, 2.2)), 1.0)
