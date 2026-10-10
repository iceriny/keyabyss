class_name BattleHazard
extends RefCounted
## Committed warning geometry and finite active contact, owned by BattleSession.

var kind: StringName
var source_id: StringName
var attack_id: String
var origin := Vector2.ZERO
var end := Vector2.ZERO
var center := Vector2.ZERO
var radius: float = 0.0
var width: float = 0.0
var warning_remaining: float = 1.2
var warning_total: float = 1.2
var active_remaining: float = 0.48
var damage_q: int
var fired: bool = false
var ring: bool = false


func contains(at: Vector2) -> bool:
	return clearance(at) <= 0.0


func intersects_motion(from: Vector2, to: Vector2) -> bool:
	# AOE timing uses the same footprint as damage, including player recoil.
	var start := from * BattleSession.ARENA_SIZE
	var finish := to * BattleSession.ARENA_SIZE
	if kind == &"blast":
		return Geometry2D.get_closest_point_to_segment(center * BattleSession.ARENA_SIZE, start, finish).distance_to(center * BattleSession.ARENA_SIZE) <= radius + 21.0
	var line_start := origin * BattleSession.ARENA_SIZE
	var line_end := end * BattleSession.ARENA_SIZE
	if Geometry2D.segment_intersects_segment(start, finish, line_start, line_end) != null:
		return true
	return contains(from) or contains(to) or minf(
		Geometry2D.get_closest_point_to_segment(line_start, start, finish).distance_to(line_start),
		Geometry2D.get_closest_point_to_segment(line_end, start, finish).distance_to(line_end)) <= width + 21.0


func clearance(at: Vector2) -> float:
	if kind == &"blast":
		return ((at - center) * BattleSession.ARENA_SIZE).length() - radius - 21.0
	var point := at * BattleSession.ARENA_SIZE
	var nearest := Geometry2D.get_closest_point_to_segment(point, origin * BattleSession.ARENA_SIZE, end * BattleSession.ARENA_SIZE)
	return point.distance_to(nearest) - width - 21.0
