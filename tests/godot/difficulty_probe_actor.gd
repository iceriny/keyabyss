extends RefCounted
## Research-informed task model, not a reproduction of the eye/finger simulation.
## Parameters are frozen across tuning rounds. All actions use InputRouter.

const PROFILES := {
	"beginner": [15.5, 13.6, 93.6, 1.239, 0.05, 0.28, 0.20, 0.34],
	"ordinary": [38.7, 28.7, 234.4, 0.301, 0.03, 0.22, 0.12, 0.24],
	"skilled": [51.5, 36.4, 311.1, 0.183, 0.02, 0.18, 0.09, 0.20],
	"expert": [67.2, 44.6, 406.0, 0.111, 0.015, 0.15, 0.06, 0.16],
	"elite": [84.5, 54.4, 512.1, 0.056, 0.01, 0.13, 0.04, 0.14],
}

var rng := RandomNumberGenerator.new()
var key: Callable
var profile: Array
var key_interval: float
var visual_seconds: float
var next_key := 0.0
var next_observation := 0.0
var blocked_until := 0.0
var planned_word := ""
var planned_target: StringName
var planned_index := 0
var preview_target: StringName
var preview_word := ""
var preview_ready := 0.0
var defense_due := -1.0
var defense_key: Key = KEY_NONE
var submitted := 0
var injected_errors := 0
var defense_attempts := 0
var missed_defenses := 0
var ultimate_attempts := 0
var no_target_seconds := 0.0
var defense_pause_seconds := 0.0
var recognition_seconds := 0.0
var key_wait_seconds := 0.0
var selections := 0


func _init(profile_name: String, actor_seed: String, send_key: Callable) -> void:
	profile = PROFILES[profile_name]
	rng.seed = actor_seed.hash()
	key = send_key
	var mean_length: float = profile[2] / profile[0]
	# End-to-end preview throughput already includes boundary and errors.
	# Remove boundary once; reserve error slots once, not an extra blanket penalty.
	key_interval = (60.0 / profile[0] - profile[3]) / mean_length * (1.0 - profile[4])
	visual_seconds = 60.0 / profile[1] - 60.0 / profile[0]


func tick(battle: BattleSession, delta: float, defend: bool = true) -> void:
	var now := battle.elapsed
	if defend and now >= next_observation:
		next_observation = now + 0.10
		_observe_defense(battle)
	if defend and defense_due >= 0.0 and now >= defense_due:
		defense_due = -1.0
		if battle.dodge_window <= 0.0 and battle.parry_window <= 0.0:
			blocked_until = now + float(profile[7])
			if rng.randf() < float(profile[6]):
				missed_defenses += 1
			else:
				key.call(defense_key)
				if defense_key == KEY_SHIFT:
					key.call(KEY_SHIFT, 0, false)
					ultimate_attempts += 1
				else:
					defense_attempts += 1
	if now < blocked_until:
		defense_pause_seconds += delta
		return
	if planned_word.is_empty():
		var selected := _target(battle)
		if selected == &"":
			no_target_seconds += delta
			return
		planned_target = selected
		planned_word = str(battle.typing._targets[selected]).replace(" ", "")
		planned_index = 0
		selections += 1
		var previewed := selected == preview_target and planned_word == preview_word
		var recognition := maxf(0.0, preview_ready - now) if previewed else _visual_cost(battle)
		recognition_seconds += recognition
		next_key = now + recognition + float(profile[3]) * _jitter(0.25) + key_interval * _jitter(0.18)
		preview_target = &""
		preview_word = ""
	if planned_index == 0 and (not battle.typing._targets.has(planned_target) or str(battle.typing._targets[planned_target]).replace(" ", "") != planned_word):
		planned_word = "" # Reacquire a disappeared preview; elapsed work is not refunded.
		return
	if now < next_key:
		key_wait_seconds += delta
		return
	var character := planned_word[planned_index]
	var wrong := planned_index > 0 and rng.randf() < float(profile[4])
	if wrong:
		character = _wrong_letter(battle)
		injected_errors += 1
	else:
		planned_index += 1
	submitted += 1
	key.call(character.to_upper().unicode_at(0), character.unicode_at(0))
	next_key = now + key_interval * _jitter(0.18)
	if planned_index == 1 and preview_target == &"":
		preview_target = _target(battle, planned_target)
		if preview_target != &"":
			preview_word = str(battle.typing._targets[preview_target]).replace(" ", "")
			preview_ready = now + _visual_cost(battle)
	if not wrong and planned_index == planned_word.length():
		planned_word = ""


func _jitter(sigma: float) -> float:
	return exp(rng.randfn(-sigma * sigma * 0.5, sigma))


func _visual_cost(battle: BattleSession) -> float:
	# Search cost is an explicit game prior; does not pretend to model occlusion.
	return visual_seconds * _jitter(0.15) + 0.025 * maxi(0, battle.typing._targets.size() - 2)


func _target(battle: BattleSession, exclude: StringName = &"") -> StringName:
	# Keep one valid preview rather than silently reading every word in parallel.
	if preview_target != exclude and battle.typing._targets.has(preview_target) and str(battle.typing._targets[preview_target]).replace(" ", "") == preview_word:
		return preview_target
	var best: StringName
	var score := -INF
	for id: StringName in battle.typing._targets:
		if id == exclude: continue
		var candidate := 0.0
		var enemy := battle.enemy_by_id(id)
		if enemy != null:
			var distance := ((enemy.position - battle.player_position) * BattleSession.ARENA_SIZE).length()
			candidate = 10.0 + 120.0 / maxf(60.0, distance)
			if enemy.kind in [&"tower", &"priest", &"folio-warden"]: candidate += 6.0
			if enemy.behavior == &"melee" and distance < 200.0: candidate += 4.0
			if enemy.boss: candidate -= 2.0
			if battle.book_id == &"flame" and enemy.burn > 10: candidate -= 5.0
			candidate -= float(enemy.hp_q) / maxf(1.0, enemy.max_hp_q)
		else:
			for pickup in battle.pickups:
				if pickup.id == id and not pickup.consumed:
					candidate = 18.0 if battle.player_hp_q < battle.player_max_hp_q * 0.65 else 2.0
		if candidate > score:
			score = candidate
			best = id
	return best


func _wrong_letter(battle: BattleSession) -> String:
	var prefix := planned_word.left(planned_index)
	var continuations := ""
	for text: String in battle.typing._targets.values():
		var playable := text.replace(" ", "")
		if playable.begins_with(prefix) and playable.length() > planned_index:
			continuations += playable[planned_index]
	continuations += planned_word[planned_index]
	for character in "zqxjvbnmklywpfghsdrtuioeac":
		if character not in continuations: return character
	return "?"


func _observe_defense(battle: BattleSession) -> void:
	if defense_due >= 0.0 or battle.elapsed < blocked_until or battle.dodge_window > 0.0 or battle.parry_window > 0.0: return
	if battle.resonance_q >= BattleSession.ULTIMATE_COST_Q and battle.ultimate_time <= 0.0 and not battle.typing._targets.is_empty():
		defense_key = KEY_SHIFT
		defense_due = battle.elapsed + float(profile[5])
		return
	var eta := INF
	var unblockable := false
	var scale := maxf(0.06, battle.world_time_scale)
	for hazard in battle.hazards:
		if hazard.contains(battle.player_position) and hazard.warning_remaining / scale < 0.65:
			eta = minf(eta, maxf(0.0, hazard.warning_remaining / scale))
			unblockable = true
	for threat in battle.threats:
		if threat.reflected: continue
		# Only extrapolate the observed tangent; no future trajectory/collision oracle.
		var offset := (battle.player_position - threat.position) * BattleSession.ARENA_SIZE
		var velocity := threat.velocity * scale
		if velocity.length_squared() < 1.0: continue
		var arrival := offset.dot(velocity) / velocity.length_squared()
		if arrival > 0.0 and arrival < 0.55 and (offset - velocity * arrival).length() < threat.radius + 28.0:
			eta = minf(eta, arrival)
	for enemy in battle.enemies:
		if not enemy.alive() or not enemy.aiming or enemy.frozen_time > 0.0: continue
		var distance := ((enemy.position - battle.player_position) * BattleSession.ARENA_SIZE).length()
		if (enemy.behavior == &"melee" and distance < 170.0) or (enemy.behavior == &"charge" and distance < 450.0):
			if enemy.attack_clock / scale < 0.55: eta = minf(eta, maxf(0.0, enemy.attack_clock / scale))
	if eta == INF: return
	if unblockable or battle.parry_cooldown > 0.0:
		if battle.dodge_charges < 1.0: return
		defense_key = KEY_ALT
	else:
		defense_key = KEY_SPACE
	defense_due = battle.elapsed + maxf(float(profile[5]), eta - 0.16) + rng.randf_range(-0.035, 0.045)


func metrics() -> Dictionary:
	return {"submitted": submitted, "injected_errors": injected_errors, "defense_attempts": defense_attempts, "missed_defenses": missed_defenses, "ultimates": ultimate_attempts, "no_target_seconds": no_target_seconds, "defense_pause_seconds": defense_pause_seconds, "recognition_scheduled_seconds": recognition_seconds, "key_wait_seconds": key_wait_seconds, "selections": selections}
