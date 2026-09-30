class_name MotionCurve
extends RefCounted
## CSS cubic-bezier evaluated in time, rather than treating time as curve t.

static func cubic(value: float, p1: Vector2 = Vector2(.2, .7), p2: Vector2 = Vector2(.2, 1)) -> float:
	var x := clampf(value, 0.0, 1.0)
	var low := 0.0
	var high := 1.0
	var t := x
	for _i in 12:
		var sampled := 3.0 * (1.0 - t) * (1.0 - t) * t * p1.x + 3.0 * (1.0 - t) * t * t * p2.x + t * t * t
		if sampled < x:
			low = t
		else:
			high = t
		t = (low + high) * .5
	return 3.0 * (1.0 - t) * (1.0 - t) * t * p1.y + 3.0 * (1.0 - t) * t * t * p2.y + t * t * t
