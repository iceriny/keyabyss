class_name ArchiveAudio
extends Node


const MAX_VOICES := 16
const BOOK_RELEASE_SECONDS := 0.05
const AMBIENCE_RATE := 48000
const AMBIENCE_SAMPLES := AMBIENCE_RATE * 4
const AMBIENCE_GAIN := 0.025
const CUES := {
	"ui.tab": {"gain": 0.3, "cooldown": 0.1, "limit": 2, "priority": 2, "duration": 0.28},
	"ui.enter": {"gain": 0.5, "cooldown": 1.5, "limit": 1, "priority": 6, "duration": 1.1},
	"ui.book": {"gain": 0.48, "cooldown": 0.16, "limit": 2, "priority": 5, "duration": 0.85},
	"ui.type": {"gain": 0.14, "cooldown": 0.018, "limit": 4, "priority": 2, "duration": 0.09},
	"ui.focus": {"gain": 0.16, "cooldown": 0.08, "limit": 2, "priority": 1, "duration": 0.22},
	"ui.select": {"gain": 0.4, "cooldown": 0.08, "limit": 3, "priority": 4, "duration": 0.48},
	"ui.open": {"gain": 0.38, "cooldown": 0.15, "limit": 3, "priority": 4, "duration": 0.7},
	"ui.close": {"gain": 0.34, "cooldown": 0.15, "limit": 3, "priority": 4, "duration": 0.6},
	"ui.confirm": {"gain": 0.45, "cooldown": 0.15, "limit": 3, "priority": 4, "duration": 1.0},
	"ui.invalid": {"gain": 0.28, "cooldown": 0.18, "limit": 2, "priority": 3, "duration": 0.35},
	"ui.ritualRise": {"gain": 0.45, "cooldown": 1.0, "limit": 1, "priority": 6, "duration": 0.864},
	"ui.ritualImpact": {"gain": 0.7, "cooldown": 1.0, "limit": 1, "priority": 7, "duration": 2.35},
	"ui.ritualChime": {"gain": 0.4, "cooldown": 0.5, "limit": 2, "priority": 5, "duration": 0.8},
	"ui.reward": {"gain": 0.45, "cooldown": 0.15, "limit": 2, "priority": 5, "duration": 1.6},
	"ui.reroll": {"gain": 0.38, "cooldown": 0.15, "limit": 2, "priority": 4, "duration": 0.7},
	"ui.supply": {"gain": 0.4, "cooldown": 0.15, "limit": 2, "priority": 5, "duration": 1.2},
	"ui.route": {"gain": 0.4, "cooldown": 0.15, "limit": 2, "priority": 5, "duration": 1.2},
	"ui.level": {"gain": 0.45, "cooldown": 1.0, "limit": 1, "priority": 6, "duration": 2.0},
}

@export var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			stop_all()

@export_range(0.0, 1.0) var effects_volume: float = 1.0:
	set(value):
		effects_volume = clampf(value, 0.0, 1.0)
		_update_voice_volumes()

var _streams: Dictionary[String, AudioStreamRandomizer] = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_cues: Dictionary = {}
var _voice_gains: Dictionary = {}
var _voice_serials: Dictionary = {}
var _voice_tweens: Dictionary = {}
var _last_played: Dictionary = {}
var _ambience_player: AudioStreamPlayer


func _ready() -> void:
	for cue: String in CUES:
		_streams[cue] = SoundBank.load_cue(cue)


func play_cue(cue: String) -> void:
	if not enabled or effects_volume <= 0.0 or not CUES.has(cue):
		return
	var definition: Dictionary = CUES[cue]
	var now := Time.get_ticks_msec() * 0.001
	if cue != "ui.book" and now - float(_last_played.get(cue, -INF)) < float(definition["cooldown"]):
		return
	var active := 0
	for voice: AudioStreamPlayer in _voices:
		if voice.playing and _voice_cues.get(voice) == cue:
			active += 1
	if cue != "ui.book" and active >= int(definition["limit"]):
		return
	var voice := _get_book_voice(active, int(definition["limit"]), int(definition["priority"])) if cue == "ui.book" else _get_voice(int(definition["priority"]))
	if voice == null:
		return
	if cue == "ui.book":
		_release_previous_books(voice)
	if cue != "ui.book":
		_last_played[cue] = now
	_prepare_voice(voice)
	voice.stream = _streams[cue]
	voice.bus = &"UI"
	_voice_cues[voice] = cue
	_voice_gains[voice] = float(definition["gain"])
	voice.volume_db = linear_to_db(maxf(0.0001, float(definition["gain"]) * effects_volume))
	var offset := float(definition.get("offset", 0.0))
	voice.play(offset)
	if definition.has("duration"):
		# The randomizer has no fixed length; natural completion retires shorter clips.
		_finish_after(voice, int(_voice_serials[voice]), float(definition["duration"]))


func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		_prepare_voice(voice)
		voice.stop()


func set_ambience(active: bool) -> void:
	if not active:
		if _ambience_player != null:
			_ambience_player.stop()
		return
	if _ambience_player == null:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = AMBIENCE_RATE
		stream.stereo = false
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = AMBIENCE_SAMPLES
		var pcm := PackedByteArray()
		pcm.resize(AMBIENCE_SAMPLES * 2)
		for sample_index in AMBIENCE_SAMPLES:
			var time := float(sample_index) / float(AMBIENCE_RATE)
			var envelope := pow(sin(PI * time / 4.0), 2.0)
			var value := envelope * (sin(time * PI * 220.0) + 0.3 * sin(time * PI * 330.0)) * 0.22
			pcm.encode_s16(sample_index * 2, roundi(value * 32767.0))
		stream.data = pcm
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.bus = &"Ambience"
		_ambience_player.volume_db = linear_to_db(AMBIENCE_GAIN)
		_ambience_player.stream = stream
		add_child(_ambience_player)
	if not _ambience_player.playing:
		_ambience_player.play()


func _get_voice(priority: int) -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice
	if _voices.size() < MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"UI"
		add_child(voice)
		voice.finished.connect(_on_voice_finished.bind(voice))
		_voices.append(voice)
		_voice_serials[voice] = 0
		return voice
	var candidate: AudioStreamPlayer
	var lowest := priority
	for voice: AudioStreamPlayer in _voices:
		var active_cue: String = _voice_cues.get(voice, "")
		var voice_priority := int(CUES[active_cue].get("priority", 0)) if CUES.has(active_cue) else 0
		if voice_priority < lowest:
			candidate = voice
			lowest = voice_priority
	return candidate


func _get_book_voice(active: int, limit: int, priority: int) -> AudioStreamPlayer:
	if active >= limit:
		for voice: AudioStreamPlayer in _voices:
			if voice.playing and _voice_cues.get(voice) == "ui.book" and _voice_tweens.has(voice):
				return voice
		for voice: AudioStreamPlayer in _voices:
			if voice.playing and _voice_cues.get(voice) == "ui.book":
				return voice
	var available := _get_voice(priority)
	if available != null:
		return available
	for voice: AudioStreamPlayer in _voices:
		if voice.playing and _voice_cues.get(voice) == "ui.book":
			return voice
	return null


func _prepare_voice(voice: AudioStreamPlayer) -> void:
	if _voice_tweens.has(voice):
		var tween: Tween = _voice_tweens[voice]
		if tween.is_running():
			tween.kill()
		_voice_tweens.erase(voice)
	_voice_serials[voice] = int(_voice_serials.get(voice, 0)) + 1
	_voice_cues.erase(voice)
	_voice_gains.erase(voice)
	if voice.playing:
		voice.stop()


func _release_previous_books(next_voice: AudioStreamPlayer) -> void:
	for voice: AudioStreamPlayer in _voices:
		if voice == next_voice or not voice.playing or _voice_cues.get(voice) != "ui.book":
			continue
		if _voice_tweens.has(voice):
			continue
		_fade_out_book(voice, int(_voice_serials[voice]))


func _fade_out_book(voice: AudioStreamPlayer, serial: int) -> void:
	var tween := create_tween()
	_voice_tweens[voice] = tween
	tween.tween_property(voice, "volume_db", -60.0, BOOK_RELEASE_SECONDS)
	tween.tween_callback(_on_book_released.bind(voice, serial))


func _on_book_released(voice: AudioStreamPlayer, serial: int) -> void:
	if not is_instance_valid(voice) or int(_voice_serials.get(voice, -1)) != serial:
		return
	voice.stop()
	_voice_cues.erase(voice)
	_voice_gains.erase(voice)
	_voice_tweens.erase(voice)


func _finish_after(voice: AudioStreamPlayer, serial: int, duration: float) -> void:
	await get_tree().create_timer(maxf(0.0, duration - 0.025)).timeout
	if not is_instance_valid(voice) or int(_voice_serials.get(voice, -1)) != serial or not voice.playing:
		return
	var tween := create_tween()
	_voice_tweens[voice] = tween
	tween.tween_property(voice, "volume_db", -60.0, 0.025)
	tween.tween_callback(_on_timed_cue_released.bind(voice, serial))


func _on_timed_cue_released(voice: AudioStreamPlayer, serial: int) -> void:
	if not is_instance_valid(voice) or int(_voice_serials.get(voice, -1)) != serial:
		return
	voice.stop()
	_voice_cues.erase(voice)
	_voice_gains.erase(voice)
	_voice_tweens.erase(voice)


func _on_voice_finished(voice: AudioStreamPlayer) -> void:
	_voice_cues.erase(voice)
	_voice_gains.erase(voice)


func _update_voice_volumes() -> void:
	for voice: AudioStreamPlayer in _voices:
		if voice.playing and _voice_gains.has(voice):
			voice.volume_db = linear_to_db(maxf(0.0001, float(_voice_gains[voice]) * effects_volume))
