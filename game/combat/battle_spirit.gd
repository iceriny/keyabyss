class_name BattleSpirit
extends RefCounted
## A persistent summoned body. BattleSession owns flight, funding and contact.

var slot: int = 0
var position := Vector2.ZERO
var previous_position := Vector2.ZERO
var velocity := Vector2.ZERO
var mode: StringName = &"orbit"
var target_id: StringName
var cooldown: float = 0.0
var damage_q: int = 0
var effect: BattleEffect
var cargo: StoredSpell
var crossing: bool = false
var struck: bool = false
var trail: PackedVector2Array = []
var start := Vector2.ZERO
var control := Vector2.ZERO
var bend := Vector2.ZERO
var endpoint := Vector2.ZERO
var flight_time: float = 0.0
var duration: float = 1.0


func begin(next_mode: StringName, destination: Vector2) -> void:
	mode = next_mode
	start = position
	endpoint = destination
	flight_time = 0.0
	var offset := (destination - position) * BattleSession.ARENA_SIZE
	var distance := offset.length()
	var speed := 705.0 if mode == &"dive" else 540.0
	duration = clampf(distance / speed, 0.48 if mode == &"dive" else 0.62, 1.3 if mode == &"dive" else 1.5)
	if mode == &"cross":
		duration = clampf(distance / 2175.0, 0.18, 0.4)
	var departure := minf(maxf(18.0, distance * 0.8), velocity.length() * duration / 3.0)
	control = start + velocity.normalized() * departure / BattleSession.ARENA_SIZE
	var bank := minf(distance, 360.0) * (0.62 if mode == &"dive" else 0.72)
	if mode == &"cross":
		control = start + (endpoint - start) / 3.0
		bank = distance * 0.08
	bend = offset.normalized().orthogonal() * (1.0 if slot % 2 == 0 else -1.0) * bank / BattleSession.ARENA_SIZE


func sample(progress: float) -> Vector2:
	var arrival := endpoint - (endpoint - control) * 0.22 + bend
	return start.bezier_interpolate(control, arrival, endpoint, progress)
