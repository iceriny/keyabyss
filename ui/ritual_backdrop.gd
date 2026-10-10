class_name RitualBackdrop
extends Control
## Shared etched framework keeps the loading and welcome in the same space.

@export var welcome := false
var formation := 0.0:
	set(value):
		formation = value
		if is_node_ready(): ink.queue_redraw()
var reduced_motion := false
var clock := 0.0
var _unit := 1.0
var _center := Vector2.ZERO
const GOLD := Color(0.68, 0.54, 0.30)
@onready var ink: Control = $Engraving
@onready var atmosphere: ShaderMaterial = $Atmosphere.material


func _ready() -> void:
	formation = 1.0 if welcome else 0.0
	ink.draw.connect(_draw_engraving)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	atmosphere.set_shader_parameter("canvas_size", size)
	atmosphere.set_shader_parameter("dust_amount", lerpf(0.16, 1.0, formation))
	ink.queue_redraw()


func _process(delta: float) -> void:
	if not reduced_motion:
		clock += delta
	atmosphere.set_shader_parameter("clock", clock)
	atmosphere.set_shader_parameter("dust_amount", lerpf(0.16, 1.0, formation))
	(ink.material as ShaderMaterial).set_shader_parameter("clock", clock)


func _draw_engraving() -> void:
	_unit = size.y / 1080.0
	_center = Vector2(size.x * 0.5, size.y * 0.385)
	ink.draw_set_transform(_center, 0.0, Vector2.ONE * _unit)
	var radius := lerpf(260.0, 282.0, formation)
	for ring: Vector2 in [Vector2(radius, 0.32), Vector2(radius + 9, 0.10), Vector2(radius + 44, 0.11), Vector2(440, 0.075), Vector2(610, 0.025)]:
		_circle(Vector2.ZERO, ring.x, ring.y)
	for i in 160:
		var angle := TAU * float(i) / 160.0
		var point := Vector2.from_angle(angle) * (radius + 44.0)
		if point.y < 245 or absf(point.x) > 180:
			ink.draw_circle(point, 0.7, Color(GOLD, 0.15))
	for side in [-1.0, 1.0]:
		var moon := Vector2(side * (radius + 44.0), 0)
		_crescent(moon, lerpf(12.0, 15.0, formation), side, 0.68)
		_fade_line(Vector2(side * (radius + 68), 0), Vector2(side * 610, 0), 0.42)
		_star(Vector2(side * radius, 0), 11, 0.45)
		for offset in [-32.0, 32.0]:
			_star(moon + Vector2(0, offset), 2.5, 0.55)
		for i in 3:
			_star(moon + Vector2(side * (26 + i * 9), 0), 1.8, 0.55 - i * 0.13)
	if formation < 1.0:
		_star(Vector2(0, -radius), 15, 0.65 * (1.0 - formation))
	_star(Vector2(0, -radius - 62), lerpf(8, 17, formation), lerpf(0.5, 0.7, formation))
	_fade_line(Vector2(0, -radius - 45), Vector2(0, -410), 0.42)
	_star(Vector2(0, radius - lerpf(8, 96, formation)), 13, 0.7)
	if formation > 0.0:
		_star(Vector2(0, 225), 7, 0.7 * formation)
		_crescent(Vector2(0, -radius), 15, 0, 0.72 * formation)
		# Quiet interlaced geometry behind the central seal.
		for turn in 3:
			var points := PackedVector2Array()
			for i in 8:
				points.append(Vector2.from_angle(-PI * 0.5 + float(i * 3) * TAU / 7.0 + turn * 0.19) * (205.0 - turn * 9.0))
			ink.draw_polyline(points, Color(GOLD, (0.055 - turn * 0.014) * formation), 0.9, true)
		_circle(Vector2.ZERO, 212, 0.20 * formation)
		_crescent(Vector2(0, 414), 12, 2, 0.70 * formation)
		_star(Vector2(0, 394), 5, 0.68 * formation)
		_fade_line(Vector2(0, 435), Vector2(0, 466), 0.30 * formation)
	if formation < 1.0:
		# A leaf-shaped inner chamber joins the core to the vertical axis.
		for side in [-1.0, 1.0]:
			var leaf := Curve2D.new()
			leaf.add_point(Vector2(0, -120), Vector2.ZERO, Vector2(0, 56))
			leaf.add_point(Vector2(side * 80, 0), Vector2(0, -75), Vector2(0, 75))
			leaf.add_point(Vector2(0, 120), Vector2(side * 12, -56))
			ink.draw_polyline(leaf.get_baked_points(), Color(GOLD, 0.04 * (1.0 - formation)), 1.0, true)
		for side in [-1.0, 1.0]:
			_fade_line(Vector2(0, side * 75), Vector2(0, side * 195), 0.24 * (1.0 - formation))
	# Text ornaments share the same vertical spine as the rune rings.
	var title_y := lerpf(300.0, 298.0, formation)
	var title_gap := lerpf(79.0, 142.0, formation)
	_rule(title_y, title_gap, lerpf(0.60, 0.78, formation))
	_rule(363, 75, 0.55 * formation)
	_rule(lerpf(400.0, 493.0, formation), 134.0, 0.55)
	if formation > 0.0:
		_star(Vector2(0, 528), 4.5, 0.85 * formation)
		_fade_line(Vector2(0, 535), Vector2(0, 600), 0.42 * formation)
	ink.draw_set_transform(Vector2.ZERO)


func _rule(y: float, gap: float, alpha: float) -> void:
	for side in [-1.0, 1.0]:
		_star(Vector2(side * gap, y), 4.0, alpha)
		_fade_line(Vector2(side * (gap + 4), y), Vector2(side * (gap + 62), y), alpha * 0.8)


func _circle(center: Vector2, radius: float, alpha: float) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var count := maxi(192, ceili(radius * _unit))
	for i in count + 1:
		var point := center + Vector2.from_angle(TAU * float(i) / count) * radius
		# Engravings dissolve where the title and loading copy occupy the axis.
		var text_space := smoothstep(245.0, 290.0, point.y) * (1.0 - smoothstep(85.0, 205.0, absf(point.x)))
		points.append(point)
		colors.append(Color(GOLD, alpha * 0.23 * (1.0 - text_space)))
	ink.draw_polyline_colors(points, colors, 1.0, true)


func _line(a: Vector2, b: Vector2, alpha: float) -> void:
	ink.draw_line(a, b, Color(GOLD, alpha * 0.08), 2.0, true)
	ink.draw_line(a, b, Color(GOLD, alpha * 0.28), 0.8, true)


func _fade_line(a: Vector2, b: Vector2, alpha: float) -> void:
	for i in 24:
		var t := float(i) / 24.0
		_line(a.lerp(b, t), a.lerp(b, t + 1.0 / 24.0), alpha * pow(1.0 - t, 1.5))


func _star(at: Vector2, radius: float, alpha: float) -> void:
	if radius >= 7.0:
		for side in [-1.0, 1.0]:
			_fade_line(at, at + Vector2(0, side * radius * 2.0), alpha * 0.7)
			_fade_line(at, at + Vector2(side * radius * 1.3, 0), alpha * 0.5)
	var points := PackedVector2Array()
	for i in 8:
		var angle := float(i) * TAU / 8.0
		points.append(at + Vector2.from_angle(angle) * radius * (1.0 if i % 2 == 0 else 0.22) * Vector2(0.65, 1.0))
	ink.draw_colored_polygon(points, Color(GOLD.lightened(0.18), alpha))


func _crescent(at: Vector2, radius: float, facing: float, alpha: float) -> void:
	var points := PackedVector2Array()
	var angle := PI if facing < 0 else 0.0
	if facing == 0: angle = PI * 0.5
	if facing == 2: angle = -PI * 0.5
	for i in 33:
		var a := PI * 0.5 + PI * float(i) / 32.0
		points.append(at + (Vector2.from_angle(a) * radius).rotated(angle))
	for i in 33:
		var a := PI * 1.5 - PI * float(i) / 32.0
		points.append(at + (Vector2(cos(a) * radius * 0.82 + radius * 0.18, sin(a) * radius)).rotated(angle))
	ink.draw_colored_polygon(points, Color(GOLD.lightened(0.10), alpha))
