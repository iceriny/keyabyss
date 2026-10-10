class_name VocabularyEntry
extends RefCounted

var word: String = ""
var meaning: String = ""


func _init(value: String = "", explanation: String = "") -> void:
	word = value
	meaning = explanation


func playable_length() -> int:
	return word.length() - word.count(" ")
