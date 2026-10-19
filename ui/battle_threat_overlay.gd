class_name BattleThreatOverlay
extends Control
## Danger geometry is kept out of world bloom, refraction and decorative particles.

var session: BattleSession
var quality: int = 2
var reduced_motion: bool = false
var _melee_cues: Dictionary[StringName, ColorRect] = {}
var _orb: GradientTexture2D
var _head_layer := Node2D.new()
var low_ribbons := MeshInstance2D.new()
var _heads: Dictionary[BattleThreat, ThreatHead] = {}
const MELEE_CUE = preload("res://ui/scenes/melee_attack_visual.tscn")


func _ready() -> void:
	_orb = preload("res://ui/effects/threat_orb.tres")
	# All danger heads stay in front of crossing tails, on the crisp canvas.
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://ui/materials/battle_ribbon.gdshader")
	surface.set_shader_parameter("physical_width", true)
	low_ribbons.material = surface
	low_ribbons.modulate.a = 0.65
	add_child(low_ribbons)
	move_child(low_ribbons, 0)
	add_child(_head_layer)
	move_child(_head_layer, 1)


func _process(_delta: float) -> void:
	for enemy in session.enemies:
		if enemy.behavior != &"melee":
			continue
		if not _melee_cues.has(enemy.id):
			var created_cue := MELEE_CUE.instantiate() as ColorRect
			add_child(created_cue)
			_melee_cues[enemy.id] = created_cue
		var cue := _melee_cues[enemy.id]
		cue.visible = enemy.alive() and BattleSession.enemy_in_combat(enemy) and (enemy.aiming or enemy.melee_strike > 0.0)
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
	_sync_heads()
	queue_redraw()


func _sync_heads() -> void:
	var live: Dictionary[BattleThreat, bool] = {}
	var fraction := Engine.get_physics_interpolation_fraction()
	var scale_factor := size.x / BattleSession.ARENA_SIZE.x
	for threat in session.threats:
		live[threat] = true
		if not _heads.has(threat):
			var head := ThreatHead.new()
			head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			head.painter = self
			head.threat = threat
			_head_layer.add_child(head)
			_heads[threat] = head
		_heads[threat].sync(size, fraction, scale_factor)
	for threat in _heads.keys():
		if not live.has(threat):
			_heads[threat].queue_free()
			_heads.erase(threat)


func _draw() -> void:
	var started := DebugLog.begin()
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
		if enemy.behavior in [&"melee", &"ward"] or not enemy.alive() or not BattleSession.enemy_in_combat(enemy):
			continue
		var from := enemy.previous_position.lerp(enemy.position, fraction) * size
		if enemy.behavior == &"refrain" and (enemy.aiming or enemy.followup_time > 0.0):
			for beat in 2:
				var pending := enemy.aiming or beat == 1
				var mark := from + Vector2((float(beat) - 0.5) * 15.0, enemy.radius + 14.0) * scale_factor
				draw_circle(mark, 3.2 * scale_factor, Color("f0d6ad", 0.9 if pending else 0.12))
				if pending: draw_arc(mark, 5.2 * scale_factor, 0.0, TAU, 16, Color("cbab88", 0.6), scale_factor, true)
		if not enemy.aiming: continue
		var target := enemy.aimed_position * size
		var urgency := 1.0 - clampf(enemy.attack_clock / enemy.warning_time, 0.0, 1.0)
		var tint := Color("e9a788", 0.15 + urgency * 0.6)
		if enemy.behavior == &"snipe":
			draw_dashed_line(from, target, Color(tint, 0.18 + urgency * 0.24), scale_factor, 9.0 * scale_factor, true)
			var mark_radius := (9.0 + (1.0 - urgency) * 9.0) * scale_factor
			for corner in 4:
				var angle := corner * PI * 0.5 + PI * 0.125
				draw_arc(target, mark_radius, angle, angle + PI * 0.25, 8, Color(tint, 0.75), 1.4 * scale_factor, true)
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
	DebugLog.end(&"battle.threat_draw", started)


static func threat_color(threat: BattleThreat) -> Color:
	if threat.reflected: return Color("adf1ce")
	if threat.heavy: return Color("ee9475")
	match threat.visual_style:
		&"needle": return Color("f4d798")
		&"refrain": return Color("e0bdd0")
		&"wisp": return Color("b4c8e5")
		&"rune": return Color("d3afe5")
		&"vortex": return Color("bdacd9")
		&"shard": return Color("e6bc92")
	return Color("efb28d")


func _draw_threat_head(canvas: CanvasItem, threat: BattleThreat, point: Vector2, radius: float, tint: Color, edge: float, heading: float) -> void:
	# The HDR world owns emission; keep a modest fallback when bloom is disabled.
	if quality == 0:
		canvas.draw_texture_rect(_orb, Rect2(point - Vector2.ONE * radius * 2.5, Vector2.ONE * radius * 5.0), false, Color(tint, 0.26))
	canvas.draw_set_transform(point, heading, Vector2.ONE * radius)
	var body := Color(tint * 0.85, 0.55)
	var core := Color("fff1d6") if not threat.reflected else Color("e2ffe9")
	var style := &"heavy" if threat.heavy else threat.visual_style
	match style:
		&"needle":
			var outline := PackedVector2Array([Vector2(1.65, 0), Vector2(-0.65, -0.85), Vector2(-1.2, 0), Vector2(-0.65, 0.85), Vector2(1.65, 0)])
			canvas.draw_colored_polygon(outline, body)
			canvas.draw_polyline(outline, tint, edge * 1.4, true)
			canvas.draw_line(Vector2(-0.8, 0), Vector2(1.25, 0), core, edge * 1.3, true)
		&"quill":
			var outline := PackedVector2Array([Vector2(1.3, 0), Vector2(-0.6, -1), Vector2(-0.2, 0), Vector2(-0.6, 1), Vector2(1.3, 0)])
			canvas.draw_colored_polygon(outline, Color(tint, 0.65))
			canvas.draw_polyline(outline, tint, edge, true)
			canvas.draw_line(Vector2(-0.2, 0), Vector2(1.1, 0), core, edge, true)
		&"refrain":
			for side: float in [-1.0, 1.0]:
				var page := PackedVector2Array([Vector2(0.8, 0), Vector2(0.4, side), Vector2(-1, side * 0.7), Vector2(-0.5, 0), Vector2(0.8, 0)])
				canvas.draw_colored_polygon(page, body)
				canvas.draw_polyline(page, tint, edge * 1.4, true)
				canvas.draw_line(Vector2(-0.45, side * 0.35), Vector2(0.3, side * 0.45), core, edge, true)
		&"wisp":
			canvas.draw_arc(Vector2.ZERO, 1.0, -PI * 0.65, PI * 0.65, 20, tint, edge * 2.8, true)
			canvas.draw_arc(Vector2(0.14, 0), 0.65, -PI * 0.6, PI * 0.6, 16, core, edge, true)
		&"rune":
			var diamond := PackedVector2Array([Vector2(1.2, 0), Vector2(0, -1.2), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(1.2, 0)])
			canvas.draw_colored_polygon(diamond, body)
			canvas.draw_polyline(diamond, tint, edge * 1.4, true)
			canvas.draw_line(Vector2(-0.4, 0), Vector2(0.4, 0), core, edge, true)
			canvas.draw_line(Vector2(0, -0.4), Vector2(0, 0.4), core, edge, true)
		&"vortex":
			canvas.draw_circle(Vector2.ZERO, 1.0, body)
			for arm in 2:
				var curve := PackedVector2Array()
				for index in 17:
					var fraction := float(index) / 16.0
					curve.append(Vector2.from_angle(fraction * PI * 1.5 + arm * PI) * lerpf(0.2, 1.1, fraction))
				canvas.draw_polyline(curve, tint, edge * 1.5, true)
		&"shard":
			var crystal := PackedVector2Array([Vector2(1.25, 0), Vector2(-0.3, -1), Vector2(-1, -0.45), Vector2(-1, 0.45), Vector2(-0.3, 1), Vector2(1.25, 0)])
			canvas.draw_colored_polygon(crystal, Color(tint, 0.35))
			canvas.draw_polyline(crystal, tint, edge * 1.3, true)
			canvas.draw_line(Vector2(-0.7, 0), Vector2(1.0, 0), core, edge, true)
		&"heavy":
			canvas.draw_circle(Vector2.ZERO, 1.0, body)
			canvas.draw_arc(Vector2.ZERO, 1.0, 0, TAU, 24, tint, edge * 2, true)
			for tooth in 4:
				var axis := Vector2.from_angle(tooth * PI * 0.5)
				canvas.draw_line(axis * 0.65, axis * 1.2, tint, edge * 2, true)
			canvas.draw_circle(Vector2.ZERO, 0.3, core)
		_:
			canvas.draw_circle(Vector2.ZERO, 0.9, body)
			canvas.draw_arc(Vector2.ZERO, 0.9, 0, TAU, 20, tint, edge * 1.4, true)
			canvas.draw_circle(Vector2.ZERO, 0.45, core)
	if threat.reflected:
		canvas.draw_line(Vector2(-0.3, 0), Vector2(0.6, 0), core, edge * 1.8, true)
	canvas.draw_set_transform(Vector2.ZERO)


class ThreatHead extends Node2D:
	var painter: BattleThreatOverlay
	var threat: BattleThreat
	var tint := Color.TRANSPARENT
	var edge := 0.0
	var style: StringName
	var detail := -1

	func sync(view_size: Vector2, fraction: float, scale_factor: float) -> void:
		position = threat.previous_position.lerp(threat.position, fraction) * view_size
		rotation = (threat.velocity * view_size / BattleSession.ARENA_SIZE).angle()
		var radius := threat.radius * scale_factor
		scale = Vector2.ONE * radius
		var next_tint := BattleThreatOverlay.threat_color(threat)
		var next_edge := maxf(1.0, scale_factor) / radius
		var next_style: StringName = &"heavy" if threat.heavy else threat.visual_style
		if tint != next_tint or edge != next_edge or style != next_style or detail != painter.quality:
			tint = next_tint
			edge = next_edge
			style = next_style
			detail = painter.quality
			queue_redraw()

	func _draw() -> void:
		painter._draw_threat_head(self, threat, Vector2.ZERO, 1.0, tint, edge, 0.0)
