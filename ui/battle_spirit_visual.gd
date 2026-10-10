class_name BattleSpiritVisual
extends Node2D
## One visible body follows one authoritative summon through every flight phase.

const TRAIL_LENGTH := 280.0

var spirit: BattleSpirit
@onready var body: Sprite2D = $Body
@onready var halo: Line2D = $Halo
@onready var ribbon: Line2D = $Ribbon
@onready var filament: Line2D = $Filament
@onready var paper: ShaderMaterial = body.material as ShaderMaterial
var age: float = 0.0
var world_size := Vector2.ZERO


static func create(value: BattleSpirit) -> BattleSpiritVisual:
	var scene := load("res://ui/scenes/battle_spirit_visual.tscn") as PackedScene
	var visual := scene.instantiate() as BattleSpiritVisual
	visual.configure(value)
	return visual


func configure(value: BattleSpirit) -> void:
	spirit = value
	if is_node_ready():
		_apply_configuration()


func _ready() -> void:
	_apply_configuration()


func _apply_configuration() -> void:
	# Ribbon shader keeps the optical width; extra geometry holds its AA fringe.
	halo.width = (25.0 if spirit.crossing else 15.0) * 3.0
	ribbon.width = (8.0 if spirit.crossing else 4.0) * 3.0
	filament.width = (2.2 if spirit.crossing else 1.3) * 3.0


func sync_frame(view_size: Vector2, fraction: float, remaining: float, delta: float, detail: int, reduce: bool) -> void:
	world_size = view_size
	_apply_configuration()
	age += delta
	body.position = spirit.previous_position.lerp(spirit.position, fraction) * view_size
	var desired := (spirit.velocity * view_size / BattleSession.ARENA_SIZE).angle()
	body.rotation = lerp_angle(body.rotation, desired, 1.0 - exp(-delta * 18.0))
	paper.set_shader_parameter("flutter", 0.0 if reduce else sin(age * 8.0 + spirit.slot * 1.8))
	body.scale = Vector2(1.15, 0.65) if spirit.crossing else Vector2.ONE * 0.85
	modulate.a = minf(1.0, age / 0.2) * (1.0 if spirit.crossing else minf(1.0, remaining / 0.8))
	var samples := PackedVector2Array()
	for at in spirit.trail:
		samples.append(at * world_size)
	_set_trail(samples, body.position)
	for line in [halo, ribbon, filament]:
		line.visible = not reduce and (detail > 0 or spirit.crossing)


func retire() -> void:
	var samples := PackedVector2Array()
	for at in spirit.trail:
		samples.append(at * world_size)
	_set_trail(samples, spirit.position * world_size)
	var fade := BattleVisualClock.tween_for(self)
	fade.tween_property(self, "modulate:a", 0.0, 0.25)
	fade.tween_callback(queue_free)


func _set_trail(samples: PackedVector2Array, render_head: Vector2) -> void:
	var points := MotionTrail.build(samples, spirit.position * world_size, render_head, TRAIL_LENGTH, true, 64)
	for line in [halo, ribbon, filament]:
		line.points = points
