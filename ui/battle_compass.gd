class_name BattleCompass
extends Control
## Arrival cues stay around the player and never compete with target words.

var session: BattleSession
var reduced_motion := false
@onready var caption: Label = $Direction


func _process(_delta: float) -> void:
	caption.text = "%s · 来袭" % session.arrival_direction
	queue_redraw()


func _draw() -> void:
	if session == null:
		return
	var direction_index := BattleEncounter.DIRECTIONS.find(session.arrival_direction)
	var breathe := 0.85 if reduced_motion else 0.8 + sin(session.elapsed * 2.2) * 0.12
	for index in 8:
		var angle := index * PI / 4.0 - PI / 2.0
		var active := index == direction_index
		draw_arc(Vector2.ZERO, 67.0, angle - 0.1, angle + 0.1, 12, Color("eed39d", breathe * 0.58) if active else Color("a6babd", 0.14), 1.4 if active else 0.7, true)
		if active:
			_arrow(angle, 79.0, Color("f0d6a1", breathe))
	for enemy in session.enemies:
		if enemy.ambush and enemy.alive() and enemy.age < 3.0:
			var angle := BattleEncounter.DIRECTIONS.find(enemy.approach_direction) * PI / 4.0 - PI / 2.0
			_arrow(angle, 92.0, Color("efa18b", minf(1.0, (3.0 - enemy.age) * 1.2)))


func _arrow(angle: float, radius: float, tint: Color) -> void:
	var axis := Vector2.from_angle(angle)
	var side := axis.orthogonal()
	var at := axis * radius
	var points := PackedVector2Array([at - axis * 7.0, at + axis * 4.0 - side * 4.0, at + axis, at + axis * 4.0 + side * 4.0])
	draw_polyline(PackedVector2Array([points[1], points[0], points[3]]), Color(tint, tint.a * 0.1), 5.0, true)
	draw_colored_polygon(points, tint)
