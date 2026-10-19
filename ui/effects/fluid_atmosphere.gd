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
class Motion extends RefCounted:
	var previous: Vector2
	var previous_angle: float
	var flow_angle: float
	var path := FluidMotionPath.new()
	var wakes: Array[FluidInfluence] = []
	var plumes: Array[FluidInfluence] = []
	var point: Vector2
	var extent: Vector2
	var angle: float
	var color: Color
	var glow: float
	var solid: bool
	var gain: float
	var body_shape: FluidInfluence.BodyShape
	var light := {"point": Vector2.ZERO, "color": Color.WHITE, "energy": 0.0, "radius": 0.0}

var _motion: Dictionary[StringName, Motion] = {}
var _ordered_motion: Array[Motion] = []
var _motion_order_dirty := true
var _ambient: Array[FluidInfluence] = []
var _spell_smoke: Dictionary[RefCounted, FluidEmitter2D] = {}
var _shockwaves: Array[Dictionary] = []
var _gravity_sources: Dictionary[RefCounted, FluidInfluence] = {}
var tracked_count := 0
var combustion: Combustion
var _fire_surface: ColorRect
var _fire_capture: BackBufferCopy
var _fire_bursts: Array[Dictionary] = []
var _fire_tail := 0.0
var _paths_active := true


func _ready() -> void:
	if battle != null:
		combustion = Combustion.new()
		add_child(combustion)
	opacity = 0.11
	wind = Vector2.ZERO
	density_decay = 0.95
	heat_decay = 1.2
	velocity_decay = .7
	vorticity = 1.0
	turbulence = .55
	turbulence_force = 42.0
	turbulence_detail = .4
	turbulence_scale = 360.0
	settling = 0.0
	buoyancy = 0.0
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
		buoyancy = 65.0
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
	if battle != null:
		_fire_capture = BackBufferCopy.new()
		_fire_capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
		add_child(_fire_capture)
		_fire_surface = ColorRect.new()
		_fire_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fire := preload("res://ui/materials/combustion.tres").duplicate() as ShaderMaterial
		fire.set_shader_parameter("combustion",combustion.texture)
		_fire_surface.material = fire
		_fire_surface.hide()
		add_child(_fire_surface)
		_fire_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var started := DebugLog.begin()
	if battle != null: delta = battle.world_delta(delta)
	if reduced_motion or quality == Quality.OFF:
		_shockwaves.clear()
	if battle != null and active:
		_sync_battle_motion()
		if battle.runtime != null:
			_sync_spell_smoke()
	var paths_active := active and not reduced_motion and quality != Quality.OFF and is_visible_in_tree()
	if paths_active != _paths_active:
		for motion in _motion.values():
			motion.previous = motion.point
			motion.previous_angle = motion.angle
			motion.path.reset(motion.point)
		_paths_active = paths_active
	super._process(delta)
	if combustion != null:
		_step_combustion(minf(delta,.05))
	DebugLog.end(&"atmosphere.prepare_submit", started)


func _before_reconfigure() -> void:
	# Uniform sets must release the old velocity RID before the solver replaces it.
	if combustion != null:
		RenderingServer.call_on_render_thread(combustion.unbind_flow)
		_fire_tail = 0.0
		_fire_bursts.clear()


func _after_reconfigure() -> void:
	_configure_combustion(false)


func _configure_combustion(preserve_fire: bool) -> void:
	if combustion != null:
		if quality != Quality.OFF:
			var fire_grid := Vector2i((size / maxf(size.x, size.y) * VisualQuality.FIRE_LONG_EDGE[scene_quality]).ceil()).max(Vector2i(8, 8))
			RenderingServer.call_on_render_thread(combustion.configure.bind(field_texture(), fire_grid, preserve_fire))
		else:
			RenderingServer.call_on_render_thread(combustion.deactivate)


func set_scene_quality(detail: int) -> void:
	if scene_quality == detail: return
	scene_quality = detail
	if is_node_ready(): _configure_combustion(true)


func set_options(detail: int, less_motion: bool) -> void:
	var changed_motion := reduced_motion != less_motion
	super.set_options(detail,less_motion)
	if changed_motion and is_node_ready():
		reset_field()


func _step_combustion(delta: float) -> void:
	var enabled := active and not reduced_motion and quality != Quality.OFF and is_visible_in_tree()
	var fuel := PackedFloat32Array()
	if enabled:
		for state in _spell_smoke:
			var fire: bool = state is SpellField and state.effect.kind == &"fire_field"
			fire = fire or (state is BattleUltimate and state.book == &"flame")
			if not fire: continue
			var emitter := _spell_smoke[state]
			var start := emitter.position
			var end := start + emitter.end_offset
			fuel.append_array(PackedFloat32Array([start.x,start.y,end.x,end.y,state.radius,emitter.modulate.a,0,0]))
		for index in range(_fire_bursts.size()-1,-1,-1):
			var burst := _fire_bursts[index]
			burst.age += delta
			if burst.age >= .20:
				_fire_bursts.remove_at(index)
				continue
			var at: Vector2 = burst.at
			fuel.append_array(PackedFloat32Array([at.x,at.y,at.x,at.y,burst.radius,1.4*(1.0-burst.age/.20),0,0]))
		_fire_tail = 2.0 if not fuel.is_empty() else maxf(0.0,_fire_tail-delta)
	_fire_surface.visible = enabled and _fire_tail > 0.0
	_fire_capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if _fire_surface.visible else BackBufferCopy.COPY_MODE_DISABLED
	if _fire_surface.visible:
		var domain := PackedFloat32Array([size.x,size.y,delta,_clock])
		RenderingServer.call_on_render_thread(combustion.advance.bind(domain,fuel))


func track_body(id: StringName, point: Vector2, extent: Vector2, angle: float, tint: Color, glow: float = .4, solid: bool = true, gain: float = 18.0, presence: float = 1.0, body_shape: FluidInfluence.BodyShape = FluidInfluence.BodyShape.BLUNT) -> void:
	## Points and extents are in field-local coordinates, not normalized screen UVs.
	if extent.x <= 0 or extent.y <= 0:
		push_error("Fluid motion requires positive extent")
		return
	if presence < .02:
		untrack(id)
		return
	if not _motion.has(id):
		var added := Motion.new()
		added.previous = point
		added.previous_angle = angle
		added.flow_angle = angle
		_motion[id] = added
		_motion_order_dirty = true
	var motion := _motion[id]
	_motion_order_dirty = _motion_order_dirty or motion.glow != glow * presence
	if active and not reduced_motion and quality != Quality.OFF:
		motion.path.append(point)
	motion.point = point
	motion.extent = extent
	motion.angle = angle
	motion.color = tint
	motion.glow = glow * presence
	motion.solid = solid
	motion.gain = gain * presence
	motion.body_shape = body_shape
	if motion.glow > 0.0:
		motion.light.point = point
		motion.light.color = tint
		motion.light.energy = motion.glow
		motion.light.radius = maxf(extent.x, extent.y) * 3.0 + 80.0


func untrack(id: StringName) -> void:
	if _motion.erase(id): _motion_order_dirty = true


func _sync_battle_motion() -> void:
	var seen: Dictionary[StringName, bool] = {&"player": true}
	var fraction := Engine.get_physics_interpolation_fraction()
	var tint := light_color
	track_body(&"player", battle.previous_player_position.lerp(battle.player_position, fraction) * size, Vector2.ONE * 24, 0, tint, .25)
	if is_instance_valid(_dodge_trail):
		_dodge_trail.position = _motion[&"player"].point
	for enemy in battle.enemies:
		if enemy.alive():
			seen[enemy.id] = true
			track_body(enemy.id, enemy.previous_position.lerp(enemy.position, fraction) * size, Vector2.ONE * enemy.radius, 0, Color("a6bcd9"), 0)
	for projectile in battle.projectiles:
		var id := StringName("projectile_%d" % projectile.get_instance_id())
		seen[id] = true
		track_body(id, projectile.previous_position.lerp(projectile.position, fraction) * size, Vector2.ONE * projectile.radius, 0, tint, .8, false, 18.0, 1.0, FluidInfluence.BodyShape.POINTED)
	for spirit in battle.spirits:
		var id := StringName("spirit_%d" % spirit.get_instance_id())
		seen[id] = true
		track_body(id, spirit.previous_position.lerp(spirit.position, fraction) * size, Vector2.ONE * 18, 0, tint, .4, false)
	for threat in battle.threats:
		var id := StringName("threat_%d" % threat.get_instance_id())
		seen[id] = true
		track_body(id, threat.previous_position.lerp(threat.position, fraction) * size, Vector2.ONE * threat.radius, threat.velocity.angle(), BattleThreatOverlay.threat_color(threat), .5 if threat.heavy else .38, false, 5.0, 1.0, FluidInfluence.BodyShape.BLUNT)
	for id in _motion.keys():
		if id not in seen:
			untrack(id)


func _before_step(delta: float) -> void:
	_sync_gravity()
	for index in range(_shockwaves.size()-1,-1,-1):
		var wave := _shockwaves[index]
		wave.age += delta
		if wave.age >= (.3 if wave.get("attraction", false) else .18):
			_shockwaves.remove_at(index)
			continue
		var source := wave.source as FluidInfluence
		if wave.get("attraction", false):
			source.expansion = -wave.strength * exp(-wave.age*12.0)
		else:
			source.extent = Vector2.ONE * wave.radius * lerpf(.28,1.0,1.0-exp(-wave.age*18.0))
			source.expansion = wave.radius * 65.0 * exp(-wave.age*22.0) * wave.strength
		_scene_sources.append(source)
	# Keep render/input turns, then sweep every retained segment on the solver tick.
	if _motion_order_dirty:
		# Sort from insertion order, preserving the engine's original equal-key order.
		_ordered_motion.assign(_motion.values())
		_ordered_motion.sort_custom(func(a: Motion, b: Motion) -> bool: return a.glow > b.glow)
		_motion_order_dirty = false
	tracked_count = _ordered_motion.size()
	for motion in _ordered_motion:
		var point: Vector2 = motion.point
		var extent: Vector2 = motion.extent
		var path := motion.path
		var distance := path.length()
		var speed := distance / delta
		var angular := angle_difference(motion.previous_angle, motion.angle) / delta
		var radius := maxf(extent.x, extent.y)
		var emits_wake: bool = motion.solid or speed > 1.0 or absf(angular) > .01
		var emits_plume: bool = battle != null and not motion.solid and speed > 12.0
		for i in maxi(1, path.points.size() - 1):
			var start := path.points[i]
			var end := path.points[mini(i + 1, path.points.size() - 1)]
			var segment := end - start
			if segment.length_squared() > 0.0:
				motion.flow_angle = segment.angle()
			# The solver already truncates at this capacity, after higher-priority
			# emitters. Keep path/heading history and accounting, skip unused geometry.
			if _scene_sources.size() >= FluidGPU.MAX_INFLUENCES:
				_omitted_scene_sources += int(emits_wake) + int(emits_plume)
				continue
			while motion.wakes.size() <= i:
				motion.wakes.append(FluidInfluence.new())
				motion.plumes.append(FluidInfluence.new())
			var velocity := segment.normalized() * speed
			var wake := motion.wakes[i] as FluidInfluence
			FluidMotionPath.sweep(wake, start, end, radius * 3.2)
			wake.rotation = motion.flow_angle
			wake.displacement_radius = radius
			wake.body_shape = motion.body_shape
			wake.velocity = velocity
			wake.coupling = motion.gain * FluidMotionPath.exposure(segment.length(), distance, radius)
			wake.spin = clampf(angular, -4, 4)
			if emits_wake:
				_scene_sources.append(wake)
			if emits_plume:
				if _scene_sources.size() >= FluidGPU.MAX_INFLUENCES:
					_omitted_scene_sources += 1
					continue
				var width := clampf(maxf(extent.x, extent.y) * .8, 18, 80)
				var plume := motion.plumes[i] as FluidInfluence
				var rear_length := radius * (wake.body_aspect if wake.body_shape == FluidInfluence.BodyShape.POINTED else 1.0)
				var release_offset := segment.normalized() * rear_length * 0.35
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
	_ambient[0].center = size * Vector2(.5, .5)
	_ambient[0].extent = size * Vector2(.95, .9)
	_ambient[0].noise_scale = size.y * .72
	_scene_sources.append(_ambient[0])


func _sync_gravity() -> void:
	if battle == null or battle.runtime == null: return
	var live: Array[RefCounted] = []
	for field in battle.runtime.fields:
		if field.effect.kind == &"gravity_field": live.append(field)
	for enemy in battle.enemies:
		if enemy.alive() and enemy.aura == &"pull": live.append(enemy)
	for state in live:
		var at: Vector2
		var radius: float
		var speed: float
		if state is SpellField:
			at = state.center
			radius = state.radius
			speed = 180.0
		else:
			var enemy := state as BattleEnemy
			at = enemy.position
			radius = enemy.aura_radius
			speed = 67.5
		if not _gravity_sources.has(state):
			_gravity_sources[state] = FluidInfluence.new()
		var source := _gravity_sources[state]
		source.center = at * size
		source.extent = Vector2.ONE * radius
		source.expansion = -speed
		_scene_sources.append(source)
	for state in _gravity_sources.keys():
		if state not in live: _gravity_sources.erase(state)


func _scene_light_inputs() -> Array[Dictionary]:
	var emitters: Array[Dictionary] = []
	if active:
		for motion in _motion.values():
			if motion.glow > 0:
				emitters.append(motion.light)
	return emitters


func present(event: Dictionary) -> void:
	if reduced_motion or not active or quality == Quality.OFF:
		return
	var kind: StringName = event.kind
	var point := (event.get("contact", event.get("center", event.get("at", Vector2(.5, .5)))) as Vector2) * size
	if kind == &"gravity_pull":
		var attraction := FluidInfluence.new()
		attraction.center = point
		attraction.extent = Vector2.ONE * float(event.radius)
		_shockwaves.append({"source":attraction,"age":0.0,"strength":float(event.force),"attraction":true})
		return
	if kind in [&"pickup_trigger", &"counter_pulse", &"parry_start"]:
		# BattleVisuals owns these bursts independently of the fluid simulation.
		return
	if kind == &"impact" and str(event.source).begins_with("frost"):
		_burst_cloud(point,105.0 if event.get("empowered",false) else 65.0,Color("b6dced"),false,.2)
		return
	if kind == &"impact" and str(event.source).begins_with("flame"):
		# Burning ticks already share their field; they must not respawn large clouds.
		if event.source != &"flame_burn":
			var radius := 130.0 if event.source in [&"flame_burst", &"flame_ultimate"] else 65.0
			_burst_cloud(point,radius,Color("ff922b"),true)
		return
	if kind == &"ultimate" and battle.book_id == &"flame":
		return # The paid timeline below owns sustained emission.
	if kind not in [&"cast", &"impact", &"counter_pulse", &"parry_start", &"dodge", &"dodge_end", &"ultimate", &"spirit_summon", &"death", &"enemy_shot"]:
		return
	if kind == &"dodge_end" and not effects.has(kind):
		return # The moving trail continues advecting; stopping is not an explosion.
	var directional := kind in [&"cast", &"dodge", &"enemy_shot"]
	var template: FluidEffectProfile = effects.get(kind, DODGE if kind == &"dodge" else (GUST if directional else BURST))
	var profile := template.duplicate(true) as FluidEffectProfile
	if kind == &"impact" and str(event.source).begins_with("storm"):
		profile.light_energy = 0.0 # The arc owns lighting; retain the existing air impulse.
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


func _burst_cloud(at: Vector2, radius: float, tint: Color, fire: bool, strength: float = 1.0) -> void:
	if fire and combustion != null:
		_fire_bursts.append({"at":at,"radius":radius,"age":0.0})
	var medium := FluidMedium.new()
	medium.color = tint
	medium.dissipation = 5.5 if fire else 6.0
	medium.emission = .0 if fire else 2.0 * strength
	# Deposit once, with unequal small lobes. Subsequent frames only move this gas.
	for index in 4:
		var source := FluidInfluence.new()
		source.center = at + Vector2.from_angle(randf()*TAU)*radius*randf_range(.03,.09)
		source.extent = Vector2.ONE*radius*randf_range(.19,.29)
		source.rotation = randf()*TAU
		source.density = (.22 if fire else .9)*strength
		source.noise_amount = .65
		source.noise_scale = maxf(8.0,radius*.035)
		source.medium = medium
		source.spin = randf_range(-1.5,1.5)
		inject(source)
	var expansion := FluidInfluence.new()
	expansion.center = at
	expansion.rotation = randf()*TAU
	expansion.noise_amount = 1.0
	_shockwaves.append({"source":expansion,"radius":radius,"age":0.0,"strength":strength})
	var light := FluidEffectProfile.new()
	light.duration = .24
	light.fade_out = 1.0
	light.light_color = tint
	light.light_radius = minf(180.0,radius)
	light.light_energy = (.8 if fire else .5)*strength
	emit_effect(light,at)


func _sync_spell_smoke() -> void:
	# One source per paid field; existing GPU grid and pressure solve stay shared.
	var live: Array[RefCounted] = []
	if not reduced_motion and quality != Quality.OFF:
		for state in battle.runtime.fields:
			if state.effect.kind not in [&"fire_field",&"cold_field"]: continue
			live.append(state)
			var emitter := _field_emitter(state, state.radius, state.effect.kind == &"fire_field")
			emitter.position = state.center * size
			emitter.end_offset = (state.endpoint - state.center) * size
			emitter.modulate.a = clampf((state.expires_at - battle.runtime.clock) / .4, 0.0, 1.0)
		for timeline in battle.ultimates:
			if timeline.book not in [&"flame",&"frost"]: continue
			live.append(timeline)
			var emitter := _field_emitter(timeline, timeline.radius, timeline.book == &"flame")
			emitter.position = timeline.center * size
			emitter.modulate.a = smoothstep(0.0, .25, timeline.age) * clampf((timeline.lifetime - timeline.age) / .5, 0.0, 1.0)
	for state in _spell_smoke.keys():
		if state not in live:
			_spell_smoke[state].hide()
			_spell_smoke[state].queue_free()
			_spell_smoke.erase(state)


func _field_emitter(state: RefCounted, radius: float, fire: bool) -> FluidEmitter2D:
	if not _spell_smoke.has(state):
		var profile := FluidEffectProfile.new()
		profile.duration = 0.0
		profile.along_path = true
		var source := FluidInfluence.new()
		source.extent = Vector2.ONE * radius * .9
		source.density = .18 if fire else .22
		source.spin = 2.4 if fire else .3
		source.coupling = 5.0
		source.noise_amount = .9
		source.noise_scale = maxf(32.0,radius*.18)
		source.medium = FluidMedium.new()
		source.medium.color = Color("ff922b") if fire else Color("aecfdc")
		source.medium.emission = 0.0 if fire else .12
		source.medium.dissipation = 1.1 if fire else 1.8
		profile.influences.append(source)
		if fire:
			profile.light_color = Color("ffac58")
			profile.light_energy = .8
			profile.light_radius = radius * 1.7
		_spell_smoke[state] = emit_effect(profile, Vector2.ZERO)
	return _spell_smoke[state]
