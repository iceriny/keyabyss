class_name BattlePickup
extends RefCounted
## A word target with a finite lifetime; never participates in enemy collision.

var id: StringName
var kind: StringName = &"rune"
var word: String
var position := Vector2.ZERO
var previous_position: Vector2:
	get: return position
var radius: float = 19.5
var age: float = 0.0
var life: float = 14.0
var source_id: StringName
var consumed: bool = false


func alive() -> bool:
	return not consumed and age < life
