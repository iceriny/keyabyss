class_name BattleProjectileVisual
extends Node2D
## A visible flight follows a fixed-step projectile and owns only render resources.

const TRAIL_LENGTH := 220.0

var projectile: BattleProjectile
var world_size: Vector2
var quality: int
var reduced_motion: bool
var budget: BattleVisualBudget
var _ember_capacity := -1
@onready var trail: Line2D = $Trail
@onready var trail_glow: Line2D = $TrailGlow
@onready var head: Node2D = $Head
@onready var halo: Sprite2D = $Head/Halo
@onready var flame_sprite: Sprite2D = $Head/Flame
@onready var flame_material: ShaderMaterial = flame_sprite.material as ShaderMaterial
@onready var shape: Polygon2D = $Head/Shape
@onready var facet: Polygon2D = $Head/Facet
@onready var spine: Line2D = $Head/Spine
@onready var barb_upper: Line2D = $Head/BarbUpper
@onready var barb_lower: Line2D = $Head/BarbLower
@onready var ink_folds: Node2D = $Head/InkFolds
@onready var embers: GPUParticles2D = $Embers


static func create(value: BattleProjectile, detail: int, reduce: bool) -> BattleProjectileVisual:
	var scene := load("res://ui/scenes/battle_projectile_visual.tscn") as PackedScene
	var visual := scene.instantiate() as BattleProjectileVisual
	visual.configure(value, detail, reduce)
	return visual


func configure(value: BattleProjectile, detail: int, reduce: bool) -> void:
	projectile = value
	quality = detail
	reduced_motion = reduce
	if is_node_ready():
		_apply_configuration()


func _ready() -> void:
	_apply_configuration()


func _apply_configuration() -> void:
	var source := str(projectile.effect.kind)
	var flame := source.begins_with("flame")
	var frost := source.begins_with("frost")
	var empowered := projectile.effect.empowered
	var tint := Color("f6a55b") if flame else (Color("a9eaff") if frost else Color("ddc6ff"))
	trail.width = (3.5 if empowered else 2.2) if flame else (3.0 if empowered else 1.7)
	trail.width *= 3.0
	trail.gradient.set_color(0, Color(tint, 0.0))
	trail.gradient.set_color(1, Color(tint, 0.72 if flame else 0.6))
	trail.visible = not reduced_motion
	trail_glow.width = trail.width * (5.0 if flame else 4.5)
	trail_glow.gradient.set_color(0, Color(tint, 0.0))
	trail_glow.gradient.set_color(1, Color(tint, 0.10 if flame else 0.12))
	trail_glow.visible = trail.visible and quality > 0
	halo.modulate = Color((Color("ffac55") if flame else tint) * 1.4, 0.42)
	halo.scale = (Vector2(2.0, 0.96) if empowered else Vector2(1.45, 0.62)) if flame else (Vector2(2.35, 1.05) if empowered and frost else Vector2(1.7, 0.82))
	flame_sprite.visible = flame
	shape.visible = not flame
	facet.visible = not flame
	spine.visible = not flame
	barb_upper.visible = not flame and frost and empowered
	barb_lower.visible = barb_upper.visible
	ink_folds.visible = not flame and source.begins_with("spirit")
	embers.emitting = false
	if _ember_capacity < 0:
		_ember_capacity = budget.grant_particles(roundi(8 * VisualQuality.PARTICLE_DENSITY[quality])) if flame and not reduced_motion else 0
		if _ember_capacity > 0:
			embers.amount = _ember_capacity
			budget.track_particles(embers, _ember_capacity)
	embers.visible = flame and not reduced_motion and _ember_capacity > 0
	if flame:
		var texture := flame_sprite.texture as GradientTexture2D
		texture.width = 130 if empowered else 104
		texture.height = 68 if empowered else 52
		flame_material.set_shader_parameter("empowered", 1.0 if empowered else 0.0)
	else:
		if frost:
			var length := 52.0 if empowered else 25.0
			var half_width := 9.0 if empowered else 5.0
			shape.polygon = PackedVector2Array([Vector2(length, 0), Vector2(-length * 0.6, -half_width), Vector2(-length * 0.35, 0), Vector2(-length * 0.6, half_width)])
			facet.polygon = PackedVector2Array([Vector2(length, 0), Vector2(-length * 0.6, -half_width), Vector2(-length * 0.35, 0)])
			facet.color = Color(0.25, 0.65, 0.85, 0.85)
		else:
			shape.polygon = PackedVector2Array([Vector2(20, 0), Vector2(-14, -9), Vector2(-5, 0), Vector2(-14, 9)])
			facet.polygon = PackedVector2Array([Vector2(20, 0), Vector2(-14, -9), Vector2(-5, 0)])
			facet.color = Color("796393")
		shape.color = tint
		spine.points = PackedVector2Array([Vector2(-29, 0), Vector2(46, 0)]) if empowered and frost else PackedVector2Array([Vector2(-16, 0), Vector2(22, 0)])
		spine.default_color = Color(1.3, 1.6, 1.7, 0.8) if frost else Color("f7ebda")


func sync_frame(view_size: Vector2, fraction: float) -> void:
	world_size = view_size
	if flame_sprite.visible:
		flame_material.set_shader_parameter("visual_time", 0.0 if reduced_motion else -projectile.life)
	var point := projectile.previous_position.lerp(projectile.position, fraction) * world_size
	head.position = point
	head.rotation = (projectile.velocity * world_size / BattleSession.ARENA_SIZE).angle()
	if trail.visible:
		var samples := PackedVector2Array()
		for at in projectile.trail:
			samples.append(at * world_size)
		_set_trail(samples, point)
	if embers.visible:
		embers.position = point
		embers.rotation = head.rotation
		embers.emitting = true


func retire() -> void:
	if trail.visible:
		var samples := PackedVector2Array()
		for at in projectile.trail:
			samples.append(at * world_size)
		_set_trail(samples, projectile.position * world_size)
	head.hide()
	embers.emitting = false
	var fade := BattleVisualClock.tween_for(self)
	fade.tween_property(self, "modulate:a", 0.0, 0.22)
	fade.tween_callback(queue_free)


func _set_trail(samples: PackedVector2Array, render_head: Vector2) -> void:
	var points := MotionTrail.build(samples, projectile.position * world_size, render_head, 110.0 if quality == 0 else TRAIL_LENGTH, true, VisualQuality.TRAIL_POINTS[quality])
	trail.points = points
	if trail_glow.visible: trail_glow.points = points
