class_name BattleThreatOverlay
extends Control
## Danger geometry is kept out of world bloom, refraction and decorative particles.

var session: BattleSession
var _melee_cues: Dictionary[StringName, ColorRect] = {}
const MELEE_CUE = preload("res://ui/scenes/melee_attack_visual.tscn")


func _process(_delta: float) -> void:
	for enemy in session.enemies:
		if enemy.kind != &"nib":
			continue
		if not _melee_cues.has(enemy.id):
			var created_cue := MELEE_CUE.instantiate() as ColorRect
			add_child(created_cue)
			_melee_cues[enemy.id] = created_cue
		var cue := _melee_cues[enemy.id]
		cue.visible = enemy.alive() and (enemy.aiming or enemy.melee_strike > 0.0)
		if cue.visible:
			cue.position = enemy.melee_origin * size - Vector2.ONE * 128.0
			var surface := cue.material as ShaderMaterial
			surface.set_shader_parameter("reach", BattleEnemy.MELEE_REACH)
			surface.set_shader_parameter("half_angle", BattleEnemy.MELEE_HALF_ANGLE)
			surface.set_shader_parameter("heading", enemy.melee_direction.angle())
			surface.set_shader_parameter("charge", 1.0 - enemy.attack_clock / enemy.warning_time)
			surface.set_shader_parameter("strike", 1.0 - enemy.melee_strike / BattleEnemy.MELEE_STRIKE_TIME if enemy.melee_strike > 0.0 else -1.0)
	for id in _melee_cues.keys():
		if session.enemy_by_id(id) == null:
			_melee_cues[id].queue_free()
			_melee_cues.erase(id)
	queue_redraw()


func _draw() -> void:
	var fraction := Engine.get_physics_interpolation_fraction()
	for enemy in session.enemies:
		if enemy.kind == &"nib" or not enemy.alive() or not enemy.aiming or not BattleSession.enemy_in_combat(enemy):
			continue
		var from := enemy.previous_position.lerp(enemy.position, fraction) * size
		var target := enemy.aimed_position * size
		var urgency := 1.0 - clampf(enemy.attack_clock / enemy.warning_time, 0.0, 1.0)
		var tint := Color("e9a788", 0.15 + urgency * 0.6)
		if enemy.kind == &"nib":
			draw_arc(from, 24 + urgency * 15, 0, TAU, 48, tint, 1.8, true)
		else:
			var angle := (target - from).angle()
			draw_arc(from, enemy.radius + 12, -PI * 0.5, -PI * 0.5 + TAU * urgency, 64, tint, 1.8, true)
			draw_arc(from, enemy.radius + 17, angle - 0.32, angle + 0.32, 20, Color("ffdbb0", urgency), 2.0, true)
	for threat in session.threats:
		var point := threat.previous_position.lerp(threat.position, fraction) * size
		var direction := (threat.velocity * size / BattleSession.ARENA_SIZE).normalized()
		var length := threat.radius * 2.0 + 3.0
		var side := direction.orthogonal() * threat.radius * 0.7
		var shape := PackedVector2Array([point + direction * length * 0.8, point + side, point - direction * length, point - side])
		var tint := Color("c5ffc9") if threat.reflected else Color("eaaa86")
		draw_colored_polygon(shape, tint)
		draw_colored_polygon(PackedVector2Array([shape[0], shape[1], shape[2]]), tint.darkened(0.45))
		var contour := shape.duplicate()
		contour.append(shape[0])
		draw_polyline(contour, Color("251615"), 1.8, true)
		draw_line(shape[0], shape[2], Color("ffe5b6"), 1.6, true)
