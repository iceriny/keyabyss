class_name BattleAudio
extends Node2D
## Short-lived spatial voices play only committed battle events.

const MAX_VOICES := 14
const CUE_GAIN := {
	"cast.frost": 0.42, "cast.storm": 0.40, "cast.spirit": 0.40, "cast.flame": 0.42,
	"impact.frost": 0.29, "impact.storm": 0.26, "impact.spirit": 0.28, "impact.flame": 0.30,
	"dash": 0.34, "parry.activate": 0.22, "parry": 0.56, "hit": 0.48, "kill": 0.28,
	"ultimate.frost": 0.62, "ultimate.storm": 0.62, "ultimate.spirit": 0.62, "ultimate.flame": 0.62,
	"victory": 0.52, "defeat": 0.48,
	"key": 0.12, "ready": 0.42, "charge": 0.24, "laser": 0.24, "chapter": 0.3,
	"parry.ring": 0.25, "overload": 0.23, "impact.blast": 0.28,
	"melee.swing": 0.24, "spirit.summon": 0.16,
}
const SHORT_CUES := {"key": 0.11, "parry.activate": 0.18, "parry.ring": 0.8, "charge": 0.68, "melee.swing": 0.3, "spirit.summon": 0.6}
const CENTERED_CUES := ["key", "hit", "ready", "chapter", "victory", "defeat"]

var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			stop_all()
var effects_volume: float = 1.0
var _streams: Dictionary[String, Array] = {}
var _last_played: Dictionary[String, float] = {}
var _previous_variant: Dictionary[String, int] = {}
var _voices: Array[AudioStreamPlayer2D] = []
var _voice_priority: Dictionary[AudioStreamPlayer2D, int] = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for cue: String in CUE_GAIN:
		var variants: Array[AudioStream] = []
		for index in 3:
			variants.append(load("res://assets/audio/battle/%s%s.wav" % [cue.replace(".", "-"), "" if index == 0 else "-%d" % (index+1)]) as AudioStream)
		_streams[cue] = variants


func present(event: Dictionary, viewport_size: Vector2) -> void:
	var cue := ""
	var at: Vector2 = event.get("at", Vector2(0.5, 0.5))
	match event.kind:
		&"manual_input": cue = "key"
		&"ultimate_ready": cue = "ready"
		&"warning", &"hazard_warning": cue = "charge"
		&"hazard_active": cue = "laser" if event.hazard == &"laser" else "impact.blast"
		&"pickup_trigger": cue = "parry" if event.pickup == &"rune" else "impact.blast"
		&"enemy_shot": cue = "laser"
		&"melee_swing": cue = "melee.swing"
		&"spirit_summon": cue = "spirit.summon"
		&"wave": cue = "chapter"
		&"cast":
			cue = "cast.%s" % event.book
			if event.empowered and event.book == &"storm":
				_play("overload", at * viewport_size)
		&"impact":
			var source := str(event.source)
			if source.begins_with("flame_burn"):
				return
			if source == "flame_burst" and event.get("empowered", false):
				_play("impact.blast", at * viewport_size)
			for book in ["frost", "storm", "spirit", "flame"]:
				if source.begins_with(book):
					cue = "impact." + book
					break
		&"death": cue = "kill"
		&"dodge": cue = "dash"
		&"parry_start": cue = "parry.activate"
		&"counter_pulse":
			cue = "parry"
			_play("parry.ring", at * viewport_size)
		&"enemy_attack":
			if event.outcome == &"hit":
				cue = "hit"
		&"ultimate": cue = "ultimate.%s" % event.book
	if not cue.is_empty():
		_play(cue, at * viewport_size)


func play_result(victory: bool, viewport_size: Vector2) -> void:
	_play("victory" if victory else "defeat", viewport_size * 0.5)


func stop_all() -> void:
	for voice in _voices:
		voice.stop()
		voice.queue_free()
	_voices.clear()
	_voice_priority.clear()


func _play(cue: String, at: Vector2) -> void:
	if not enabled or effects_volume <= 0.0:
		return
	var cooldown := 0.08 if cue.begins_with("impact") else (0.15 if cue in ["charge", "laser", "melee.swing", "spirit.summon"] else 0.02)
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_played.get(cue, -INF) < cooldown:
		return
	var priority := 5 if cue.begins_with("ultimate") or cue in ["victory", "defeat", "parry", "hit", "ready"] else (4 if cue in ["charge", "laser", "melee.swing", "parry.ring"] else 1)
	if _voices.size() >= MAX_VOICES:
		var retired: AudioStreamPlayer2D = null
		for active in _voices:
			if _voice_priority[active] < priority and (retired == null or _voice_priority[active] < _voice_priority[retired]):
				retired = active
		if retired == null:
			return
		_release(retired)
	_last_played[cue] = now
	# Audio variation is independent of the seeded combat RNG and never repeats immediately.
	var variant := _rng.randi_range(0, 1)
	var previous: int = _previous_variant.get(cue, -1)
	if previous < 0:
		variant = _rng.randi_range(0, 2)
	elif variant >= previous:
		variant += 1
	_previous_variant[cue] = variant
	var voice := AudioStreamPlayer2D.new()
	voice.stream = _streams[cue][variant]
	voice.bus = "Threats" if cue in ["hit", "defeat", "charge", "laser", "melee.swing"] else "Spells"
	voice.volume_db = linear_to_db(float(CUE_GAIN[cue]) * effects_volume)
	voice.max_distance = 2500.0
	voice.attenuation = 0.25
	voice.panning_strength = 0.0 if cue in CENTERED_CUES else 0.5
	if cue in CENTERED_CUES:
		voice.attenuation = 0.0
	voice.position = at
	add_child(voice)
	_voices.append(voice)
	_voice_priority[voice] = priority
	voice.finished.connect(_release.bind(voice))
	voice.play()
	if SHORT_CUES.has(cue):
		var release := voice.create_tween()
		release.tween_interval(maxf(0.0, minf(float(SHORT_CUES[cue]), voice.stream.get_length()) - 0.04))
		release.tween_property(voice, "volume_db", -60.0, 0.04)
		release.tween_callback(_release.bind(voice))


func _release(voice: AudioStreamPlayer2D) -> void:
	_voices.erase(voice)
	_voice_priority.erase(voice)
	voice.stop()
	voice.queue_free()
