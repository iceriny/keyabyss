class_name BattleStartRequest
extends RefCounted

var build: CompiledBuild
var vocabulary: Array[VocabularyEntry] = []
var vocabulary_index: VocabularyIndex
var maximum_length: int = 24
var encounter: BattleEncounter = preload("res://game/content/single_room.tres")
var difficulty: String = "normal"
var seed_text: String
var progressive: bool = true
var minimum_length: int = 1
var run_id: String
var room_serial: int = 0
var attempt_id: String
var chapter: int = 1
var loop_index: int = 0
var god_mode: bool = false
