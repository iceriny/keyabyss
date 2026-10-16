extends SceneTree
## Native PCM selection and real UI/input feedback; no audition interface.

var failures := 0
var checks := 0
var app: KeyabyssApp
var feedback: Array[StringName] = []
var rejected: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(749)
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/cues.json"))
	_check(mapping.size() == ArchiveAudio.CUES.size() + BattleAudio.CUE_GAIN.size(), "all runtime cues have a selected library group")
	for cue: String in mapping:
		var pool := SoundBank.load_cue(cue)
		_check(pool.streams_count == 4 and pool.playback_mode == AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS, cue + " has four native no-repeat variants")
		var fingerprints: Dictionary = {}
		for index in pool.streams_count:
			var clip := pool.get_stream(index) as AudioStreamWAV
			_check(clip != null and clip.mix_rate == 48000 and clip.loop_mode == AudioStreamWAV.LOOP_DISABLED, cue + " imports bounded-rate nonlooping PCM")
			fingerprints[_fingerprint(clip)] = index
		_check(fingerprints.size() == 4, cue + " contains four distinct audible waveforms")
		var previous := ""
		var heard: Dictionary = {}
		for iteration in 32:
			var actual := _fingerprint(pool)
			_check(fingerprints.has(actual) and actual != previous, cue + " engine chooses a source variant without immediate repeat")
			heard[actual] = true
			previous = actual
		_check(heard.size() == 4, cue + " engine uses every variant")
	await _settle()
	await _runtime()
	await _application()
	print("Audio: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _fingerprint(stream: AudioStream) -> String:
	var playback := stream.instantiate_playback()
	playback.start()
	var pcm := playback.mix_audio(1.0, 8192).to_byte_array()
	playback.stop()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(pcm)
	return digest.finish().hex_encode()


func _runtime() -> void:
	var archive := ArchiveAudio.new()
	root.add_child(archive)
	archive.play_cue("ui.type")
	_check(_ui_count(archive, "ui.type") == 1, "UI transient starts immediately")
	await create_timer(0.24).timeout
	_check(_ui_count(archive, "ui.type") == 0, "randomizer UI transient uses configured release, not wrapper length")
	for iteration in 6:
		archive.play_cue("ui.book")
		await create_timer(0.03).timeout
	await create_timer(0.09).timeout
	_check(_ui_count(archive, "ui.book") == 1, "rapid book changes leave one voice")
	archive.enabled = false
	archive.play_cue("ui.confirm")
	_check(_ui_count(archive) == 0, "UI mute retires voices and blocks new playback")
	archive.queue_free()
	var battle := BattleAudio.new()
	root.add_child(battle)
	var size := Vector2(1920, 1080)
	var events := [
		{"kind": &"cast", "book": &"frost", "empowered": false, "at": Vector2(.2, .3)},
		{"kind": &"impact", "source": &"frost", "at": Vector2(.2, .3)},
		{"kind": &"enemy_attack", "outcome": &"hit"},
		{"kind": &"enemy_shot"}, {"kind": &"hazard_active", "hazard": &"laser"},
		{"kind": &"boss_phase"}, {"kind": &"enemy_heal"},
		{"kind": &"pickup_trigger", "pickup": &"rune"},
		{"kind": &"pickup_trigger", "pickup": &"ink"},
		{"kind": &"spirit_summon"}, {"kind": &"melee_swing"},
		{"kind": &"action_rejected"},
	]
	for event: Dictionary in events:
		battle.present(event, size)
	_check(_battle_cues(battle) == ["cast.frost", "impact.frost", "hit", "enemy.shot", "laser", "boss.phase", "enemy.heal", "pickup.rune", "impact.blast", "spirit.summon", "melee.swing", "unavailable"], "committed events select distinct feedback")
	_check(battle._voices[0].panning_strength > 0.0 and battle._voices[2].panning_strength == 0.0, "world sounds are spatial and damage is centered")
	battle.stop_all()
	battle.present({"kind": &"counter_pulse", "grade": &"success"}, size)
	_check(_battle_cues(battle) == ["parry"], "ordinary parry has one restrained sound")
	battle.stop_all()
	battle.present({"kind": &"counter_pulse", "grade": &"perfect"}, size)
	_check(_battle_cues(battle) == ["parry.ring", "parry.perfect"], "perfect parry adds resonance and distinct impact")
	battle.stop_all()
	battle.present({"kind": &"impact", "source": &"flame_burn"}, size)
	_check(battle._voices.is_empty(), "continuous burn does not spam hit sounds")
	battle.play_input("key", size)
	await create_timer(0.24).timeout
	_check(battle._voices.is_empty(), "randomizer battle transient retires on time")
	battle.stop_all()
	battle._last_played.clear()
	for index in BattleAudio.MAX_VOICES:
		battle._last_played.erase("key")
		battle.play_input("key", size)
	battle.present({"kind": &"enemy_attack", "outcome": &"hit"}, size)
	_check(battle._voices.size() == BattleAudio.MAX_VOICES and _battle_cues(battle).has("hit"), "damage displaces a typing voice at capacity")
	battle.enabled = false
	_check(battle._voices.is_empty(), "battle mute clears all voices")
	battle.queue_free()
	await process_frame


func _application() -> void:
	var evidence := "res://.temp/audio-upgrade/run-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.settings.sound = true
	app.settings.ambience = false
	app.settings.reduce_motion = true
	app.settings.fullscreen = false
	app.settings.progressive = false
	app.settings.quality = 0
	app.settings.fluid_quality = 0
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.settings.vocabulary_id = app.vocabulary.save_import(app.vocabulary.parse_import("word,meaning\ncat,猫\ncar,车\ndog,狗", "audio.csv"))
	_check(app.settings.save_settings(), "isolated audio settings save")
	app.profile_base_path = evidence.path_join("profiles")
	app.presentation_enabled = false
	root.add_child(app)
	await _settle()
	app.archive.set_prepared(true)
	_check(_ui_count(app.sound, "ui.open") == 1 and _ui_count(app.sound, "ui.select") == 0, "preparation opens with one main sound")
	app.sound.stop_all()
	app.archive.set_prepared(true)
	_check(_ui_count(app.sound) == 0, "same preparation state is silent")
	app.archive.set_prepared(false)
	_check(_ui_count(app.sound, "ui.close") == 1, "keyboard preparation return has closing feedback")
	app.sound.stop_all()
	app.archive._difficulty(2)
	_check(_ui_count(app.sound, "ui.tab") == 1, "difficulty change has feedback")
	app.sound.stop_all()
	app.archive._difficulty(2)
	_check(_ui_count(app.sound) == 0, "same difficulty is silent")
	# Initial configuration and Backspace update labels, not physical character sounds.
	app.sound._last_played.clear()
	await _key(KEY_G, "g")
	_check(app.sound._last_played.has("ui.type") and app.router.buffer == "g", "accepted command character has typing feedback")
	app.sound.stop_all()
	await _key(KEY_BACKSPACE)
	_check(_ui_count(app.sound) == 0, "command Backspace does not play a new character")
	await _key(KEY_X, "x")
	_check(_ui_count(app.sound, "ui.invalid") == 1, "rejected command character has feedback")
	app._start_practice()
	await _settle()
	app.sound.stop_all()
	app.sound._last_played.clear()
	app.practice.typing.feed("x")
	_check(_ui_count(app.sound, "ui.invalid") == 1, "practice failed judgement has feedback")
	app.sound.stop_all()
	app._pause()
	_check(_ui_count(app.sound, "ui.open") == 1, "pause opens with one main sound")
	app.sound._last_played.clear()
	app.sound.stop_all()
	app._resume()
	_check(_ui_count(app.sound, "ui.close") == 1 and not paused, "resume has closing feedback and restores time")
	app._home()
	await _settle()
	app._settings_page("home")
	app.sound.stop_all()
	app.sound._last_played.clear()
	var meanings := app.settings_controls["show_meaning"] as CheckButton
	meanings.button_pressed = not meanings.button_pressed
	_check(_ui_count(app.sound, "ui.tab") == 1, "actual setting toggle has feedback")
	app.sound.stop_all()
	meanings.toggled.emit(meanings.button_pressed)
	_check(_ui_count(app.sound) == 0, "unchanged setting is silent")
	app.sound._last_played.clear()
	(app.settings_controls["effects_volume"] as HSlider).drag_ended.emit(true)
	_check(_ui_count(app.sound, "ui.confirm") == 1, "effect volume uses one drag-end confirmation")
	app._home()
	await _settle()
	app.archive.set_prepared(true)
	app.settings.difficulty = "normal"
	app._launch_prepared()
	for iteration in 180:
		await process_frame
		if app.route == "battle": break
	_check(app.route == "battle", "formal battle starts for audio integration")
	var session := app.battle.session
	session.set_physics_process(false)
	var targets: Dictionary[StringName, String] = {&"cat": "cat", &"car": "car"}
	session.typing.set_targets(targets)
	session.typing.feedback_requested.connect(func(cue: StringName) -> void: feedback.append(cue))
	session.event_committed.connect(func(event: Dictionary) -> void:
		if event.kind == &"action_rejected": rejected.append(event.action))
	app.battle.audio.stop_all()
	var combat_rng := session._rng.state
	await _key(KEY_X, "x")
	_check(_battle_cues(app.battle.audio) == ["mistake"], "wrong battle letter uses existing failed judgement exactly once")
	await _key(KEY_TAB)
	await _key(KEY_BACKSPACE)
	_check(feedback == [&"target", &"cancel"], "Tab and explicit abandonment have feedback")
	_check(session._rng.state == combat_rng, "audio randomness does not consume seeded combat state")
	session.parry_cooldown = 0.5
	session.dodge_charges = 0.0
	session.resonance_q = 0
	for action: StringName in [&"parry", &"dodge_left", &"ultimate"]:
		session._commit_action(action)
	_check(rejected == [&"parry", &"dodge_left", &"ultimate"], "failed defenses and ultimate report committed rejection")
	# A paid reward fact crosses exactly one threshold through the real settlement.
	session.reward_facts.append(RewardFact.new("audio-fixture", RewardPolicy.INITIAL_THRESHOLD, session.chapter, false))
	session.manual_characters = TalentProgress.CHARACTERS_PER_LEVEL
	app.sound.stop_all()
	app.sound._last_played.clear()
	session._end(true)
	await _settle()
	_check(app.route == "reward", "real room settlement opens a reward offer")
	_check(app.profile.manual_characters == TalentProgress.CHARACTERS_PER_LEVEL and _ui_count(app.sound, "ui.level") == 1 and _ui_count(app.sound, "ui.open") == 0, "saved growth threshold has one level sound")
	app.sound.stop_all()
	app.sound._last_played.clear()
	var first_id := StringName(app.run.offer.candidates[0])
	app._show_reward_detail(app.run.compiler.catalog.get_definition(first_id))
	_check(_ui_count(app.sound, "ui.open") == 1, "reward detail opens audibly")
	app.sound.stop_all()
	app._back()
	_check(_ui_count(app.sound, "ui.close") == 1, "Escape detail dismissal has feedback")
	await _settle()
	app.sound.stop_all()
	app.sound._last_played.clear()
	app.commands["reroll"].call()
	_check(_ui_count(app.sound, "ui.reroll") == 1 and _ui_count(app.sound, "ui.open") == 0 and _ui_count(app.sound, "ui.select") == 0, "successful reroll rebuilds without extra menu sounds")
	app.sound.stop_all()
	app.sound._last_played.clear()
	app._choose_reward(&"invalid-fixture", str(app.run.offer.id), null)
	_check(_ui_count(app.sound, "ui.invalid") == 1 and app.route == "reward", "failed reward has rejection feedback")
	app.sound.stop_all()
	app.sound._last_played.clear()
	app._choose_reward(StringName(app.run.offer.candidates[0]), str(app.run.offer.id), null)
	_check(_ui_count(app.sound, "ui.reward") == 1 and _ui_count(app.sound, "ui.open") == 0 and _ui_count(app.sound, "ui.select") == 0, "successful reward has one acquisition sound")
	app.sound.stop_all()
	app.sound._last_played.clear()
	app._choose_route("invalid-fixture")
	_check(_ui_count(app.sound, "ui.invalid") == 1, "failed route has rejection feedback")
	app.sound.stop_all()
	app.sound._last_played.clear()
	app._choose_route("offering")
	_check(_ui_count(app.sound, "ui.route") == 1 and _ui_count(app.sound, "ui.open") == 0, "successful route has one result sound")
	# Empty eligibility is the supply branch of a legitimately earned opportunity.
	app.run.offer.candidates.clear()
	app._show_run_stage(false)
	app.sound.stop_all()
	app.sound._last_played.clear()
	app.commands["supply"].call()
	_check(_ui_count(app.sound, "ui.supply") == 1 and _ui_count(app.sound, "ui.open") == 0, "successful supply has one restorative sound")
	app.queue_free()
	await _settle()


func _ui_count(sound: ArchiveAudio, cue: String = "") -> int:
	var count := 0
	for voice: AudioStreamPlayer in sound._voices:
		if voice.playing and (cue.is_empty() or sound._voice_cues.get(voice) == cue): count += 1
	return count


func _battle_cues(sound: BattleAudio) -> Array[String]:
	var cues: Array[String] = []
	for voice: AudioStreamPlayer2D in sound._voices: cues.append(voice.get_meta("cue"))
	return cues


func _key(code: Key, character: String = "") -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = character.unicode_at(0) if not character.is_empty() else 0
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _settle() -> void:
	for iteration in 5: await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
