class_name BattleProjectile
extends RefCounted
## Fixed-step flight state. The renderer reads positions; it never commits hits.

var effect: BattleEffect
var position := Vector2.ZERO
var previous_position := Vector2.ZERO
var velocity := Vector2.ZERO # Arena units per second.
var attraction_impulse := Vector2.ZERO # Applied after homing, before swept movement.
var speed: float = 1080.0
var radius: float = 6.0
var life: float = 2.1
var homing: bool = true
var remaining_hits: int = 1
var hit_ids: PackedStringArray = []
var trail: PackedVector2Array = []


func _init(paid_effect: BattleEffect) -> void:
	effect = paid_effect
	position = paid_effect.origin
	previous_position = position
	remaining_hits = effect.applications
	if effect.build != null and effect.build.has(&"fast-flight"):
		life /= 1.25
	if str(effect.kind).begins_with("frost"):
		speed = 1540.0 if effect.empowered else 1380.0
		radius = 10.0 if effect.empowered else 6.0
		life = 1.65
		remaining_hits = effect.applications
