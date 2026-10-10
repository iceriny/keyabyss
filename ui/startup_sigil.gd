class_name StartupSigil
extends Control
## Gate geometry with shared Arcana384 rune masks.

enum GeometryLayer { COMPLETE, CONNECTIONS, INSCRIPTIONS, GLYPHS, BACKGROUND }
@export var geometry_layer: GeometryLayer = GeometryLayer.COMPLETE

@export var tint: Color = Color("d3bb82"):
	set(value):
		tint = value
		queue_redraw()

@export_range(0.0, 1.0) var progress: float = 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		queue_redraw()

var clock: float = 0.0:
	set(value):
		clock = value
		if not reduced_motion:
			queue_redraw()

var _ink_scale := 1.0

@export_range(0.0, 120.0, 0.1, "or_greater") var core_reverse_period: float = 0.0:
	set(value):
		core_reverse_period = value
		queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	var unit := minf(size.x, size.y) / 100.0
	if unit <= 0.0:
		return
	var center := size * 0.5
	_ink_scale = 1.0
	if geometry_layer not in [GeometryLayer.CONNECTIONS, GeometryLayer.GLYPHS]:
		for entry: Array in [[46.0, 0.3], [44.0, 0.6], [37.0, 0.3], [35.0, 0.6]]:
			_circle(center, float(entry[0]) * unit, float(entry[1]), 0.28 * unit)
		if progress > 0.0:
			draw_arc(center, 46.0 * unit, -PI * 0.5, -PI * 0.5 + TAU * progress, _arc_points(46.0 * unit, TAU * progress), tint, 0.28 * unit, true)
	if geometry_layer not in [GeometryLayer.CONNECTIONS, GeometryLayer.BACKGROUND]:
		var orbit_angle := 0.0 if reduced_motion else clock * TAU / 120.0
		var glyph_count := 28 if geometry_layer == GeometryLayer.GLYPHS else 36
		for i in glyph_count:
			var angle := float(i) * TAU / float(glyph_count) + orbit_angle
			var glyph_center := center + Vector2(0.0, -40.5 * unit).rotated(angle)
			var glyph_scale := unit * (0.64 if geometry_layer == GeometryLayer.GLYPHS else 0.46)
			draw_set_transform(glyph_center, angle, Vector2.ONE * glyph_scale)
			_ink_scale = glyph_scale
			var glyph_alpha := 1.0
			if geometry_layer == GeometryLayer.GLYPHS:
				glyph_alpha -= smoothstep(0.65, 1.0, -cos(angle)) * 0.88
			_draw_rune(i % (12 if geometry_layer == GeometryLayer.COMPLETE else ArcanaRunes.ROOTS.length()), glyph_alpha)
	draw_set_transform(Vector2.ZERO)
	if geometry_layer == GeometryLayer.GLYPHS:
		return
	var core_angle := 0.0
	if not reduced_motion and core_reverse_period > 0.0:
		core_angle = -clock * TAU / core_reverse_period
	draw_set_transform(center, core_angle, Vector2.ONE * unit)
	_ink_scale = unit
	if geometry_layer != GeometryLayer.INSCRIPTIONS:
		_draw_star(Vector2.ZERO, 34.0, 7, 3, 0.58)
		_draw_star(Vector2.ZERO, 31.0, 7, 2, 0.26)
		_circle(Vector2.ZERO, 24.0, 0.55, 0.28)
	for index in 3:
		var angle := float(index) * TAU / 3.0
		var satellite := Vector2(0.0, -23.0).rotated(angle)
		if geometry_layer != GeometryLayer.CONNECTIONS:
			_circle(satellite, 9.0, 1.0, 0.28)
			_circle(satellite, 7.5, 0.5, 0.28)
			_draw_star(satellite, 6.5, 5, 2, 1.0)
			_circle(satellite, 2.0, 1.0, 0.28)
		if geometry_layer != GeometryLayer.INSCRIPTIONS:
			var top := Vector2(0.0, -49.0).rotated(angle)
			_line(top, Vector2(0.0, -38.0).rotated(angle))
			_line(Vector2(-3.0, -43.0).rotated(angle), Vector2(3.0, -43.0).rotated(angle))
			_line(Vector2(0.0, -38.0).rotated(angle), Vector2(-2.0, -40.0).rotated(angle))
			_line(Vector2(0.0, -38.0).rotated(angle), Vector2(2.0, -40.0).rotated(angle))
	if geometry_layer != GeometryLayer.CONNECTIONS:
		_circle(Vector2.ZERO, 9.0, 1.0, 0.28)
		_circle(Vector2.ZERO, 7.0, 0.5, 0.28)
		_draw_star(Vector2.ZERO, 5.5, 6, 1, 0.8)
		draw_circle(Vector2.ZERO, 1.4, tint)
	draw_set_transform(Vector2.ZERO)


func _circle(center: Vector2, radius: float, alpha: float, width: float) -> void:
	draw_arc(center, radius, 0.0, TAU, _arc_points(radius), Color(tint, tint.a * alpha), width, true)


func _arc_points(radius: float, angle: float = TAU) -> int:
	# Bound chord error in output pixels, including the local rune/core transform.
	var canvas_scale := get_global_transform_with_canvas().get_scale().abs()
	var pixels := radius * _ink_scale * maxf(canvas_scale.x, canvas_scale.y)
	var step := 2.0 * acos(clampf(1.0 - 0.15 / maxf(pixels, 0.15), -1.0, 1.0))
	return maxi(8, ceili(angle / step) + 1)


func _line(start: Vector2, end: Vector2, alpha: float = 1.0, width: float = 0.28) -> void:
	draw_line(start, end, Color(tint, tint.a * alpha), width, true)


func _path(points: PackedVector2Array, closed: bool = false) -> void:
	if closed:
		points.append(points[0])
	draw_polyline(points, tint, 0.65, true)


func _draw_star(center: Vector2, radius: float, count: int, step: int, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in count:
		var angle := -PI * 0.5 + float((i * step) % count) * TAU / float(count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	points.append(points[0])
	draw_polyline(points, Color(tint, tint.a * alpha), 0.28, true)


func _draw_rune(index: int, alpha: float = 1.0) -> void:
	ArcanaRunes.draw(self, ArcanaRunes.ROOTS[index], Vector2.ZERO, 15.0, Color(tint, tint.a * alpha))
