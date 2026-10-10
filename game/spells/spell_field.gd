class_name SpellField
extends RefCounted

var id: int
var effect: BattleEffect
var center: Vector2
var endpoint: Vector2
var radius: float
var remaining_pulses: int
var pulse_q: int
var interval: float
var next_at: float
var expires_at: float
var relayed: bool = false


func contains(position: Vector2) -> bool:
	var start := center * BattleSession.ARENA_SIZE
	var end := endpoint * BattleSession.ARENA_SIZE
	var point := position * BattleSession.ARENA_SIZE
	var nearest := Geometry2D.get_closest_point_to_segment(point, start, end) if start != end else start
	return point.distance_squared_to(nearest) <= radius * radius
