class_name WordCompletion
extends RefCounted

var attempt_id: String
var target_id: StringName
var word: String
var manual_positions: PackedInt32Array = []
var assisted_positions: PackedInt32Array = []
var mistakes: int = 0
var word_version: int = 0


func fully_manual() -> bool:
	return assisted_positions.is_empty() and manual_positions.size() == word.replace(" ", "").length()
