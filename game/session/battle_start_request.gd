class_name BattleStartRequest
extends RefCounted

var build: CompiledBuild
var vocabulary: Array[VocabularyEntry] = []
var encounter: BattleEncounter = preload("res://game/content/single_room.tres")
var difficulty: String = "normal"
var seed_text: String
var progressive: bool = true
var minimum_length: int = 1
