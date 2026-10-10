class_name FluidBody2D
extends Node2D
## A projected body transfers momentum; SOLID is for walls occupying the entire
## simulated slice. Neither mode feeds visual pressure back into game physics.

enum Interaction { DISPLACE, SOLID }

@export var field: FluidField2D
## Optional. Without a collider, use this node's transform and manual footprint.
@export var collision: CollisionShape2D
@export var shape: FluidInfluence.Shape = FluidInfluence.Shape.ELLIPSE
@export var extent := Vector2(24, 24)
@export var interaction: Interaction = Interaction.DISPLACE
@export var coupling: float = 24.0
@export var reach: float = 3.2
@export var body_shape: FluidInfluence.BodyShape = FluidInfluence.BodyShape.BLUNT
@export_range(1.0, 4.0) var body_aspect: float = 2.4
@export_range(0.0, 1200.0) var response_speed: float = 240.0
var _obstacle := FluidInfluence.new()
var _previous := Vector2.ZERO
var _previous_angle := 0.0
var _started := false
var _flow_angle := 0.0


func _ready() -> void:
	if field == null:
		push_error("FluidBody2D requires a field")
		set_process(false)
		return
	if collision != null and not (collision.shape is CircleShape2D or collision.shape is RectangleShape2D or collision.shape is CapsuleShape2D):
		push_error("FluidBody2D supports circle, rectangle and capsule collision shapes")
		set_process(false)
		return
	if collision == null and (extent.x <= 0.0 or extent.y <= 0.0):
		push_error("FluidBody2D requires positive manual extent")
		set_process(false)
		return
	field.tree_exiting.connect(_detach)
	if collision != null:
		collision.tree_exiting.connect(_detach)


func _process(delta: float) -> void:
	delta = BattleVisualClock.delta_for(self, delta)
	var local_transform := field.get_global_transform().affine_inverse() * (collision.global_transform if collision != null else global_transform)
	_obstacle.center = local_transform.origin
	_obstacle.rotation = local_transform.get_rotation()
	var footprint: Shape2D = collision.shape if collision != null else null
	var half_size := extent
	_obstacle.shape = shape
	if footprint is CircleShape2D:
		_obstacle.shape = FluidInfluence.Shape.ELLIPSE
		half_size = Vector2.ONE * (footprint as CircleShape2D).radius
	elif footprint is RectangleShape2D:
		_obstacle.shape = FluidInfluence.Shape.BOX
		half_size = (footprint as RectangleShape2D).size * 0.5
	elif footprint is CapsuleShape2D:
		_obstacle.shape = FluidInfluence.Shape.CAPSULE
		_obstacle.rotation += PI * 0.5
		half_size = Vector2((footprint as CapsuleShape2D).height * 0.5, (footprint as CapsuleShape2D).radius)
		local_transform = local_transform.rotated_local(PI * 0.5)
	_obstacle.extent = half_size * Vector2(local_transform.x.length(), local_transform.y.length())
	_obstacle.coupling = coupling if interaction == Interaction.DISPLACE else 0.0
	_obstacle.displacement_radius = maxf(_obstacle.extent.x, _obstacle.extent.y) if interaction == Interaction.DISPLACE else 0.0
	_obstacle.sweep_length = 0.0
	_obstacle.body_shape = body_shape
	_obstacle.body_aspect = body_aspect
	_obstacle.response_speed = response_speed
	if interaction == Interaction.DISPLACE:
		_obstacle.extent *= reach
	_obstacle.velocity = (_obstacle.center - _previous) / maxf(delta, 0.0001) if _started else Vector2.ZERO
	_obstacle.spin = angle_difference(_previous_angle, _obstacle.rotation) / maxf(delta, 0.0001) if _started else 0.0
	var point := _obstacle.center
	var angle := _obstacle.rotation
	if not _started:
		_flow_angle = angle
	if interaction == Interaction.DISPLACE and _started and point.distance_squared_to(_previous) > 1.0:
		var radius := maxf(_obstacle.extent.x, _obstacle.extent.y)
		FluidMotionPath.sweep(_obstacle, _previous, point, radius)
		_flow_angle = _obstacle.rotation
		_obstacle.coupling *= FluidMotionPath.exposure(point.distance_to(_previous), point.distance_to(_previous), _obstacle.displacement_radius)
	if interaction == Interaction.DISPLACE and body_shape == FluidInfluence.BodyShape.POINTED:
		_obstacle.rotation = _flow_angle if _started else angle
	_previous = point
	_previous_angle = angle
	_started = true
	var inputs := field.sources if interaction == Interaction.DISPLACE else field.obstacles
	var other := field.obstacles if interaction == Interaction.DISPLACE else field.sources
	other.erase(_obstacle)
	if (collision != null and collision.disabled) or not is_visible_in_tree():
		inputs.erase(_obstacle)
	elif not inputs.has(_obstacle):
		inputs.append(_obstacle)


func rebase() -> void:
	## After teleporting, start a fresh motion sample instead of sweeping the jump.
	_started = false
	_obstacle.velocity = Vector2.ZERO
	_obstacle.spin = 0.0
	_obstacle.sweep_length = 0.0


func _exit_tree() -> void:
	_detach()


func _detach() -> void:
	set_process(false)
	if is_instance_valid(field):
		field.obstacles.erase(_obstacle)
		field.sources.erase(_obstacle)
