class_name FluidAtmosphere
extends FluidField2D
## Scene motion, GPU particles and native lights share one local velocity field.

var battle: BattleSession
var trail_material: FluidMedium
var effects: Dictionary[StringName, FluidEffectProfile] = {}
const BURST: FluidEffectProfile = preload("res://ui/effects/presets/burst.tres")
const GUST: FluidEffectProfile = preload("res://ui/effects/presets/gust.tres")
const DODGE: FluidEffectProfile = preload("res://ui/effects/presets/dodge.tres")
var _dodge_trail: FluidEmitter2D
var _motion: Dictionary[StringName, Dictionary] = {}
var _ambient: Array[FluidInfluence] = []
var tracked_count := 0


func _ready() -> void:
	opacity = 0.11
	wind = Vector2(2, -2)
	density_decay = 0.95
	heat_decay = 1.2
	velocity_decay = .7
	vorticity = 1.0
	turbulence = .55
	turbulence_force = 42.0
	turbulence_detail = .4
	turbulence_scale = 360.0
	settling = 3.0
	buoyancy = 65.0
	center_clear = 0.0 if battle == null else 0.25
	scattering = 1.6
	if battle == null:
		opacity = .16
		edge_fade = 0.0
		wind = Vector2(4, 1)
		density_decay = .18
		heat_decay = .5
		velocity_decay = .22
		settling = 5.0
		turbulence = .55
		turbulence_force = 18.0
		for i in 4:
			_ambient.append(FluidInfluence.new())
		_ambient[0].shape = FluidInfluence.Shape.BOX
		_ambient[0].density = .11
		_ambient[0].noise_amount = 1.0
		_ambient[0].initial_age = 2.0
	else:
		var source := FluidInfluence.new()
		source.shape = FluidInfluence.Shape.BOX
		source.density = .0875
		source.noise_amount = 1.0
		source.initial_age = 2.0
		_ambient.append(source)
	super._ready()


func _process(delta: float) -> void:
	if battle != null and active:
		_sync_battle_motion()
	if not active or reduced_motion or quality == Quality.OFF or not is_visible_in_tree():
		for motion in _motion.values():
			motion.previous = motion.point
			motion.previous_angle = motion.angle
			(motion.path as FluidMotionPath).reset(motion.point)
	super._process(delta)


func track_body(id: StringName, point: Vector2, extent: Vector2, angle: float, tint: Color, glow: float = .4, solid: bool = true, gain: float = 18.0, presence: float = 1.0, body_shape: FluidInfluence.BodyShape = FluidInfluence.BodyShape.BLUNT) -> void:
	## Points and extents are in field-local coordinates, not normalized screen UVs.
	if extent.x <= 0 or extent.y <= 0:
		push_error("Fluid motion requires positive extent")
		return
	if presence < .02:
		untrack(id)
		return
	if not _motion.has(id):
		_motion[id] = {"previous": point, "previous_angle": angle, "flow_angle": angle, "path": FluidMotionPath.new(), "wakes": [], "plumes": []}
	var motion := _motion[id]
	(motion.path as FluidMotionPath).append(point)
	motion.merge({"point": point, "extent": extent, "angle": angle, "color": tint, "glow": glow * presence, "solid": solid, "gain": gain * presence, "body_shape": body_shape}, true)


func untrack(id: StringName) -> void:
	_motion.erase(id)


func _sync_battle_motion() -> void:
	var seen: Array[StringName] = [&"player"]
	var fraction := Engine.get_physics_interpolation_fraction()
	var tint := light_color
	track_body(&"player", battle.previous_player_position.lerp(battle.player_position, fraction) * size, Vector2.ONE * 24, 0, tint, .25)
	if is_instance_valid(_dodge_trail):
		_dodge_trail.position = _motion[&"player"].point
	for enemy in battle.enemies:
		if enemy.alive():
			seen.append(enemy.id)
			track_body(enemy.id, enemy.previous_position.lerp(enemy.position, fraction) * size, Vector2.ONE * enemy.radius, 0, Color("a6bcd9"), 0)
	for projectile in battle.projectiles:
		var id := StringName("projectile_%d" % projectile.get_instance_id())
		seen.append(id)
		track_body(id, projectile.previous_position.lerp(projectile.position, fraction) * size, Vector2.ONE * projectile.radius, 0, tint, .8, false, 18.0, 1.0, FluidInfluence.BodyShape.POINTED)
	for spirit in battle.spirits:
		var id := StringName("spirit_%d" % spirit.get_instance_id())
		seen.append(id)
		track_body(id, spirit.previous_position.lerp(spirit.position, fraction) * size, Vector2.ONE * 18, 0, tint, .4, false)
	for threat in battle.threats:
		var id := StringName("threat_%d" % threat.get_instance_id())
		seen.append(id)
		track_body(id, threat.previous_position.lerp(threat.position, fraction) * size, Vector2.ONE * 14, 0, Color("c5ffc9") if threat.reflected else Color("ffb197"), .25, false, 5.0, 1.0, FluidInfluence.BodyShape.POINTED)
	for id in _motion.keys():
		if id not in seen:
			_motion.erase(id)


func _before_step(delta: float) -> void:
	# Keep render/input turns, then sweep every retained segment on the solver tick.
	var ordered: Array = _motion.values()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.glow > b.glow)
	tracked_count = ordered.size()
	for motion: Dictionary in ordered:
		var point: Vector2 = motion.point
		var extent: Vector2 = motion.extent
		var path := motion.path as FluidMotionPath
		var distance := path.length()
		var speed := distance / delta
		var angular := angle_difference(motion.previous_angle, motion.angle) / delta
		var radius := maxf(extent.x, extent.y)
		for i in maxi(1, path.points.size() - 1):
			while motion.wakes.size() <= i:
				motion.wakes.append(FluidInfluence.new())
				motion.plumes.append(FluidInfluence.new())
			var start := path.points[i]
			var end := path.points[mini(i + 1, path.points.size() - 1)]
			var segment := end - start
			var velocity := segment.normalized() * speed
			var wake := motion.wakes[i] as FluidInfluence
			FluidMotionPath.sweep(wake, start, end, radius * 3.2)
			if segment.length_squared() > 0.0:
				motion.flow_angle = segment.angle()
			wake.rotation = motion.flow_angle
			wake.displacement_radius = radius
			wake.body_shape = motion.body_shape
			wake.velocity = velocity
			wake.coupling = motion.gain * FluidMotionPath.exposure(segment.length(), distance, radius)
			wake.spin = clampf(angular, -4, 4)
			if motion.solid or speed > 1.0 or absf(angular) > .01:
				_scene_sources.append(wake)
			if battle != null and not motion.solid and speed > 12.0:
				var width := clampf(maxf(extent.x, extent.y) * .8, 18, 80)
				var plume := motion.plumes[i] as FluidInfluence
				var rear_length := radius * (wake.body_aspect if wake.body_shape == FluidInfluence.BodyShape.POINTED else 1.0)
				var release_offset := segment.normalized() * (rear_length * 2.0 + width * .5)
				FluidMotionPath.sweep(plume, start - release_offset, end - release_offset, width)
				var exposure := FluidMotionPath.exposure(segment.length(), distance, width)
				plume.velocity = velocity * .08
				plume.coupling = 3.0 * exposure
				plume.density = minf(speed / width * .65, 32.0) * exposure
				plume.medium = trail_material
				plume.color = motion.color
				_scene_sources.append(plume)
		path.reset(point)
		motion.previous = point
		motion.previous_angle = motion.angle
	if battle == null:
		# Room mist exists independently of interactions; books only move its air.
		_ambient[0].center = size * Vector2(.5, 1.04)
		_ambient[0].extent = size * Vector2(.95, .46)
		_ambient[0].noise_scale = size.y * .62
		turbulence_scale = size.y * .58
		for i in range(1, _ambient.size()):
			var phase := _clock * .09 + float(i) * 2.1
			var anchor: Vector2 = [Vector2(.22, .30), Vector2(.70, .60), Vector2(.45, .85)][i - 1]
			_ambient[i].center = size * (anchor + Vector2(sin(phase), cos(phase * .83)) * .06)
			_ambient[i].extent = size * Vector2(.4, .45)
			_ambient[i].spin = (.025 + sin(phase) * .012) * (-1.0 if i % 2 == 0 else 1.0)
		_scene_sources.append_array(_ambient)
		return
	_ambient[0].center = size * Vector2(.5, .88)
	_ambient[0].extent = size * Vector2(.95, .9)
	_ambient[0].noise_scale = size.y * .72
	_scene_sources.append(_ambient[0])


func _scene_light_inputs() -> Array[Dictionary]:
	var emitters: Array[Dictionary] = []
	if active:
		for motion in _motion.values():
			if motion.glow > 0:
				emitters.append({"point": motion.point, "color": motion.color, "energy": motion.glow, "radius": maxf(motion.extent.x, motion.extent.y) * 3.0 + 80.0})
	return emitters


func present(event: Dictionary) -> void:
	if reduced_motion or not active:
		return
	var kind: StringName = event.kind
	if kind not in [&"cast", &"impact", &"counter_pulse", &"parry_start", &"dodge", &"dodge_end", &"ultimate", &"spirit_summon", &"death", &"enemy_shot"]:
		return
	if kind == &"dodge_end" and not effects.has(kind):
		return # The moving trail continues advecting; stopping is not an explosion.
	var point := (event.get("contact", event.get("center", event.get("at", Vector2(.5, .5)))) as Vector2) * size
	var directional := kind in [&"cast", &"dodge", &"enemy_shot"]
	var template: FluidEffectProfile = effects.get(kind, DODGE if kind == &"dodge" else (GUST if directional else BURST))
	var profile := template.duplicate(true) as FluidEffectProfile
	if not effects.has(kind):
		profile.light_color = light_color
	var direction: Vector2 = event.get("direction", Vector2.UP)
	if event.has("target"):
		direction = ((event.target as Vector2) * size - point).normalized()
	for influence in profile.influences:
		if trail_material != null and influence.density > 0:
			influence.medium = trail_material
	var emitter := emit_effect(profile, point, direction.angle())
	if kind == &"dodge":
		_dodge_trail = emitter
	if profile.along_path and event.has("from"):
		emitter.end_offset = ((event["from"] as Vector2) * size - point).rotated(-direction.angle())
	if kind in [&"ultimate", &"counter_pulse"]:
		emitter.scale = Vector2.ONE * 2.2
