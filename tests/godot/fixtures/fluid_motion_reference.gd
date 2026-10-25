extends RefCounted
## Frozen GDS motion implementation, before the managed batch kernel.
## Used only by test_fluid; keeps the original source/RNG-independent numeric path.
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

var _motion: Dictionary = {}
var _ordered_motion: Array[Motion] = []
var _motion_order_dirty := true

var active := true
var reduced_motion := false
var quality := FluidField2D.Quality.MEDIUM
const Quality = FluidField2D.Quality
var battle: BattleSession
var trail_material: FluidMedium
var fog_color := Color("668b9b")
var tracked_count := 0
var _scene_sources: Array[FluidInfluence] = []
var _scene_source_capacity := FluidGPU.MAX_INFLUENCES
var _omitted_scene_sources := 0

func track_body(id: Variant, point: Vector2, extent: Vector2, angle: float, tint: Color, glow: float = .4, solid: bool = true, gain: float = 18.0, presence: float = 1.0, body_shape: FluidInfluence.BodyShape = FluidInfluence.BodyShape.BLUNT) -> void:
	## Points and extents are in field-local coordinates, not normalized screen UVs.
	## Battle bodies use object identity; authored UI bodies use stable StringNames.
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
	var motion: Motion = _motion[id]
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


func untrack(id: Variant) -> void:
	if _motion.erase(id): _motion_order_dirty = true



func _before_step(delta: float) -> void:
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
		if _scene_sources.size() >= _scene_source_capacity:
			_omitted_scene_sources += maxi(1, path.points.size() - 1) * (int(emits_wake) + int(emits_plume))
			# Only the last nonzero segment affects the next tick's heading.
			for i in range(path.points.size() - 1, 0, -1):
				var last_segment := path.points[i] - path.points[i - 1]
				if last_segment.length_squared() > 0.0:
					motion.flow_angle = last_segment.angle()
					break
			path.reset(point)
			motion.previous = point
			motion.previous_angle = motion.angle
			continue
		for i in maxi(1, path.points.size() - 1):
			var start := path.points[i]
			var end := path.points[mini(i + 1, path.points.size() - 1)]
			var segment := end - start
			if segment.length_squared() > 0.0:
				motion.flow_angle = segment.angle()
			# The solver already truncates at this capacity, after higher-priority
			# emitters. Keep path/heading history and accounting, skip unused geometry.
			if _scene_sources.size() >= _scene_source_capacity:
				_omitted_scene_sources += int(emits_wake) + int(emits_plume)
				continue
			while motion.wakes.size() <= i:
				motion.wakes.append(FluidInfluence.new())
				motion.plumes.append(FluidInfluence.new())
			var direction := segment.normalized()
			var velocity := direction * speed
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
				if _scene_sources.size() >= _scene_source_capacity:
					_omitted_scene_sources += 1
					continue
				var width := clampf(maxf(extent.x, extent.y) * .8, 18, 80)
				var plume := motion.plumes[i] as FluidInfluence
				var rear_length := radius * (wake.body_aspect if wake.body_shape == FluidInfluence.BodyShape.POINTED else 1.0)
				var release_offset := direction * rear_length * 0.35
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
