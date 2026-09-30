class_name BattleVisuals
extends Control
## World geometry and Godot particles consume committed battle events only.

var session: BattleSession
var school_color := Color("8bdeff")
var quality: int = 2
var reduced_motion: bool = false
var _pulses: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _wave_plane: ColorRect
var _wave_material: ShaderMaterial
@export var spark_texture: GradientTexture2D
var _spark_texture: GradientTexture2D
var _projectile_nodes: Dictionary[BattleProjectile, BattleProjectileVisual] = {}
var _spirit_nodes: Dictionary[BattleSpirit, BattleSpiritVisual] = {}
var _ultimate_nodes: Dictionary[BattleUltimate, UltimateField] = {}
var _recoil := Vector2.ZERO
var _actors: Dictionary[StringName, BattleActorVisual] = {}
var _player: BattleActorVisual
var _dodge_echoes: Array[Dictionary] = []
var _echo_clock: float = 0.0
var _charge: float = 0.0
var _charge_attempt := ""
var camera_offset := Vector2.ZERO
var _camera_motion := DampedMotion.new()
var fluid: FluidAtmosphere
var fluid_quality: int = 2
var fluid_material: FluidMedium
var fluid_effects: Dictionary[StringName, FluidEffectProfile] = {}
var rule_visuals: BattleRuleVisuals


func configure(battle: BattleSession, tint: Color, visual_quality: int, less_motion: bool) -> void:
	session = battle
	school_color = tint
	quality = visual_quality
	reduced_motion = less_motion


func set_options(detail: int, less_motion: bool) -> void:
	if quality == detail and reduced_motion == less_motion:
		return
	quality = detail
	fluid.scene_quality = detail
	reduced_motion = less_motion
	for visual in _projectile_nodes.values():
		visual.queue_free()
	_projectile_nodes.clear()
	if reduced_motion or quality == 0:
		_waves.clear()
		_dodge_echoes.clear()
		_camera_motion.reset()
		camera_offset = Vector2.ZERO
		_recoil = Vector2.ZERO
		for child in get_children():
			if child is GPUParticles2D:
				child.queue_free()
	_update_waves()


func _ready() -> void:
	fluid = FluidAtmosphere.new()
	fluid.name = "FluidAtmosphere"
	fluid.scene_quality = quality
	fluid.battle = session
	fluid.trail_material = fluid_material
	fluid.effects = fluid_effects
	fluid.fog_color = Color("668b9b").lerp(school_color, .18)
	fluid.light_color = school_color
	fluid.set_options(fluid_quality, reduced_motion)
	add_child(fluid)
	move_child(fluid, 0)
	rule_visuals = BattleRuleVisuals.new()
	rule_visuals.session = session
	add_child(rule_visuals)
	move_child(rule_visuals, 1)
	fluid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wave_plane = $Shockwave
	_wave_material = _wave_plane.material as ShaderMaterial
	_spark_texture = spark_texture
	_player = BattleActorVisual.create(&"player", school_color, _spark_texture)
	_player.name = "Player"
	add_child(_player)
	for enemy in session.enemies:
		_create_actor(enemy)


func _create_actor(enemy: BattleEnemy) -> void:
	var tint: Color = {&"nib": Color("8cc4b8"), &"quill": Color("dcb887"), &"guard": Color("a6bcd9")}[enemy.kind]
	var actor := BattleActorVisual.create(enemy.kind, tint, _spark_texture)
	actor.name = str(enemy.id)
	add_child(actor)
	_actors[enemy.id] = actor


func _process(delta: float) -> void:
	rule_visuals.size = size
	rule_visuals.quality = quality
	rule_visuals.reduced_motion = reduced_motion
	_recoil *= exp(-delta * 16.0)
	if reduced_motion:
		_camera_motion.reset()
	else:
		_camera_motion.advance(delta, 5.0)
	camera_offset = _camera_motion.position
	var desired_charge := float(session.typing.progress) / maxf(1.0, session.typing.word.length())
	var attempt := "%s:%s" % [session.typing.target_id, session.typing.word]
	if attempt != _charge_attempt or desired_charge < _charge:
		_charge = 0.0
		_charge_attempt = attempt
	_charge = desired_charge if reduced_motion else lerpf(_charge, desired_charge, 1.0 - exp(-delta * 18.0))
	var fraction := Engine.get_physics_interpolation_fraction()
	_player.sync_player(session.previous_player_position.lerp(session.player_position, fraction) * size, session.elapsed, _recoil, session.hurt_window, delta, reduced_motion)
	_player.aura.modulate = Color(school_color, 0.07 + _charge * 0.2)
	_player.aura.scale = Vector2(1.6, 0.9) * (1.0 + _charge * 0.45)
	_player.body.modulate.a = (0.82 + sin(session.elapsed * 16) * 0.18) if session.dodge_window > 0.0 and not reduced_motion else 1.0
	if not reduced_motion and session._dodge_time < 0.17:
		_echo_clock -= delta
		if _echo_clock <= 0.0:
			_echo_clock = 0.018
			_dodge_echoes.append({"at": _player.position, "age": 0.0})
	for index in range(_dodge_echoes.size() - 1, -1, -1):
		_dodge_echoes[index].age += delta
		if _dodge_echoes[index].age >= 0.27:
			_dodge_echoes.remove_at(index)
	for enemy in session.enemies:
		if not _actors.has(enemy.id):
			_create_actor(enemy)
		_actors[enemy.id].sync_enemy(enemy, enemy.previous_position.lerp(enemy.position, fraction) * size, session.elapsed, delta, reduced_motion)
		_actors[enemy.id].modulate.a = (1.0 - _actors[enemy.id].dead_time) * (1.0 if enemy.combat_locked else 0.06 + 0.94 * pow(BattleSession.arena_clarity(enemy.position, enemy.radius), 2.0))
	for projectile in session.projectiles:
		if not _projectile_nodes.has(projectile):
			var visual := BattleProjectileVisual.create(projectile, quality, reduced_motion)
			visual.world_size = size
			add_child(visual)
			_projectile_nodes[projectile] = visual
		_projectile_nodes[projectile].sync_frame(size, Engine.get_physics_interpolation_fraction())
	for projectile in _projectile_nodes.keys():
		if not session.projectiles.has(projectile):
			_projectile_nodes[projectile].retire()
			_projectile_nodes.erase(projectile)
	for spirit in session.spirits:
		if not _spirit_nodes.has(spirit):
			var visual := BattleSpiritVisual.create(spirit)
			add_child(visual)
			_spirit_nodes[spirit] = visual
		_spirit_nodes[spirit].sync_frame(size, fraction, session.spirit_time, delta, quality, reduced_motion)
	for spirit in _spirit_nodes.keys():
		if not session.spirits.has(spirit):
			_spirit_nodes[spirit].retire()
			_spirit_nodes.erase(spirit)
	for timeline in session.ultimates:
		if not _ultimate_nodes.has(timeline):
			var field := UltimateField.create(timeline, school_color)
			$Fields.add_child(field)
			_ultimate_nodes[timeline] = field
		_ultimate_nodes[timeline].sync_frame(size, quality, reduced_motion)
	for timeline in _ultimate_nodes.keys():
		if not session.ultimates.has(timeline):
			_ultimate_nodes[timeline].queue_free()
			_ultimate_nodes.erase(timeline)
	for index in range(_pulses.size() - 1, -1, -1):
		_pulses[index]["age"] = float(_pulses[index]["age"]) + delta
		if _pulses[index].has("node"):
			var sprite: Sprite2D = _pulses[index]["node"]
			if _pulses[index].get("guard", false):
				_pulses[index].at = _player_uv()
			sprite.position = _pulses[index].at * size
			(sprite.material as ShaderMaterial).set_shader_parameter("progress", minf(1.0, _pulses[index].age / _pulses[index].duration))
		if float(_pulses[index]["age"]) >= float(_pulses[index]["duration"]):
			if _pulses[index].has("node"):
				_pulses[index]["node"].queue_free()
			_pulses.remove_at(index)
	for index in range(_waves.size() - 1, -1, -1):
		_waves[index]["age"] = float(_waves[index]["age"]) + delta
		if float(_waves[index]["age"]) >= float(_waves[index]["duration"]):
			_waves.remove_at(index)
	_update_waves()
	queue_redraw()


func present(event: Dictionary) -> void:
	fluid.present(event)
	var kind: StringName = event.kind
	var at: Vector2 = event.get("at", Vector2(0.5, 0.5))
	match kind:
		&"cast":
			if not reduced_motion:
				_recoil = ((at - event.target) * size).normalized() * 7.0
			_pulses.append({"kind": &"cast", "at": at, "target": event.target, "age": 0.0, "duration": 0.32 if event.empowered else 0.2, "color": school_color, "empowered": event.empowered, "book": event.book})
		&"impact":
			var contact: Vector2 = event.contact
			var direction: Vector2 = event.direction
			if event.source == &"flame_burn":
				_pulses.append({"kind": &"ember", "at": contact, "age": 0.0, "duration": 0.35, "color": Color("ec813e")})
				return
			var color := _effect_color(event.source)
			var empowered: bool = event.get("empowered", false)
			if not reduced_motion:
				_camera_motion.kick(direction * (5.0 if event.source == &"counter" else 1.7), 5.0 if event.source == &"counter" else 1.7)
			if _actors.has(event.enemy):
				_actors[event.enemy].receive_impact(direction, 5.0 if empowered else 3.0, reduced_motion)
			if str(event.source).begins_with("flame"):
				_spawn_flame_burst(contact, (180.0 if empowered else 150.0) if event.source in [&"flame_burst", &"flame_ultimate"] else 65.0)
			else:
				_pulses.append({"kind": &"ring", "at": contact, "origin": event["from"], "source": event.source, "age": 0.0, "duration": 0.68 if empowered else 0.55, "color": color, "empowered": empowered})
			_spawn_particles(contact, color, 0.7, true, event.source, Vector2.ZERO if str(event.source).ends_with("_ultimate") else direction)
			if event.source in [&"frost_ultimate", &"counter"]:
				_add_wave(contact, 0.46, 0.0035)
		&"death":
			_spawn_particles(at, Color("e8d6ae"), 0.9, true)
			_add_wave(at, 0.72, -0.004, 0.075)
		&"parry_start":
			_spawn_counter_pulse(at, true)
		&"counter_pulse":
			_spawn_particles(_player_uv(), Color("d9f7ff"), 0.8, true)
			_add_wave(_player_uv(), 0.52, 0.009)
			_spawn_counter_pulse(at)
		&"enemy_attack":
			if event.outcome == &"hit":
				_add_wave(_player_uv(), 0.4, 0.005)
				var direction: Vector2 = ((at - event["from"]) * size).normalized()
				_player.receive_impact(direction, 5.0, reduced_motion)
				if not reduced_motion:
					_camera_motion.kick(direction * 5.0, 5.0)
		&"ultimate":
			var center: Vector2 = event.center
			_spawn_particles(center, school_color, 1.2, true, StringName(str(session.book_id) + "_ultimate"))
			_add_wave(center, 1.1, 0.008)
		&"spirit_summon":
			_spawn_particles(at, Color("d9c8ff"), 0.5, false)
		&"dodge":
			if not reduced_motion:
				_echo_clock = 0.0
				_spawn_particles(at, school_color, 0.35, true)
		&"dodge_end":
			_spawn_particles(at, school_color, 0.4, true)
			_pulses.append({"kind": &"ring", "at": at, "age": 0.0, "duration": 0.25, "color": school_color})
	queue_redraw()


func _draw() -> void:
	if session == null:
		return
	_draw_edge_seal(Vector2(-size.x * 0.08, size.y * 0.17), size.y * 0.46, -0.35)
	_draw_edge_seal(Vector2(size.x * 1.06, size.y * 0.87), size.y * 0.42, 2.7)
	for echo in _dodge_echoes:
		var fade: float = 1.0 - echo.age / 0.27
		draw_texture_rect(BattleActorVisual.PLAYER, Rect2(echo.at - Vector2.ONE * 55, Vector2.ONE * 110), false, Color(school_color * 1.4, fade * 0.32))
	for threat in session.threats:
		var at := threat.previous_position.lerp(threat.position, Engine.get_physics_interpolation_fraction()) * size
		var tint := Color("c5ffc9") if threat.reflected else Color("ffb197")
		draw_texture_rect(_spark_texture, Rect2(at - Vector2.ONE * 29, Vector2.ONE * 58), false, Color(tint, 0.24))
		if quality > 0 and not reduced_motion:
			var samples := PackedVector2Array()
			for sample in threat.trail:
				samples.append(sample * size)
			var tail := MotionTrail.build(samples, threat.position * size, at, 180.0, false, 12)
			for i in range(1, tail.size()):
				var alpha := float(i) / tail.size() * 0.2
				draw_line(tail[i - 1], tail[i], Color(tint, alpha), 2.0, true)
	for enemy in session.enemies:
		var point := enemy.previous_position.lerp(enemy.position, Engine.get_physics_interpolation_fraction()) * size
		if enemy.alive():
			_draw_enemy(point, [&"nib", &"quill", &"guard"].find(enemy.kind), enemy)
			if session.typing.target_id == enemy.id and BattleSession.enemy_in_combat(enemy):
				var from := session.player_position * size
				_draw_lock(from, point, enemy.radius + 21.0)
	var player := session.previous_player_position.lerp(session.player_position, Engine.get_physics_interpolation_fraction()) * size
	_draw_player(player)
	if session.dodge_window > 0.0:
		draw_arc(player, 31, 0, TAU, 48, Color(school_color, 0.3), 1.2, true)
	for pulse in _pulses:
		if pulse.has("node"):
			continue
		var fraction: float = pulse.age / pulse.duration
		var color: Color = pulse.color
		if pulse.kind == &"cast":
			_draw_cast(pulse, fraction)
		elif pulse.kind == &"ember":
			for mote in 4:
				var offset := Vector2(sin(mote * 2.3) * 12, -fraction * 22 + cos(mote * 1.8) * 8)
				draw_circle(pulse.at * size + offset, 1.3, Color(color, (1.0 - fraction) * 0.55))
		else:
			if pulse.has("source"):
				_draw_spell_shape(pulse, fraction, color)
			else:
				draw_arc(pulse.at * size, 12 + fraction * 55, 0, TAU, 64, Color(color, (1.0 - fraction) * 0.4), 1.6, true)


func _draw_edge_seal(center: Vector2, radius: float, phase: float) -> void:
	var etch := Color("9e9574", 0.034)
	for ring in [0.68, 0.83, 1.0]:
		draw_arc(center, radius * ring, phase, phase + PI * 1.58, 120, etch, 1.0, true)
	for mark in 47:
		var angle := phase + mark * PI * 1.58 / 46.0
		var direction := Vector2.from_angle(angle)
		var reach := 13.0 if mark % 4 == 0 else 6.0
		draw_line(center + direction * radius * 0.87, center + direction * (radius * 0.87 + reach), Color("a99e7c", 0.035), 1.0, true)
	for glyph in 24:
		var angle := phase + glyph * PI * 1.58 / 23.0
		var axis := Vector2.from_angle(angle)
		var at := center + axis * radius * 0.93
		var side := axis.orthogonal()
		draw_polyline(PackedVector2Array([at - axis * 5, at + axis * 5, at + side * 4, at - side * 3 - axis * 2]), Color("b6ad87", 0.065), 0.7, true)


func _draw_enemy(point: Vector2, index: int, enemy: BattleEnemy) -> void:
	if not BattleSession.enemy_in_combat(enemy):
		return
	var tint: Color = [Color("a0c4bf"), Color("d0a477"), Color("aabbd5")][index]
	if enemy.frozen_time > 0.0:
		tint = Color("a7def4")
	draw_set_transform(point)
	point = Vector2.ZERO
	if enemy.hp_q < enemy.max_hp_q:
		draw_rect(Rect2(point + Vector2(-22, 36), Vector2(44, 3)), Color("17272d"))
		draw_rect(Rect2(point + Vector2(-22, 36), Vector2(44.0 * enemy.hp_q / enemy.max_hp_q, 3)), tint)
	if enemy.marked_time > 0.0:
		draw_arc(point, 32, -PI * 0.8, PI * 0.3, 24, Color("cab0ed", 0.5), 1.0, true)
	if enemy.frozen_time > 0.0:
		for shard in 5:
			var angle := shard * TAU / 5.0
			var axis := Vector2.from_angle(angle)
			var center := axis * 23
			draw_colored_polygon(PackedVector2Array([center + axis * 10, center + axis.orthogonal() * 4, center - axis * 6, center - axis.orthogonal() * 4]), Color("a9e9ff", 0.22))
	draw_set_transform(Vector2.ZERO)


func _draw_player(point: Vector2) -> void:
	var tint := school_color.lerp(Color("e9ca8e"), 0.22)
	var motion := 0.0 if reduced_motion else session.elapsed
	var radius := 30.0 + _charge * 18.0
	draw_texture_rect(_spark_texture, Rect2(point - Vector2.ONE * 95, Vector2.ONE * 190), false, Color(tint, 0.08 + _charge * 0.24))
	# Flattened ground seal, then the raised staff light and floating charge motes.
	draw_set_transform(point + Vector2(0, 18), 0, Vector2(1, 0.52))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 80, Color(tint * 1.2, 0.3 + _charge * 0.5), 1.5, true)
	for segment in 8:
		var angle := segment * TAU / 8.0 + motion * 0.18
		var axis := Vector2.from_angle(angle)
		draw_arc(Vector2.ZERO, radius + 15, angle, angle + 0.5, 12, Color(tint, _charge * 0.65), 1.2, true)
		draw_line(axis * (radius - 3), axis * (radius + 6), Color(tint * 1.4, 0.22 + _charge * 0.65), 1.5, true)
	draw_set_transform(Vector2.ZERO)
	var staff := point + Vector2(19, -31) + _recoil
	var glow_radius := 24.0 + _charge * 30.0
	draw_texture_rect(_spark_texture, Rect2(staff - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2), false, Color(tint * 1.2, 0.32 + _charge * 0.3))
	for mote in mini(session.typing.progress, 12):
		var angle := mote * TAU / mini(session.typing.progress, 12) + (0.0 if reduced_motion else session.elapsed * 1.8)
		var at := point + Vector2(cos(angle) * 33, sin(angle) * 25 - 6)
		draw_texture_rect(_spark_texture, Rect2(at - Vector2(6, 6), Vector2(12, 12)), false, Color(tint, 0.28))
		draw_circle(at, 1.3, Color(tint * 1.3, 0.9))


func _draw_lock(from: Vector2, point: Vector2, radius: float) -> void:
	var motion := 0.0 if reduced_motion else session.elapsed
	var direction := (point - from).normalized()
	var distance := point.distance_to(from)
	if distance > radius + 45.0:
		var offset := fposmod(motion * 20.0, 13.0)
		for step in floori((distance - radius - 35) / 13.0):
			var start := from + direction * (35 + step * 13.0 + offset)
			draw_line(start, start + direction * 3, Color("f9d895", 0.38), 1.0, true)
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


func _spawn_counter_pulse(at: Vector2, guard: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var texture := GradientTexture2D.new()
	texture.width = 384
	texture.height = 384
	texture.gradient = Gradient.new()
	sprite.texture = texture
	sprite.position = at * size
	var pulse_material := ShaderMaterial.new()
	pulse_material.shader = preload("res://ui/materials/counter_pulse.gdshader")
	pulse_material.set_shader_parameter("reduced_motion", reduced_motion)
	pulse_material.set_shader_parameter("guard", guard)
	sprite.material = pulse_material
	add_child(sprite)
	_pulses.append({"kind": &"counter_pulse", "node": sprite, "at": at, "age": 0.0, "duration": 0.24 if guard else 0.52, "guard": guard})


func _draw_cast(pulse: Dictionary, progress: float) -> void:
	var at: Vector2 = pulse.at * size
	var color: Color = pulse.color
	var fade := pow(1.0 - progress, 1.5)
	if not pulse.empowered:
		draw_arc(at, 17 + progress * 18, -PI * 0.9, PI * 0.6, 28, Color(color, fade * 0.35), 1.3, true)
		return
	var target: Vector2 = pulse.target * size
	var axis := (target - at).normalized()
	var side := axis.orthogonal()
	match pulse.book:
		&"frost":
			var tip := at + axis * (36.0 + progress * 76.0)
			var tail := at - axis * 15.0
			var spear := PackedVector2Array([tip, at + side * 10.0, tail, at - side * 10.0])
			draw_colored_polygon(spear, Color("91e1ff", fade * 0.3))
			draw_line(tail, tip, Color(1.5, 2.2, 2.5, fade * 0.8), 2.0, true)
			for wing in [-1.0, 1.0]:
				draw_line(at + axis * 25.0, at + axis * 4.0 + side * wing * 23.0, Color("a8ebff", fade * 0.7), 1.5, true)
		&"flame":
			for tongue in 3:
				var start := at + side * (tongue - 1) * 10.0
				var reach := 48.0 + progress * 35.0 - absf(tongue - 1) * 13.0
				var end := start + axis * reach + side * (tongue - 1) * 9.0
				draw_set_transform((start + end) * 0.5, axis.angle())
				draw_texture_rect(_spark_texture, Rect2(-reach * 0.65, -18.0, reach * 1.3, 36.0), false, Color("ffb657", fade * 0.25))
				draw_set_transform(Vector2.ZERO)
				draw_line(start + axis * 8.0, end, Color("ffe19a", fade * 0.72), 3.0, true)
		&"storm":
			for fork in [-1.0, 0.0, 1.0]:
				var end: Vector2 = at + axis * (75.0 + progress * 25.0) + side * fork * (29.0 + progress * 24.0)
				var bend: Vector2 = at + axis * 32.0 + side * fork * 8.0
				var bolt := PackedVector2Array([at, bend, bend + axis * 15.0 - side * fork * 7.0, end])
				draw_polyline(bolt, Color("b8bdff", fade * 0.2), 7.0, true)
				draw_polyline(bolt, Color("fff1b5", fade * 0.8), 1.5, true)
		&"spirit":
			for slash in [-1.0, 1.0]:
				var center := at + axis * (20.0 + progress * 28.0)
				draw_line(center - axis * 23.0 - side * slash * 15.0, center + axis * 23.0 + side * slash * 15.0, Color("f4e7ff", fade * 0.68), 2.3, true)
	draw_texture_rect(_spark_texture, Rect2(at - Vector2.ONE * 42.0, Vector2.ONE * 84.0), false, Color(color * 1.3, fade * 0.24))


func _draw_spell_shape(pulse: Dictionary, progress: float, color: Color) -> void:
	var point: Vector2 = pulse.at * size
	var origin: Vector2 = pulse.origin * size
	var source := str(pulse.source)
	var empowered: bool = pulse.empowered
	var flash := pow(1.0 - progress, 4.0)
	draw_texture_rect(_spark_texture, Rect2(point - Vector2(70, 70), Vector2(140, 140)), false, Color(color * 1.5, flash * 0.45))
	if source.begins_with("frost"):
		var shard_count := 12 if empowered else 8
		for shard in shard_count:
			var angle := TAU * shard / shard_count + 0.2
			var direction := Vector2.from_angle(angle)
			var side := direction.orthogonal()
			var center := point + direction * (18 + progress * (112.0 if empowered else 76.0))
			# Fade before collapsing a facet; a zero-length tip is not a polygon.
			var length := (29.0 if empowered and shard % 2 == 0 else 18.0) * (1.0 - progress * 0.65)
			var points := PackedVector2Array([center + direction * length, center + side * 4.0, center - direction * length * 0.7, center - side * 4.0])
			draw_colored_polygon(points, Color(color, (1.0 - progress) * 0.6))
			draw_colored_polygon(PackedVector2Array([points[0], points[1], points[2]]), Color("337499", (1.0 - progress) * 0.65))
			draw_line(points[0], points[2], Color(1.2, 1.8, 2.0, (1.0 - progress) * 0.75), 0.8, true)
	elif source == "counter":
		# A deflected impact is a brief warm compression, never a lightning link.
		var axis := (point - origin).normalized()
		var angle := axis.angle()
		var radius := 9.0 + progress * 38.0
		var fade := pow(1.0 - progress, 2.0)
		draw_arc(point, radius, angle - 1.1, angle + 1.1, 36, Color("e5efcf", fade * 0.5), 1.2, true)
	elif source.begins_with("storm"):
		var bolt := PackedVector2Array()
		var direction := (point - origin).normalized()
		var side := direction.orthogonal()
		var count := clampi(ceili(point.distance_to(origin) / (12.0 if empowered else 18.0)), 8, 52)
		for segment in count + 1:
			var along := float(segment) / count
			var jitter := (fposmod(sin(segment * 127.1 + floorf(progress * (9.0 if empowered else 5.0)) * 1.37) * 43758.5453, 1.0) * 2.0 - 1.0) * sin(along * PI) * (29.0 if empowered else 17.0)
			bolt.append(origin.lerp(point, along) + side * jitter)
		draw_polyline(bolt, Color(color, (1.0 - progress) * 0.24), 9.0 if empowered else 5.0, true)
		draw_polyline(bolt, Color(1.7, 1.5, 0.9, (1.0 - progress) * 0.9), 1.8 if empowered else 1.2, true)
		for branch in range(3, count - 1, 4 if empowered else 6):
			var endpoint := bolt[branch] + direction * 20 + side * sin(branch * 3.71) * 29
			draw_polyline(PackedVector2Array([bolt[branch], bolt[branch].lerp(endpoint, 0.45) + side * 8, endpoint]), Color(color, (1.0 - progress) * 0.35), 0.8, true)
	elif source == "spirit_cross":
		var axis := (point - origin).normalized()
		var sweep := 1.0 if reduced_motion else minf(1.0, progress / 0.24)
		var fade := pow(1.0 - progress, 1.5)
		var previous := point - axis * 150.0
		for segment in 28:
			var along := (segment + 1) / 28.0 * sweep
			var next := point + axis * (along * 2.0 - 1.0) * 150.0 + axis.orthogonal() * sin(along * TAU) * 8.0
			var width := maxf(0.4, sin(along * PI) * 3.5 * fade)
			draw_line(previous, next, Color(color, fade * 0.12), width * 3.0, true)
			draw_line(previous, next, Color("f4e7ff", fade * 0.9), width, true)
			previous = next
	elif source.begins_with("spirit"):
		var axis := (point - origin).normalized()
		var length := 24.0 + progress * 35.0
		draw_line(point - axis * length, point + axis * length, Color("ecdcff", pow(1.0 - progress, 2) * 0.75), 1.2, true)


func _player_uv() -> Vector2:
	return session.player_position


func _effect_color(source: StringName) -> Color:
	var source_name := str(source)
	if source_name.begins_with("flame"):
		return Color("ff9a6b")
	if source_name.begins_with("storm"):
		return Color("ffe7ac")
	if source_name.begins_with("spirit"):
		return Color("d8b9f4")
	if source_name == "counter":
		return Color("f4e1ae")
	return Color("9cdeff")


func _spawn_particles(at: Vector2, tint: Color, intensity: float, burst: bool, source: StringName = &"", direction: Vector2 = Vector2.ZERO) -> void:
	if reduced_motion or quality == 0:
		return
	var particles := GPUParticles2D.new()
	particles.name = "SpellMotes"
	particles.position = at * size
	particles.amount = (46 if quality == 2 else 23) if burst else (22 if quality == 2 else 11)
	particles.lifetime = 0.7 * intensity + 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.texture = _spark_texture
	particles.modulate = tint
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = blend
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 5.0
	motion.spread = 65.0 if not direction.is_zero_approx() else 180.0
	if not direction.is_zero_approx():
		motion.direction = Vector3(direction.x, direction.y, 0.0)
	motion.initial_velocity_min = 18.0 if not burst else 48.0
	motion.initial_velocity_max = 65.0 if not burst else 145.0
	motion.gravity = Vector3.ZERO
	if str(source).begins_with("flame"):
		motion.gravity = Vector3(0, -70, 0)
		motion.initial_velocity_max = 95.0
	elif str(source).begins_with("frost") or str(source).begins_with("spirit"):
		particles.amount = (12 if quality == 2 else 6) if str(source).begins_with("spirit") else (20 if quality == 2 else 10)
		particles.lifetime = 0.55
		var shard := GradientTexture2D.new()
		shard.width = 12
		shard.height = 12
		shard.gradient = Gradient.new()
		particles.texture = shard
		var fragment_material := ShaderMaterial.new()
		fragment_material.shader = preload("res://ui/materials/battle_fragment.gdshader")
		fragment_material.set_shader_parameter("paper", str(source).begins_with("spirit"))
		particles.material = fragment_material
		motion.gravity = Vector3(0, 42 if str(source).begins_with("frost") else -12, 0)
		motion.angular_velocity_min = -150
		motion.angular_velocity_max = 150
	motion.damping_min = 12.0
	motion.damping_max = 26.0
	motion.scale_min = 0.025 if particles.texture == _spark_texture else 0.3
	motion.scale_max = 0.06 if particles.texture == _spark_texture else 0.7
	var fade := Gradient.new()
	fade.set_color(0, Color(1.4, 1.3, 1.1, 0.8))
	fade.set_color(1, Color(0.6, 0.6, 0.6, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	motion.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = shrink
	motion.scale_curve = scale_curve
	particles.process_material = motion
	add_child(particles)
	fluid.bind_particles(particles, 1.6)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


func _spawn_flame_burst(at: Vector2, radius: float) -> void:
	var sprite := Sprite2D.new()
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.texture = _spark_texture
	sprite.position = at * size
	sprite.scale = Vector2.ONE * radius * 2.0 * size.y / BattleSession.ARENA_SIZE.y / _spark_texture.width
	var burst_material := ShaderMaterial.new()
	burst_material.shader = preload("res://ui/materials/flame_burst.gdshader")
	sprite.material = burst_material
	add_child(sprite)
	_pulses.append({"kind": &"fire", "node": sprite, "at": at, "age": 0.0, "duration": 0.6})
	_add_wave(at, 0.6, 0.004, radius / BattleSession.ARENA_SIZE.y)


func _add_wave(at: Vector2, duration: float, power: float, radius: float = 0.12) -> void:
	if reduced_motion or quality == 0:
		return
	_waves.append({"at": at, "age": 0.0, "duration": duration, "power": power, "radius": radius})
	if _waves.size() > 4:
		_waves.pop_front()


func _update_waves() -> void:
	var encoded := PackedVector4Array()
	var canvas_size: Vector2 = get_parent().size
	var origin := position / canvas_size
	var span := size * scale / canvas_size
	for wave in _waves:
		var progress: float = wave.age / wave.duration
		var front := lerpf(0.05, 0.82, smoothstep(0.0, 0.7, progress))
		if wave.power < 0.0:
			front = 0.87 - front
		var center: Vector2 = origin + wave.at * span
		encoded.append(Vector4(center.x, center.y, front * wave.radius * span.y, wave.power * (1.0 - progress)))
	while encoded.size() < 4:
		encoded.append(Vector4.ZERO)
	_wave_plane.visible = not _waves.is_empty()
	_wave_material.set_shader_parameter("waves", encoded)
	_wave_material.set_shader_parameter("aspect", canvas_size.x / canvas_size.y)
