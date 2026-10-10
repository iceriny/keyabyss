class_name BattleThreatOverlay
extends Control
## Danger geometry is kept out of world bloom, refraction and decorative particles.

var session: BattleSession
var _melee_cues: Dictionary[StringName, ColorRect] = {}
var _orb: GradientTexture2D
const MELEE_CUE = preload("res://ui/scenes/melee_attack_visual.tscn")


func _ready() -> void:
	_orb = preload("res://ui/effects/threat_orb.tres")


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
	var scale_factor := size.x / BattleSession.ARENA_SIZE.x
	for hazard in session.hazards:
		var active: bool = hazard.warning_remaining <= 0.0
		var progress: float = 1.0 - clampf(hazard.warning_remaining / hazard.warning_total, 0.0, 1.0)
		var color := Color("ffd2a0") if active else Color("ed937e")
		if hazard.kind == &"blast":
			var center: Vector2 = hazard.center * size
			var radius: float = hazard.radius * scale_factor
			draw_circle(center, radius, Color(color, 0.16 if active else 0.045))
			draw_arc(center, radius, 0, TAU, 80, Color(color, 0.95), 2.5 if active else 1.5, true)
			if not active:
				draw_arc(center, radius * progress, 0, TAU, 64, Color(color, 0.6), 1.1, true)
			for index in 4:
				var direction := Vector2.from_angle(index * PI * 0.5)
				draw_line(center + direction * (radius - 7), center + direction * (radius + 7), color, 1.6, true)
		else:
			var start: Vector2 = hazard.origin * size
			var finish: Vector2 = hazard.end * size
			var side := (finish - start).normalized().orthogonal() * hazard.width * scale_factor
			draw_colored_polygon(PackedVector2Array([start + side, finish + side, finish - side, start - side]), Color(color, 0.25 if active else 0.055))
			draw_line(start + side, finish + side, Color(color, 0.85), 1.6, true)
			draw_line(start - side, finish - side, Color(color, 0.85), 1.6, true)
			if active:
				draw_line(start, finish, Color("ffe5c0"), 3.0, true)
			else:
				draw_dashed_line(start, finish, Color(color, 0.35 + progress * 0.4), 1.2, 12.0 * scale_factor, true)
	for enemy in session.enemies:
		if enemy.kind == &"nib" or not enemy.alive() or not enemy.aiming or not BattleSession.enemy_in_combat(enemy):
			continue
		var from := enemy.previous_position.lerp(enemy.position, fraction) * size
		var target := enemy.aimed_position * size
		var urgency := 1.0 - clampf(enemy.attack_clock / enemy.warning_time, 0.0, 1.0)
		var tint := Color("e9a788", 0.15 + urgency * 0.6)
		if enemy.behavior == &"charge":
			var side := (target - from).normalized().orthogonal() * enemy.radius * scale_factor
			draw_line(from + side, target + side, tint, 1.5, true)
			draw_line(from - side, target - side, tint, 1.5, true)
			draw_dashed_line(from, target, tint, 1.2, 10.0, true)
		if enemy.kind == &"nib":
			draw_arc(from, 24 + urgency * 15, 0, TAU, 48, tint, 1.8, true)
		else:
			var angle := (target - from).angle()
			draw_arc(from, enemy.radius + 12, -PI * 0.5, -PI * 0.5 + TAU * urgency, 64, tint, 1.8, true)
			draw_arc(from, enemy.radius + 17, angle - 0.32, angle + 0.32, 20, Color("ffdbb0", urgency), 2.0, true)
	for threat in session.threats:
		var point := threat.previous_position.lerp(threat.position, fraction) * size
		var tint := Color("adf1ce") if threat.reflected else Color("efb28d")
		var radius := threat.radius * scale_factor
		var samples := PackedVector2Array()
		for sample in threat.trail: samples.append(sample * size)
		var tail := MotionTrail.build(samples, threat.position * size, point, 64.0 * scale_factor, false, 12)
		for index in range(1, tail.size()):
			var strength := float(index) / tail.size()
			draw_line(tail[index - 1], tail[index], Color(tint, strength * 0.1), radius * 2.2 * strength, true)
			draw_line(tail[index - 1], tail[index], Color(tint, strength * 0.5), maxf(1.0, radius * 0.5 * strength), true)
		draw_texture_rect(_orb, Rect2(point - Vector2.ONE * radius * 3.5, Vector2.ONE * radius * 7.0), false, Color(tint, 0.6))
		draw_texture_rect(_orb, Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color("fff0d7"))
