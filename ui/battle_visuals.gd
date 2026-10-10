class_name BattleVisuals
extends Control
## World geometry and Godot particles consume committed battle events only.

const ENEMY_COLORS := {
	&"nib": Color("8cc4b8"), &"quill": Color("dcb887"), &"guard": Color("a6bcd9"),
	&"wisp": Color("9ec7e6"), &"ram": Color("c49a85"), &"ink-colossus": Color("ba91c9"),
	&"binder": Color("a7c7ad"), &"brood": Color("b3a0bf"), &"leech": Color("9fc3aa"),
	&"mirror": Color("c0cce2"), &"mortar": Color("c7aa8a"), &"priest": Color("a4cbbb"),
	&"reaper": Color("b7a8b6"), &"scribe": Color("d1b298"), &"sentinel": Color("b5c0ca"),
	&"split": Color("c4c1a4"), &"tower": Color("c5afe0"), &"vortex": Color("b2a7d6"),
	&"echo-archivist": Color("b4c9eb"), &"final-editor": Color("d8adab")
}

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
var _perfect_dodge_until := 0.0
var camera_offset := Vector2.ZERO
var _camera_motion := DampedMotion.new()
var fluid: FluidAtmosphere
var fluid_quality: int = 2
var fluid_material: FluidMedium
var fluid_effects: Dictionary[StringName, FluidEffectProfile] = {}
var rule_visuals: BattleRuleVisuals


func configure(battle: BattleSession, tint: Color, visual_quality: int, less_motion: bool) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	for pulse in _pulses:
		if pulse.kind not in [&"item_burst", &"clear_pulse"]:
			continue
		var sprite: Sprite2D = pulse.node
		(sprite.material as ShaderMaterial).set_shader_parameter("reduced_motion", less_motion or (detail == 0 and pulse.kind == &"item_burst"))
		(sprite.material as ShaderMaterial).set_shader_parameter("detail", detail)
		if less_motion or detail == 0:
			for child in sprite.get_children():
				if child is GPUParticles2D or child is PointLight2D:
					child.queue_free()
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
	var clock := BattleVisualClock.new()
	clock.session = session
	add_child(clock)
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
	_player.z_index = 2
	add_child(_player)
	for enemy in session.enemies:
		_create_actor(enemy)


func _create_actor(enemy: BattleEnemy) -> void:
	var tint: Color = ENEMY_COLORS[enemy.kind]
	var actor := BattleActorVisual.create(enemy.kind, tint, _spark_texture)
	actor.name = str(enemy.id)
	actor.z_index = 2
	add_child(actor)
	_actors[enemy.id] = actor


func _process(delta: float) -> void:
	var started := DebugLog.begin()
	delta = session.world_delta(delta)
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
	_player.sync_player(session.previous_player_position.lerp(session.player_position, fraction) * size, session.world_time, _recoil, session.hurt_window, delta, reduced_motion)
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
		_actors[enemy.id].sync_enemy(enemy, enemy.previous_position.lerp(enemy.position, fraction) * size, session.world_time, delta, reduced_motion, quality)
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
			var sprite: Node2D = _pulses[index]["node"]
			if _pulses[index].get("guard", false):
				_pulses[index].at = _player_uv()
			sprite.position = _pulses[index].at * size
			var progress := minf(1.0, _pulses[index].age / _pulses[index].duration)
			if sprite is LightningArc:
				sprite.advance(progress)
			else:
				(sprite.material as ShaderMaterial).set_shader_parameter("progress", progress)
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
	DebugLog.end(&"battle.visuals", started)


func present(event: Dictionary) -> void:
	var started := DebugLog.begin()
	_present(event)
	DebugLog.operation(&"battle.present", started, {"kind": event.kind})


func _present(event: Dictionary) -> void:
	fluid.present(event)
	var kind: StringName = event.kind
	var at: Vector2 = event.get("at", Vector2(0.5, 0.5))
	match kind:
		&"clear_pulse":
			if event.source != &"ultimate": _spawn_clear_pulse(at, event.radius, event.source)
		&"perfect_dodge":
			_perfect_dodge_until = session.elapsed + event.until
		&"pickup_spawn":
			_spawn_particles(at, Color("a7e4c5") if event.pickup == &"rune" else Color("e8b988"), 0.3, false)
		&"storm_path":
			_spawn_spell_link(event.from, at, true, false)
		&"field":
			if event.source == &"overload": _spawn_electric_burst(at, event.radius)
		&"pickup_trigger":
			var rune: bool = event.pickup == &"rune"
			_spawn_item_burst(at, 1 if rune else 2, 520.0 if rune else 255.0)
		&"cast":
			if not reduced_motion:
				_recoil = ((at - event.target) * size).normalized() * 7.0
			_spawn_energy(at, 60.0 if event.empowered else 35.0, school_color, event.book == &"flame", &"cast", 0.28)
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
				_spawn_flame_burst(contact, (180.0 if empowered else 150.0) if event.source in [&"flame_burst", &"flame_ultimate"] else 85.0, event.source not in [&"flame_ultimate", &"flame_wave", &"flame_domain"])
			elif str(event.source).begins_with("frost"):
				_spawn_frost_impact(contact, direction, empowered, event.source != &"frost_ultimate")
			elif event.source == &"storm_burst":
				_spawn_energy(contact, 25.0, Color("ffe7ac"), false, &"contact", .2)
			elif str(event.source).begins_with("storm") or str(event.source).begins_with("spirit"):
				_spawn_spell_link(event["from"], contact, str(event.source).begins_with("storm"), empowered)
			else:
				_spawn_energy(contact, 56.0, color, false, &"contact", 0.4)
			_spawn_particles(contact, color, 0.7, true, event.source, Vector2.ZERO if str(event.source).ends_with("_ultimate") else direction)
			if event.source == &"counter":
				_add_wave(contact, 0.46, 0.0035)
		&"death":
			_spawn_particles(at, Color("e8d6ae"), 0.9, true)
			_add_wave(at, 0.72, -0.004, 0.075)
		&"parry_start":
			_spawn_energy(at, 44.0, Color("b9d6ce"), false, &"guard", .18)
		&"counter_pulse":
			if event.get("grade", &"success") == &"perfect":
				_spawn_item_burst(at, 0, 195.0)
			else:
				_spawn_item_burst(at, 3, 125.0)
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
		&"spirit_summon":
			_spawn_particles(at, Color("d9c8ff"), 0.5, false)
		&"dodge":
			if not reduced_motion:
				_echo_clock = 0.0
				_spawn_particles(at, school_color, 0.35, true)
		&"dodge_end":
			if not reduced_motion:
				_spawn_particles(at, school_color, 0.2, false)
	queue_redraw()


func _draw() -> void:
	if session == null:
		return
	var started := DebugLog.begin()
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
	for enemy in session.enemies:
		var point := enemy.previous_position.lerp(enemy.position, Engine.get_physics_interpolation_fraction()) * size
		if enemy.alive():
			_draw_enemy(point, enemy)
			if session.typing.target_id == enemy.id and BattleSession.enemy_in_combat(enemy):
				var from := session.player_position * size
				_draw_lock(from, point, enemy.radius + 21.0)
	var player := session.previous_player_position.lerp(session.player_position, Engine.get_physics_interpolation_fraction()) * size
	_draw_player(player)
	_player.aura.modulate.a = 0.22 if session.dodge_window > 0.0 else 0.12
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
	DebugLog.end(&"battle.draw_commands", started)


func _draw_edge_seal(center: Vector2, radius: float, phase: float) -> void:
	draw_set_transform(center, phase)
	draw_texture_rect(ArcanaRunes.seal(session.book_id, radius * 2.0), Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color("b6ad87", .052))
	draw_set_transform(Vector2.ZERO)


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


func _spawn_item_burst(at: Vector2, style: int, radius: float) -> void:
	# Gold parry, jade countermeasure, amber ink. One short optical beat and
	# independent ballistic particles; no dye, pressure source or volume marcher.
	var tint: Color = [Color("ffe3a2"), Color("a9e8cd"), Color("ffad55"), Color("c4e9db")][style]
	var duration: float = [.46, .58, .64, .32][style]
	var sprite := Sprite2D.new()
	# Actors occupy the next canvas layer, keeping their silhouettes readable.
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.texture = _spark_texture
	sprite.position = at * size
	sprite.scale = Vector2.ONE * radius * 2.4 / _spark_texture.width
	var pulse_material := preload("res://ui/materials/item_burst.tres").duplicate() as ShaderMaterial
	pulse_material.set_shader_parameter("reduced_motion", reduced_motion or quality == 0)
	pulse_material.set_shader_parameter("tint", tint)
	pulse_material.set_shader_parameter("style", style)
	pulse_material.set_shader_parameter("radius", radius)
	pulse_material.set_shader_parameter("seed", randf() * 100.0)
	sprite.material = pulse_material
	add_child(sprite)
	_pulses.append({"kind": &"item_burst", "node": sprite, "at": at, "age": 0.0, "duration": duration})
	_add_contact_light(sprite, tint, minf(radius * 1.5, 350.0), duration * .6, [3.2, 1.25, 1.8, 1.5][style])
	if reduced_motion or quality == 0:
		return
	for layer in 2:
		var sparks := layer == 1
		var particles := preload("res://ui/scenes/burst_splinters.tscn").instantiate() as GPUParticles2D
		particles.name = "Sparks" if sparks else "CrystalSplinters"
		# Inverse parent scale keeps the particle sizes and speed in world pixels.
		particles.scale = Vector2.ONE / sprite.scale.x
		particles.amount = (52 if sparks else 22) if quality == 2 else (28 if sparks else 12)
		if style == 3:
			particles.amount = int(particles.amount * .55)
		particles.lifetime = duration * .88
		particles.texture = _spark_texture
		particles.visibility_rect = Rect2(-Vector2.ONE * radius * 1.3, Vector2.ONE * radius * 2.6)
		var surface := particles.material as ShaderMaterial
		surface.set_shader_parameter("spark", sparks)
		surface.set_shader_parameter("tint", tint if not sparks else tint.lerp(Color("ffe8b7"), .55))
		var motion := particles.process_material as ParticleProcessMaterial
		motion.emission_sphere_radius = radius * .045
		motion.initial_velocity_min = radius / duration * .9
		motion.initial_velocity_max = radius / duration * 2.3
		motion.damping_min = radius / (duration * duration) * 1.6
		motion.damping_max = radius / (duration * duration) * 2.4
		motion.scale_min = (5.0 if sparks else 16.0) / _spark_texture.width
		motion.scale_max = (12.0 if sparks else 32.0) / _spark_texture.width
		sprite.add_child(particles)
		particles.emitting = true


func _spawn_clear_pulse(at: Vector2, radius: float, source: StringName) -> void:
	var tint := Color("c6ddd7")
	if source == &"R029": tint = Color("efdbb3")
	elif source == &"R020": tint = Color("e6c493")
	elif source == &"dodge_clear": tint = school_color.lerp(Color("e2ede5"), 0.4)
	elif source == &"overload": tint = Color("f6d998")
	var sprite := Sprite2D.new()
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.texture = _spark_texture
	sprite.position = at * size
	sprite.scale = Vector2.ONE * radius * 2.4 / _spark_texture.width
	var surface := preload("res://ui/materials/item_burst.tres").duplicate() as ShaderMaterial
	surface.set_shader_parameter("style", 5 if source == &"R020" else 4)
	surface.set_shader_parameter("radius", radius)
	surface.set_shader_parameter("tint", tint)
	surface.set_shader_parameter("reduced_motion", reduced_motion)
	surface.set_shader_parameter("detail", quality)
	surface.set_shader_parameter("seed", randf() * 100.0)
	sprite.material = surface
	add_child(sprite)
	_pulses.append({"kind": &"clear_pulse", "node": sprite, "at": at, "age": 0.0, "duration": 0.64})
	# The existing refraction plane carries the energy; the material only exposes
	# a few lit folds. Both use the same front curve and finish at the real radius.
	_add_wave(at, .64, .0022, radius / BattleSession.ARENA_SIZE.y / .82)
	_add_contact_light(sprite, tint, minf(radius, 220.0), .2, .12)


func _spawn_energy(at: Vector2, radius: float, tint: Color, hot: bool, kind: StringName, duration: float) -> void:
	var sprite := Sprite2D.new()
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.texture = _spark_texture
	sprite.position = at * size
	sprite.scale = Vector2.ONE * radius * 2.3 / _spark_texture.width
	var shader := preload("res://ui/materials/energy_burst.tres").duplicate() as ShaderMaterial
	shader.set_shader_parameter("variation", fposmod(session.elapsed * 0.37 + at.x * 5.1, 1.0))
	shader.set_shader_parameter("tint", tint)
	shader.set_shader_parameter("hot", hot)
	shader.set_shader_parameter("reduced_motion", reduced_motion)
	sprite.material = shader
	add_child(sprite)
	_pulses.append({"kind": kind, "node": sprite, "at": at, "age": 0.0, "duration": duration})
	_add_contact_light(sprite, tint, radius * 1.8, duration * 0.7)


func _add_contact_light(parent: Node2D, tint: Color, radius: float, duration: float, energy: float = .22) -> void:
	if quality != 2 or reduced_motion:
		return
	var light := preload("res://ui/scenes/contact_light.tscn").instantiate() as PointLight2D
	light.color = tint
	light.texture_scale = radius * 2.0 / light.texture.get_width() / parent.scale.x
	light.energy = energy
	parent.add_child(light)
	BattleVisualClock.tween_for(self).tween_property(light, "energy", 0.0, duration)


func _spawn_electric_burst(at: Vector2, radius: float) -> void:
	var arc := LightningArc.new()
	arc.burst_radius = radius
	arc.reduced = reduced_motion or quality == 0
	arc.random_seed = hash(Vector3(at.x, at.y, session.world_time))
	arc.position = at * size
	add_child(arc)
	_pulses.append({"kind": &"link", "node": arc, "at": at, "age": 0.0, "duration": .24})
	_spawn_energy(at, 42.0, Color("ffe7ac"), false, &"contact", .24)


func _spawn_spell_link(from: Vector2, at: Vector2, electric: bool, empowered: bool) -> void:
	var axis := (at - from) * size
	if electric:
		var arc := LightningArc.new()
		arc.reach = maxf(30.0, axis.length())
		arc.reduced = reduced_motion
		arc.random_seed = hash(Vector3(from.x, at.y, session.elapsed))
		arc.position = (from + at) * .5 * size
		arc.rotation = axis.angle()
		add_child(arc)
		if not reduced_motion:
			var flash := FluidEffectProfile.new()
			flash.duration = .24
			flash.fade_out = 0.0
			flash.along_path = true
			flash.light_color = Color("ffd785")
			flash.light_energy = 2.4
			flash.light_radius = 190.0
			arc.illumination = fluid.emit_effect(flash, from * size)
			arc.illumination.end_offset = axis
		_pulses.append({"kind": &"link", "node": arc, "at": (from + at) * .5, "age": 0.0, "duration": .24})
		_spawn_energy(at, 45.0 if empowered else 30.0, Color("ffe7ac"), false, &"contact", .2)
		return
	var sprite := Sprite2D.new()
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.texture = _spark_texture
	var length := maxf(60.0, axis.length()) if electric else (240.0 if empowered else 95.0)
	var breadth := 150.0 if electric else 85.0
	var center := (from + at) * 0.5 if electric else at
	sprite.position = center * size
	sprite.rotation = axis.angle()
	sprite.scale = Vector2(length + 64.0, breadth) / _spark_texture.width
	var shader := preload("res://ui/materials/spell_link.tres").duplicate() as ShaderMaterial
	shader.set_shader_parameter("extent", Vector2(length + 64.0, breadth))
	shader.set_shader_parameter("electric", electric)
	shader.set_shader_parameter("seed", session.elapsed)
	shader.set_shader_parameter("reduced_motion", reduced_motion)
	sprite.material = shader
	add_child(sprite)
	_pulses.append({"kind": &"link", "node": sprite, "at": center, "age": 0.0, "duration": 0.48 if electric else 0.38})
	_spawn_energy(at, 58.0 if empowered else 38.0, Color("bcc9ff") if electric else Color("d9baf5"), false, &"contact", 0.38)


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
	var particles := preload("res://ui/scenes/spell_motes.tscn").instantiate() as GPUParticles2D
	particles.position = at * size
	particles.amount = (46 if quality == 2 else 23) if burst else (22 if quality == 2 else 11)
	particles.lifetime = 0.7 * intensity + 0.3
	particles.texture = _spark_texture
	particles.modulate = tint
	var motion := particles.process_material as ParticleProcessMaterial
	motion.spread = 65.0 if not direction.is_zero_approx() else 180.0
	if not direction.is_zero_approx():
		motion.direction = Vector3(direction.x, direction.y, 0.0)
	motion.initial_velocity_min = 18.0 if not burst else 48.0
	motion.initial_velocity_max = 65.0 if not burst else 145.0
	if str(source).begins_with("flame"):
		particles.amount = 24 if quality == 2 else 12
		particles.lifetime = .42
		motion.initial_velocity_min = 85.0
		motion.initial_velocity_max = 220.0
	elif str(source).begins_with("frost") or str(source).begins_with("spirit"):
		particles.amount = (12 if quality == 2 else 6) if str(source).begins_with("spirit") else (20 if quality == 2 else 10)
		particles.lifetime = 0.55
		particles.texture = preload("res://ui/effects/battle_shard.tres")
		var fragment_material := preload("res://ui/materials/battle_fragment.tres").duplicate() as ShaderMaterial
		fragment_material.set_shader_parameter("paper", str(source).begins_with("spirit"))
		particles.material = fragment_material
		motion.angular_velocity_min = -150
		motion.angular_velocity_max = 150
	motion.scale_min = 0.025 if particles.texture == _spark_texture else 0.3
	motion.scale_max = 0.06 if particles.texture == _spark_texture else 0.7
	add_child(particles)
	fluid.bind_particles(particles, 1.6)
	particles.emitting = true
	# GPU one-shot completion notification does not track changing speed_scale.
	var retirement := BattleVisualClock.tween_for(particles)
	retirement.tween_interval(particles.lifetime + .3)
	retirement.tween_callback(particles.queue_free)


func _spawn_flame_burst(at: Vector2, radius: float, refract: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.texture = _spark_texture
	sprite.position = at * size
	sprite.scale = Vector2.ONE * radius * 2.0 * size.y / BattleSession.ARENA_SIZE.y / _spark_texture.width
	var burst_material := preload("res://ui/materials/flame_burst.tres").duplicate() as ShaderMaterial
	burst_material.set_shader_parameter("seed", randf() * 100.0)
	burst_material.set_shader_parameter("reduced_motion", reduced_motion)
	sprite.material = burst_material
	add_child(sprite)
	_add_contact_light(sprite, Color("ffb65f"), radius * 2.0, .2, .8)
	_pulses.append({"kind": &"fire", "node": sprite, "at": at, "age": 0.0, "duration": .42})
	if refract: _add_wave(at, .35, 0.002, radius / BattleSession.ARENA_SIZE.y)


func _spawn_frost_impact(at: Vector2, direction: Vector2, empowered: bool, refract: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.texture = _spark_texture
	sprite.position = at * size
	sprite.scale = Vector2.ONE * (3.2 if empowered else 2.2)
	var ice := preload("res://ui/materials/frost_impact.tres").duplicate() as ShaderMaterial
	ice.set_shader_parameter("ice_grain", preload("res://assets/art/effects/frost_microfacets.png"))
	ice.set_shader_parameter("axis", direction)
	ice.set_shader_parameter("seed", session.elapsed)
	ice.set_shader_parameter("reduced_motion", reduced_motion)
	sprite.material = ice
	add_child(sprite)
	_pulses.append({"kind": &"frost", "node": sprite, "at": at, "age": 0.0, "duration": 0.7})
	var light := preload("res://ui/scenes/frost_impact_light.tscn").instantiate() as PointLight2D
	light.visible = quality == 2 and not reduced_motion
	sprite.add_child(light)
	var tween := BattleVisualClock.tween_for(self)
	tween.tween_property(light, "energy", 0.0, 0.45)
	if refract: _add_wave(at, 0.3, 0.0018, 0.055)


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
