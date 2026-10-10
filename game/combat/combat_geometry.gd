class_name CombatGeometry
extends RefCounted
## Circle sweeps in design pixels. Returns the first contact fraction, or INF.


static func sweep_discs(a_from: Vector2, a_to: Vector2, b_from: Vector2, b_to: Vector2, radius: float) -> float:
	var offset := a_from - b_from
	var c := offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var travel := (a_to - a_from) - (b_to - b_from)
	var a := travel.length_squared()
	var b := offset.dot(travel)
	if a <= 0.000001 or b >= 0.0:
		return INF
	var discriminant := b * b - a * c
	if discriminant < 0.0:
		return INF
	# Equivalent to (-b - sqrt(discriminant)) / a, without near-root cancellation.
	var entry := c / (-b + sqrt(discriminant))
	return entry if entry <= 1.0 else INF


static func contact_point(a: Vector2, b: Vector2, radius_a: float, direction: Vector2) -> Vector2:
	var normal := (a - b).normalized()
	if normal.is_zero_approx():
		normal = -direction.normalized()
	return a - normal * radius_a


static func disc_in_sector(offset: Vector2, radius: float, axis: Vector2, reach: float, half_angle: float) -> bool:
	# Distance to the filled sector, including its two radial edges and apex.
	if offset.length_squared() <= radius * radius:
		return true
	if offset.normalized().dot(axis) >= cos(half_angle):
		return offset.length() <= reach + radius
	for side in [-1.0, 1.0]:
		var edge := axis.rotated(half_angle * side)
		var nearest := edge * clampf(offset.dot(edge), 0.0, reach)
		if offset.distance_squared_to(nearest) <= radius * radius:
			return true
	return false
