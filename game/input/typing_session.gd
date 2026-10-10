class_name TypingSession
extends RefCounted

signal changed
signal completed(target_id: StringName, manual_count: int, assisted: bool, attempt_id: String)
signal abandoned(attempt_id: String)
signal word_completed(fact: WordCompletion)
signal character_judged(attempt_id: String, target_word: String, correct: bool)

static var _serial: int = 0
var target_id: StringName = &""
var word: String = ""
var progress: int = 0
var mistakes: int = 0
var last_feedback: String = ""
var _targets: Dictionary[StringName, String] = {}
var _pending: Array[ManualInputReceipt] = []
var _sequence: int = 0
var _attempt_serial: int = 0
var _session_id: String
var _attempt_mistakes: int = 0
var _versions: Dictionary[StringName, int] = {}
var assisted_authorizer: Callable


func _init() -> void:
	_serial += 1
	_session_id = "%s:%s:%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), _serial]


func set_targets(targets: Dictionary[StringName, String]) -> void:
	if progress > 0:
		abandoned.emit(current_attempt_id())
	_attempt_serial += 1
	_targets = targets.duplicate()
	_versions.clear()
	_attempt_mistakes = 0
	target_id = &""
	word = ""
	progress = 0
	last_feedback = ""
	changed.emit()


func upsert_target(id: StringName, next_word: String) -> void:
	if not _targets.has(id) or _targets[id] != next_word:
		_versions[id] = _versions.get(id, 0) + 1
	_targets[id] = next_word
	if target_id == id and progress == 0:
		word = next_word
	changed.emit()


func retire_target(id: StringName) -> void:
	if not _targets.has(id) and target_id != id: return
	if target_id == id and progress > 0:
		_targets.erase(id)
		return
	_targets.erase(id)
	if target_id == id:
		cancel()
	else:
		changed.emit()


func select_target(id: StringName) -> void:
	if not _targets.has(id):
		return
	if progress > 0:
		abandoned.emit(current_attempt_id())
	_attempt_serial += 1
	target_id = id
	word = _targets[id]
	progress = 0
	_attempt_mistakes = 0
	last_feedback = "输入词咒"
	changed.emit()


func cycle_target(reverse: bool = false) -> void:
	var prefix := word.replace(" ", "").left(progress)
	var ids: Array[StringName] = []
	for id: StringName in _targets:
		if _targets[id].replace(" ", "").begins_with(prefix):
			ids.append(id)
	if ids.is_empty():
		return
	var current := ids.find(target_id)
	var next := (ids.size() - 1 if reverse else 0) if current < 0 else posmod(current + (-1 if reverse else 1), ids.size())
	target_id = ids[next]
	word = _targets[target_id]
	if progress == 0:
		last_feedback = "输入词咒"
	changed.emit()


func cancel() -> void:
	if progress > 0:
		abandoned.emit(current_attempt_id())
	_attempt_serial += 1
	target_id = &""
	word = ""
	progress = 0
	_attempt_mistakes = 0
	last_feedback = "已放弃当前词咒" if not _targets.is_empty() else ""
	changed.emit()


func feed(character: String) -> void:
	if character.length() != 1 or character == " ":
		return
	character = character.to_lower()
	if target_id == &"":
		for id: StringName in _targets:
			if _targets[id].begins_with(character):
				select_target(id)
				break
	if target_id == &"":
		last_feedback = "没有以此字符开头的词咒"
		character_judged.emit(current_attempt_id(), "", false)
		changed.emit()
		return
	var playable := word.replace(" ", "")
	if progress >= playable.length():
		return
	if character != playable[progress]:
		var prefix := playable.left(progress) + character
		for id: StringName in _targets if _targets.has(target_id) else {}:
			if _targets[id].replace(" ", "").begins_with(prefix):
				target_id = id
				word = _targets[id]
				playable = word.replace(" ", "")
				changed.emit()
				break
		if character != playable[progress]:
			mistakes += 1
			_attempt_mistakes += 1
			character_judged.emit(current_attempt_id(), word, false)
			last_feedback = "错字 · 进度保留"
			changed.emit()
			return
	progress += 1
	_sequence += 1
	var receipt := ManualInputReceipt.new()
	receipt.id = "%s:%s" % [_session_id, _sequence]
	receipt.attempt_id = current_attempt_id()
	receipt.target_id = target_id
	receipt.word = word
	receipt.character = character
	receipt.position = progress
	receipt.completes_word = progress == playable.length()
	receipt.word_version = target_version(target_id)
	_pending.append(receipt)
	character_judged.emit(receipt.attempt_id, word, true)
	last_feedback = "落笔 %s / %s" % [progress, playable.length()]
	changed.emit()
	if receipt.completes_word:
		_finish(false)


func complete_assisted() -> void:
	if target_id == &"" or progress <= 0 or progress >= word.replace(" ", "").length():
		return
	if not assisted_authorizer.is_valid() or not assisted_authorizer.call():
		last_feedback = "补全尚未准备好 · 可以继续输入"
		changed.emit()
		return
	_finish(true)


func _finish(assisted: bool) -> void:
	var finished_id := target_id
	var manual_count := progress
	var attempt_id := current_attempt_id()
	var fact := WordCompletion.new()
	fact.attempt_id = attempt_id
	fact.target_id = target_id
	fact.word = word
	fact.mistakes = _attempt_mistakes
	fact.word_version = _versions.get(target_id, 0)
	for index in word.replace(" ", "").length():
		if index < progress:
			fact.manual_positions.append(index + 1)
		else:
			fact.assisted_positions.append(index + 1)
	_targets.erase(finished_id)
	_attempt_serial += 1
	target_id = &""
	word = ""
	progress = 0
	_attempt_mistakes = 0
	last_feedback = "词咒完成"
	completed.emit(finished_id, manual_count, assisted, attempt_id)
	word_completed.emit(fact)
	changed.emit()


func drain_receipts() -> Array[ManualInputReceipt]:
	var receipts := _pending
	_pending = []
	return receipts


func current_attempt_id() -> String:
	return "%s:attempt:%d" % [_session_id, _attempt_serial]


func target_version(id: StringName) -> int:
	return _versions.get(id, 0)


func display_boundary() -> int:
	var accepted := 0
	for index in word.length():
		if word[index] != " ":
			accepted += 1
		if accepted > progress:
			return index
	return word.length()
