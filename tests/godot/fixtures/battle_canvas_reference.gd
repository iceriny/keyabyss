extends Control
## Frozen pre-cache Canvas commands for HDR pixel and ordering regression.

const ENEMY_COLORS := {
	&"nib": Color("8cc4b8"), &"quill": Color("dcb887"), &"guard": Color("a6bcd9"),
	&"wisp": Color("9ec7e6"), &"ram": Color("c49a85"), &"ink-colossus": Color("ba91c9"),
	&"binder": Color("a7c7ad"), &"brood": Color("b3a0bf"), &"leech": Color("9fc3aa"),
	&"mirror": Color("c0cce2"), &"mortar": Color("c7aa8a"), &"priest": Color("a4cbbb"),
	&"reaper": Color("b7a8b6"), &"scribe": Color("d1b298"), &"sentinel": Color("b5c0ca"),
	&"split": Color("c4c1a4"), &"tower": Color("c5afe0"), &"vortex": Color("b2a7d6"),
	&"echo-archivist": Color("b4c9eb"), &"final-editor": Color("d8adab"),
	&"pin-archer": Color("d4b78e"), &"refrain": Color("b9bfd3"), &"folio-warden": Color("b1c5ab")
}

var session: BattleSession
var school_color := Color("8bdeff")
var reduced_motion := false
var _spark_texture: Texture2D
var _dodge_echoes: Array[Dictionary] = []
var _pulses: Array[Dictionary] = []
var _charge := 0.0
var _recoil := Vector2.ZERO
var _perfect_dodge_until := 0.0


func _draw() -> void:
	if session == null:
		return
	var started := DebugLog.begin()
	var stage_started := started
	_draw_edge_seal(Vector2(-size.x * 0.08, size.y * 0.17), size.y * 0.46, -0.35)
	_draw_edge_seal(Vector2(size.x * 1.06, size.y * 0.87), size.y * 0.42, 2.7)
	for pickup in session.pickups:
		if not pickup.alive(): continue
		var center: Vector2 = pickup.position * size
		var color := Color("a7e4c5") if pickup.kind == &"rune" else Color("e8b988")
		var radius: float = pickup.radius
		draw_texture_rect(_spark_texture, Rect2(center - Vector2.ONE * 42, Vector2.ONE * 84), false, Color(color, 0.17))
		var outline := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
		draw_colored_polygon(outline, Color(color, 0.14))
		draw_polyline(outline, color, 1.8, true)
		if pickup.kind == &"rune":
			ArcanaRunes.draw(self, "反", center, radius * 1.65, color)
		else:
			for index in 4:
				var axis := Vector2.from_angle(PI * 0.25 + index * PI * 0.5)
				draw_line(center + axis * 3, center + axis * radius * 0.6, color, 2.0, true)
	for echo in _dodge_echoes:
		var fade: float = 1.0 - echo.age / 0.27
		draw_texture_rect(BattleActorVisual.PLAYER, Rect2(echo.at - Vector2.ONE * 55, Vector2.ONE * 110), false, Color(school_color * 1.4, fade * 0.32))
	DebugLog.end(&"battle.draw_background", stage_started)
	stage_started = DebugLog.begin()
	for enemy in session.enemies:
		var point := enemy.previous_position.lerp(enemy.position, Engine.get_physics_interpolation_fraction()) * size
		if enemy.alive():
			if enemy.behavior == &"ward": _draw_ward(point, enemy)
			_draw_enemy(point, enemy)
			if session.typing.target_id == enemy.id and BattleSession.enemy_in_combat(enemy):
				var from := session.player_position * size
				_draw_lock(from, point, enemy.radius + 21.0)
	DebugLog.end(&"battle.draw_enemies", stage_started)
	stage_started = DebugLog.begin()
	var player := session.previous_player_position.lerp(session.player_position, Engine.get_physics_interpolation_fraction()) * size
	_draw_player(player)
	DebugLog.end(&"battle.draw_player", stage_started)
	stage_started = DebugLog.begin()
	for pulse in _pulses:
		if pulse.has("node"):
			continue
		var fraction: float = pulse.age / pulse.duration
		var color: Color = pulse.color
		if pulse.kind == &"ember":
			for mote in 4:
				var offset := Vector2.from_angle(mote * 2.399 + pulse.at.x * 14.0) * (6.0 + fraction * 22.0)
				var point: Vector2 = pulse.at * size + offset
				draw_texture_rect(_spark_texture, Rect2(point - Vector2.ONE * 5, Vector2.ONE * 10), false, Color(color * 1.5, (1.0 - fraction) * 0.6))
	DebugLog.end(&"battle.draw_pulses", stage_started)
	DebugLog.end(&"battle.draw_commands", started)


func _draw_edge_seal(center: Vector2, radius: float, phase: float) -> void:
	draw_set_transform(center, phase)
	draw_texture_rect(ArcanaRunes.seal(session.book_id, radius * 2.0), Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color("b6ad87", .052))
	draw_set_transform(Vector2.ZERO)


func _draw_ward(point: Vector2, source: BattleEnemy) -> void:
	var target := session.ward_target(source)
	if target == null: return
	var endpoint := target.previous_position.lerp(target.position, Engine.get_physics_interpolation_fraction()) * size
	var axis := endpoint - point
	var bow := axis.orthogonal().normalized() * minf(22.0, axis.length() * 0.12)
	var curve := PackedVector2Array()
	for index in 17:
		var fraction := float(index) / 16.0
		curve.append(point.lerp(endpoint, fraction) + bow * sin(fraction * PI))
	draw_polyline(curve, Color("a7c6b3", 0.10), 4.0, true)
	draw_polyline(curve, Color("c9cead", 0.62), 1.1, true)
	var radius := target.radius + 9.0
	for side: float in [-1.0, 1.0]:
		var angle := side * PI * 0.5
		draw_arc(endpoint, radius, angle - 0.5, angle + 0.5, 16, Color("c9cead", 0.75), 1.8, true)
	var bud := point.lerp(endpoint, 0.52) + bow
	var tangent := axis.normalized()
	var leaf := PackedVector2Array([bud - tangent * 7.0, bud + tangent.orthogonal() * 3.5, bud + tangent * 7.0, bud - tangent.orthogonal() * 3.5])
	draw_colored_polygon(leaf, Color("b6c7a6", 0.6))


func _draw_enemy(point: Vector2, enemy: BattleEnemy) -> void:
	if not BattleSession.enemy_in_combat(enemy):
		return
	var tint: Color = ENEMY_COLORS[enemy.kind]
	if enemy.frozen_time > 0.0:
		tint = Color("a7def4")
	draw_set_transform(point)
	point = Vector2.ZERO
	if enemy.aura != &"":
		var aura_color := Color("acccb8") if enemy.aura == &"speed" else Color("bda7d4")
		draw_arc(point, enemy.aura_radius * size.x / BattleSession.ARENA_SIZE.x, 0, TAU, 96, Color(aura_color, 0.19), 1.2, true)
	if enemy.mirror_ready or enemy.shielded:
		var radius := enemy.radius + 11.0
		for arc in 6:
			var angle := arc * TAU / 6.0
			draw_arc(point, radius, angle, angle + 0.72, 12, Color("b9d5ed", 0.7), 2.2, true)
	if enemy.hp_q < enemy.max_hp_q:
		var width := 110.0 if enemy.boss else 44.0
		var height := enemy.radius + 18.0
		draw_rect(Rect2(point + Vector2(-width * 0.5, height), Vector2(width, 3)), Color("17272d"))
		draw_rect(Rect2(point + Vector2(-width * 0.5, height), Vector2(width * enemy.hp_q / enemy.max_hp_q, 3)), tint)
		if enemy.burn > 10:
			var ticks := ceili((enemy.burn - 10) / 5.0)
			var burn_damage := ticks * 6.0 * BattleSession.Q * session.runtime.damage_multiplier() * (1.0 + .3 * session.compiled_build.asset_stacks(&"R050")) * (1.35 if session.compiled_build.asset_stacks(&"R056") > 0 else 1.0)
			burn_damage *= (1.0 + 2.0 * enemy.vulnerability / 127.0) * (1.0 - float(enemy.resistances[DamagePacket.Element.FIRE]) / BattleSession.Q)
			var tail := minf(enemy.hp_q, burn_damage) / enemy.max_hp_q * width
			draw_rect(Rect2(Vector2(-width * .5 + width * enemy.hp_q / enemy.max_hp_q - tail, height), Vector2(tail, 3)), Color("f4ae70", .85))
	if enemy.cold > 0 or enemy.frozen_time > 0.0:
		var progress := 1.0 if enemy.frozen_time > 0.0 else minf(1.0, enemy.cold / 91.0)
		draw_arc(point, enemy.radius + 7, -PI * .5, -PI * .5 + TAU * progress, 48, Color("9bdcea", .85), 1.6, true)
	if enemy.shock > 0:
		for branch in (3 if enemy.shock > 60 else (2 if enemy.shock > 30 else 1)):
			var offset := Vector2(enemy.radius + 7, -8 + branch * 9)
			draw_polyline(PackedVector2Array([offset + Vector2(3,-4), offset + Vector2(-2,0), offset + Vector2(3,0), offset + Vector2(-1,5)]), Color("f6d998", .85), 1.3, true)
	if enemy.marked_time > 0.0:
		draw_arc(point, 32, -PI * 0.8, PI * 0.3, 24, Color("cab0ed", 0.5), 1.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_player(point: Vector2) -> void:
	var tint := school_color.lerp(Color("e9ca8e"), 0.22)
	var motion := 0.0 if reduced_motion else session.world_time
	var perfect_remaining := _perfect_dodge_until - session.elapsed
	if perfect_remaining > 0.0 and session.dodge_window > 0.0:
		var strength := minf(1.0, perfect_remaining / 0.12)
		var gold := Color("f2dfac", strength * 0.85)
		draw_texture_rect(_spark_texture, Rect2(point - Vector2.ONE * 72.0, Vector2.ONE * 144.0), false, Color("c4ddda", strength * 0.14))
		for side in 2:
			var angle := side * PI + 0.24
			draw_arc(point, 43.0, angle, angle + PI - 0.48, 32, gold, 1.7, true)
			var tip := point + Vector2.from_angle(side * PI) * 43.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -5), tip + Vector2(3, 0), tip + Vector2(0, 5), tip - Vector2(3, 0)]), gold)
	if session.compiled_build.has(&"assist") and session.runtime.assist_ready():
		var pulse := 1.0 if reduced_motion else .64 + .36 * pow(.5 + .5 * sin(motion * 3.8), 2.0)
		var at := point + Vector2(57, -20)
		draw_texture_rect(_spark_texture, Rect2(at - Vector2.ONE * 24, Vector2.ONE * 48), false, Color(tint, .16 * pulse))
		ArcanaRunes.draw(self, "全", at, 32.0, Color(tint * 1.5, pulse))
	if session.parry_window > 0.0:
		ArcanaRunes.draw(self, "护", point + Vector2(-48, -15), 36.0, Color("e5d5ad", .7))
	draw_texture_rect(_spark_texture, Rect2(point - Vector2.ONE * 95, Vector2.ONE * 190), false, Color(tint, 0.08 + _charge * 0.24))
	var diameter := 126.0 + _charge * 30.0
	draw_texture_rect(ArcanaRunes.seal(session.book_id, diameter), Rect2(point - Vector2.ONE * diameter * .5, Vector2.ONE * diameter), false, Color(tint, .22 + _charge * .36))
	var staff := point + Vector2(19, -31) + _recoil
	var glow_radius := 24.0 + _charge * 30.0
	draw_texture_rect(_spark_texture, Rect2(staff - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2), false, Color(tint * 1.2, 0.32 + _charge * 0.3))
	for mote in mini(session.typing.progress, 12):
		var angle := mote * TAU / mini(session.typing.progress, 12) + (0.0 if reduced_motion else session.elapsed * 1.8)
		var at := point + Vector2(cos(angle) * 33, sin(angle) * 25 - 6)
		draw_texture_rect(_spark_texture, Rect2(at - Vector2(6, 6), Vector2(12, 12)), false, Color(tint, 0.28))
		draw_circle(at, 1.3, Color(tint * 1.3, 0.9))


func _draw_lock(from: Vector2, point: Vector2, radius: float) -> void:
	var motion := 0.0 if reduced_motion else session.world_time
	var direction := (point - from).normalized()
	var distance := point.distance_to(from)
	if distance > radius + 45.0:
		var offset := fposmod(motion * 20.0, 13.0)
		var count := floori((distance - radius - 35) / 13.0)
		var dashes := PackedVector2Array()
		dashes.resize(count * 2)
		for step in count:
			var start := from + direction * (35 + step * 13.0 + offset)
			dashes[step * 2] = start
			dashes[step * 2 + 1] = start + direction * 3
		if not dashes.is_empty():
			draw_multiline(dashes, Color("f9d895", 0.38), 1.0, true)
	for quadrant in 4:
		var angle := quadrant * PI * 0.5 + PI * 0.25
		var axis := Vector2.from_angle(angle)
		var side := axis.orthogonal()
		var at := point + axis * radius
		draw_polyline(PackedVector2Array([at - axis * 5 - side * 8, at - side * 8, at + side * 8, at - axis * 5 + side * 8]), Color("ffdea0"), 1.8, true)
	for arc in 3:
		var angle := motion * 0.5 + arc * TAU / 3.0
		draw_arc(point, radius + 7, angle, angle + 0.65, 16, Color("f8d28d", 0.65), 1.0, true)
	var progress := _charge
	if progress > 0:
		draw_arc(point, radius + 11, -PI * 0.5, -PI * 0.5 + TAU * progress, 80, Color("aaf2e5"), 2.6, true)
