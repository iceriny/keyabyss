class_name JourneyEmblem
extends Control
## Open ink-and-gold illustrations for the archive and room interludes.

var kind: StringName = &"rest"
var tint := Color("ccb887")
var progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _curve(points: Array[Vector2], color: Color, width: float = 1.5) -> void:
	var curve := Curve2D.new()
	for index in points.size():
		var tangent := (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]) * 0.17
		curve.add_point(points[index], -tangent, tangent)
	draw_polyline(curve.get_baked_points(), color, width, true)


func _draw() -> void:
	var unit := minf(size.x, size.y) / 180.0
	draw_set_transform(size * 0.5, 0, Vector2.ONE * unit)
	for index in range(18, 0, -1):
		draw_circle(Vector2.ZERO, index * 4.0, Color(tint, 0.0025))
	var faint := Color(tint, 0.24)
	draw_arc(Vector2.ZERO, 66, -2.7, -0.35, 64, faint, 0.8, true)
	draw_arc(Vector2.ZERO, 66, 0.45, 2.5, 64, faint, 0.8, true)
	if kind == &"rest":
		_curve([Vector2(-40, 43), Vector2(-15, 7), Vector2(10, -24), Vector2(44, -48)], tint, 1.7)
		for index in 5:
			var anchor := Vector2(-27 + index * 13, 25 - index * 17)
			var tip := anchor + Vector2(-29 + index * 2, -22)
			_curve([anchor, anchor + Vector2(-24, -2), tip, anchor + Vector2(-4, -13), anchor], Color(tint, 0.7), 1.0)
			_curve([anchor, anchor + Vector2(20, 2), anchor + Vector2(30, -17), anchor + Vector2(8, -12)], Color(tint, 0.5), 1.0)
		draw_arc(Vector2(22, 29), 17, -0.1, PI * 1.5, 48, Color("9dc7b6"), 1.4, true)
	elif kind == &"offering":
		_curve([Vector2(-37, 0), Vector2(-26, 24), Vector2(0, 36), Vector2(26, 24), Vector2(37, 0)], tint, 1.8)
		_curve([Vector2(-39, 0), Vector2(0, 9), Vector2(39, 0)], Color(tint, 0.6), 1.0)
		_curve([Vector2(0, 36), Vector2(0, 48), Vector2(-25, 56)], tint)
		_curve([Vector2(0, 36), Vector2(0, 48), Vector2(25, 56)], tint)
		_curve([Vector2(0, -55), Vector2(-12, -29), Vector2(0, -16), Vector2(12, -29), Vector2(0, -55)], Color("d79386"), 1.7)
		draw_circle(Vector2(0, -28), 3, Color("e4b0a0", 0.4))
	else:
		_curve([Vector2(-55, 43), Vector2(-24, 12), Vector2(17, -9), Vector2(49, -49)], tint, 1.8)
		for index in 5:
			var at := Vector2(-43 + index * 22, 30 - index * 18)
			var lit := progress >= (index + 1) / 5.0
			var color := tint if lit else Color(tint, 0.23)
			var leaf := PackedVector2Array([at + Vector2(0, -8), at + Vector2(5, 0), at + Vector2(0, 8), at + Vector2(-5, 0), at + Vector2(0, -8)])
			draw_polyline(leaf, color, 1.2, true)
			if lit: draw_circle(at, 2, color)
	draw_set_transform(Vector2.ZERO)
