class_name BattleThreat
extends RefCounted

var source_id: StringName
var position := Vector2.ZERO
var previous_position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage_q: int
var radius: float = 5.0
var life: float = 6.0
var reflected: bool = false
var cleared: bool = false
var trail: PackedVector2Array = []
var attack_id: String
var effect: BattleEffect
var grazed: bool = false
var curvature: float = 0.0
var acceleration: float = 0.0
var heavy: bool = false
var visual_style: StringName
var _flight_delta := -1.0
var _flight_turn := 0.0
var _flight_growth := 0.0
var _flight_linear := true
var _flight_along := 0.0
var _flight_across := 0.0
var _flight_angle := 0.0
var _flight_scale := 1.0


func advance_flight(delta: float, arena_size: Vector2) -> void:
	# Coefficients depend on the time step and flight law, never on velocity.
	# Read velocity here so earlier parries/impacts still affect this exact step.
	if _flight_delta != delta or _flight_turn != curvature or _flight_growth != acceleration:
		_flight_delta = delta
		_flight_turn = curvature
		_flight_growth = acceleration
		var denominator := acceleration * acceleration + curvature * curvature
		_flight_linear = denominator < 0.00000001
		_flight_angle = curvature * delta
		_flight_scale = exp(acceleration * delta)
		if not _flight_linear:
			var cosine := cos(_flight_angle)
			var sine := sin(_flight_angle)
			_flight_along = (_flight_scale * (acceleration * cosine + curvature * sine) - acceleration) / denominator
			_flight_across = (_flight_scale * (acceleration * sine - curvature * cosine) + curvature) / denominator
	previous_position = position
	var displacement := velocity * delta if _flight_linear else velocity * _flight_along + Vector2(-velocity.y, velocity.x) * _flight_across
	position += displacement / arena_size
	velocity = velocity.rotated(_flight_angle) * _flight_scale


func aim_curve(offset: Vector2) -> float:
	# Choose the launch tangent once; flight does not follow a moving target.
	var distance := offset.length()
	var speed := velocity.length()
	if distance == 0.0: return 0.0
	# Keep the target on the first bend, within the reachable chord.
	curvature = signf(curvature) * minf(absf(curvature), 1.2 * speed / distance)
	var lower := 0.0
	var upper := distance / speed * 1.25
	for iteration in 24:
		var middle := (lower + upper) * 0.5
		if flight_displacement(Vector2.RIGHT * speed, curvature, acceleration, middle).length() < distance:
			lower = middle
		else:
			upper = middle
	var arrival := (lower + upper) * 0.5
	var local := flight_displacement(Vector2.RIGHT * speed, curvature, acceleration, arrival)
	velocity = Vector2.from_angle(offset.angle() - local.angle()) * speed
	life = maxf(life, arrival + 1.0)
	return arrival


func flight_bounds(duration: float) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO).expand(flight_displacement(velocity, curvature, acceleration, duration))
	if curvature == 0.0: return bounds
	var heading := velocity.angle()
	var final_heading := heading + curvature * duration
	# Coordinate extrema occur when the tangent crosses a cardinal direction.
	for quadrant in range(floori(minf(heading, final_heading) / (PI * 0.5)) + 1, ceili(maxf(heading, final_heading) / (PI * 0.5))):
		var time := (quadrant * PI * 0.5 - heading) / curvature
		bounds = bounds.expand(flight_displacement(velocity, curvature, acceleration, time))
	return bounds


static func flight_displacement(initial_velocity: Vector2, turn: float, growth: float, delta: float) -> Vector2:
	# Exact integral of an exponentially speeding, continuously turning velocity.
	var denominator := growth * growth + turn * turn
	if denominator < 0.00000001: return initial_velocity * delta
	var angle := turn * delta
	var scale := exp(growth * delta)
	var along := (scale * (growth * cos(angle) + turn * sin(angle)) - growth) / denominator
	var across := (scale * (growth * sin(angle) - turn * cos(angle)) + turn) / denominator
	return initial_velocity * along + Vector2(-initial_velocity.y, initial_velocity.x) * across


static func flight_velocity(initial_velocity: Vector2, turn: float, growth: float, delta: float) -> Vector2:
	return initial_velocity.rotated(turn * delta) * exp(growth * delta)
