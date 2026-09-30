class_name BattleThreat
extends RefCounted

var source_id: StringName
var position := Vector2.ZERO
var previous_position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage_q: int
var radius: float = 5.0
var life: float = 6.0
var reflected: bool = false
var trail: PackedVector2Array = []
var attack_id: String
var effect: BattleEffect
var grazed: bool = false
