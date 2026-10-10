class_name BattleStatistics
extends RefCounted
## Read-only totals from accepted typing and committed battle actions.

const SUM_FIELDS := ["elapsed", "damage_q", "kills", "manual_characters", "manual_words", "wrong_words", "mistakes", "dodges", "defense_successes", "perfect_defenses", "ultimates"]
var correct_streak: int = 0
var best_correct_streak: int = 0
var max_combo: int = 0
var wrong_words: int = 0
var mistakes: int = 0
var dodges: int = 0
var defense_successes: int = 0
var perfect_defenses: int = 0
var ultimates: int = 0
var kills: int = 0
var damage_q: int = 0
var wrong_word_counts: Dictionary[String, int] = {}
var _mistaken_attempts: Dictionary[String, bool] = {}
var _world: BattleSession
var _segment_id: String


func _init(session: BattleSession) -> void:
	_world = session
	max_combo = _world.runtime._combo
	_segment_id = Crypto.new().generate_random_bytes(12).hex_encode()
	_world.typing.character_judged.connect(_on_character)
	_world.event_committed.connect(_on_event)


func detach() -> void:
	_world.typing.character_judged.disconnect(_on_character)
	_world.event_committed.disconnect(_on_event)


func snapshot() -> Dictionary:
	return {"version": 1, "segment_id": _segment_id, "elapsed": _world.elapsed, "damage_q": damage_q, "kills": kills, "manual_characters": _world.manual_characters, "manual_words": _world.completed_words + _world._pickup_words, "best_correct_streak": best_correct_streak, "max_combo": max_combo, "correct_streak": correct_streak, "wrong_words": wrong_words, "mistakes": mistakes, "wrong_word_counts": wrong_word_counts.duplicate(), "dodges": dodges, "defense_successes": defense_successes, "perfect_defenses": perfect_defenses, "ultimates": ultimates}


func _on_character(attempt_id: String, target_word: String, correct: bool) -> void:
	if correct:
		correct_streak += 1
		best_correct_streak = maxi(best_correct_streak, correct_streak)
		return
	correct_streak = 0
	mistakes += 1
	if target_word.is_empty(): return
	wrong_word_counts[target_word] = wrong_word_counts.get(target_word, 0) + 1
	if not _mistaken_attempts.has(attempt_id):
		_mistaken_attempts[attempt_id] = true
		wrong_words += 1


func _on_event(event: Dictionary) -> void:
	match event.kind:
		&"cast", &"pickup_trigger": max_combo = maxi(max_combo, _world.runtime._combo)
		&"impact": damage_q += int(event.applied_q)
		&"dodge": dodges += 1
		&"ultimate": ultimates += 1
		&"death": kills += 1
		&"counter_pulse":
			defense_successes += 1
			if event.grade == &"perfect": perfect_defenses += 1
