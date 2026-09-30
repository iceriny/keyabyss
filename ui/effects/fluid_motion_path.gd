class_name FluidMotionPath
extends RefCounted
## Preserve turns between solver ticks; straight motion costs a single capsule.
## Bounded simplification keeps the most significant bends on busy input frames.

const MAX_SEGMENTS := 8
var points := PackedVector2Array()


func reset(point: Vector2) -> void:
	points = PackedVector2Array([point])


func append(point: Vector2) -> void:
	if points.is_empty():
		reset(point)
		return
	if points[-1].distance_squared_to(point) < 0.01:
		return
	points.append(point)
	if points.size() > 2 and _deviation(points.size() - 2) < 0.5:
		points.remove_at(points.size() - 2)
	if points.size() > MAX_SEGMENTS + 1:
		var least := 1
		for i in range(2, points.size() - 1):
			if _deviation(i) < _deviation(least):
				least = i
		points.remove_at(least)


func length() -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


func _deviation(index: int) -> float:
	return points[index].distance_to(Geometry2D.get_closest_point_to_segment(points[index], points[index - 1], points[index + 1]))


static func sweep(source: FluidInfluence, start: Vector2, end: Vector2, radius: float) -> void:
	var travel := end - start
	source.shape = FluidInfluence.Shape.CAPSULE
	source.center = (start + end) * .5
	source.extent = Vector2(travel.length() * .5 + radius, radius)
	source.rotation = travel.angle()
	source.sweep_length = travel.length()


static func exposure(distance: float, total: float, radius: float) -> float:
	# A long sweep visits each patch briefly; overlapping short segments divide
	# the tick's duration. Input frequency must not multiply the delivered force.
	return minf(distance, radius * 2.0) / total if total > 0.0 else 1.0
