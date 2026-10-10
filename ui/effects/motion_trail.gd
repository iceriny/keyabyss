class_name MotionTrail
extends RefCounted
## Builds a display-only tail from committed physics samples and one render head.

const MIN_SEGMENT := 0.01


static func build(samples: PackedVector2Array, physics_head: Vector2, render_head: Vector2, max_length: float, smooth: bool, max_points: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in samples:
		if points.is_empty() or points[-1].distance_to(point) > MIN_SEGMENT:
			points.append(point)
	if not points.is_empty() and points[-1].distance_to(physics_head) <= MIN_SEGMENT:
		points.remove_at(points.size() - 1)
	if points.is_empty() or points[-1].distance_to(render_head) > MIN_SEGMENT:
		points.append(render_head)
	else:
		points[points.size() - 1] = render_head
	points = _trim_from_head(points, max_length)
	if smooth and points.size() > 2:
		return _trim_from_head(_centripetal(points, max_points), max_length)
	return points


static func _trim_from_head(points: PackedVector2Array, max_length: float) -> PackedVector2Array:
	var backwards := PackedVector2Array([points[-1]])
	var remaining := max_length
	for index in range(points.size() - 2, -1, -1):
		var segment := points[index + 1].distance_to(points[index])
		if segment <= MIN_SEGMENT:
			continue
		if segment > remaining:
			backwards.append(points[index + 1].lerp(points[index], remaining / segment))
			break
		backwards.append(points[index])
		remaining -= segment
		if remaining <= MIN_SEGMENT:
			break
	var result := PackedVector2Array()
	for index in range(backwards.size() - 1, -1, -1):
		result.append(backwards[index])
	return result


static func _centripetal(points: PackedVector2Array, max_points: int) -> PackedVector2Array:
	var subdivisions := mini(3, maxi(1, floori(float(max_points - 1) / float(points.size() - 1))))
	var result := PackedVector2Array()
	for index in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		var before := points[index - 1] if index > 0 else a + (a - b)
		var after := points[index + 2] if index + 2 < points.size() else b + (b - a)
		for sample in subdivisions:
			result.append(_sample(before, a, b, after, float(sample) / subdivisions))
	result.append(points[-1])
	return result


static func _sample(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, fraction: float) -> Vector2:
	var t0 := 0.0
	var t1 := t0 + sqrt(p0.distance_to(p1))
	var t2 := t1 + sqrt(p1.distance_to(p2))
	var t3 := t2 + sqrt(p2.distance_to(p3))
	var t := lerpf(t1, t2, fraction)
	var a1 := p0.lerp(p1, (t - t0) / (t1 - t0))
	var a2 := p1.lerp(p2, (t - t1) / (t2 - t1))
	var a3 := p2.lerp(p3, (t - t2) / (t3 - t2))
	var b1 := a1.lerp(a2, (t - t0) / (t2 - t0))
	var b2 := a2.lerp(a3, (t - t1) / (t3 - t1))
	return b1.lerp(b2, (t - t1) / (t2 - t1))
