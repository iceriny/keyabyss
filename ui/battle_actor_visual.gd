class_name BattleActorVisual
extends Node2D
## Retains the book-and-ink silhouettes; surface, lighting and dissolution are native.

const PLAYER = preload("res://assets/art/actors/scribe.svg")
const ENEMIES = {
	&"nib": preload("res://assets/art/actors/nib.svg"),
	&"quill": preload("res://assets/art/actors/quill.svg"),
	&"guard": preload("res://assets/art/actors/guard.svg"),
}
@onready var body: Sprite2D = $Body
@onready var surface: ShaderMaterial = body.material as ShaderMaterial
@onready var shadow: Sprite2D = $Shadow
@onready var aura: Sprite2D = $Aura
var dead_time: float = 0.0
var _kind: StringName
var _tint: Color
var _glow: Texture2D
var _hit_motion := DampedMotion.new()
var _hit_axis := Vector2.RIGHT


static func create(kind: StringName, tint: Color, glow: Texture2D) -> BattleActorVisual:
	var scene := load("res://ui/scenes/battle_actor_visual.tscn") as PackedScene
	var visual := scene.instantiate() as BattleActorVisual
	visual.configure(kind, tint, glow)
	return visual


func configure(kind: StringName, tint: Color, glow: Texture2D) -> void:
	_kind = kind
	_tint = tint
	_glow = glow
	if is_node_ready():
		_apply_configuration()


func _ready() -> void:
	_apply_configuration()


func _apply_configuration() -> void:
	body.light_mask = 2
	shadow.texture = _glow
	aura.texture = _glow
	aura.modulate = Color(_tint, 0.12 if _kind == &"player" else 0.035)
	body.texture = PLAYER if _kind == &"player" else ENEMIES[_kind]
	body.scale = Vector2.ONE * (0.43 if _kind == &"player" else 0.44)
	surface.set_shader_parameter("school", _tint)


func receive_impact(direction: Vector2, strength: float, reduced: bool) -> void:
	if reduced:
		_hit_motion.reset()
		return
	_hit_axis = direction.normalized()
	_hit_motion.kick(_hit_axis * strength, strength)


func sync_enemy(enemy: BattleEnemy, at: Vector2, time: float, delta: float, reduced: bool) -> void:
	position = at
	if reduced:
		_hit_motion.reset()
	else:
		_hit_motion.advance(delta, 6.0)
	if not enemy.alive():
		dead_time = minf(1.0, dead_time + delta * 1.8)
		surface.set_shader_parameter("dissolve", dead_time)
		modulate.a = 1.0 - dead_time
		return
	var bob := 0.0 if reduced else sin(time * 1.7 + float(str(enemy.id).get_slice("_", 1)) * 2.1) * 2.0
	body.position = _hit_motion.position + Vector2(0.0, bob)
	if enemy.kind == &"nib" and not reduced:
		if enemy.aiming:
			var tension := 1.0 - clampf(enemy.attack_clock / enemy.warning_time, 0.0, 1.0)
			body.position -= enemy.melee_direction * tension * tension * 7.0
		elif enemy.melee_strike > 0.0:
			var swing := 1.0 - enemy.melee_strike / BattleEnemy.MELEE_STRIKE_TIME
			body.position += enemy.melee_direction * sin(swing * PI) * 14.0
	body.rotation = 0.0 if reduced else clampf((enemy.velocity.x + enemy.impulse.x) * 0.00055, -0.24, 0.24)
	var axis := _hit_axis if _hit_motion.position.length() > 0.01 else enemy.velocity.normalized()
	if axis.is_zero_approx():
		axis = Vector2.UP
	var compression := 0.0 if reduced else minf(0.15, enemy.squash * 0.35 + _hit_motion.position.length() / 5.0 * 0.09)
	body.scale = (Vector2.ONE * (1.0 + compression * 0.45) - axis * axis * (compression * 1.45)) * 0.44
	surface.set_shader_parameter("flash", minf(0.68, enemy.hit_flash / 0.12 * 0.68))
	surface.set_shader_parameter("frozen", minf(1.0, enemy.frozen_time * 2.0))
	surface.set_shader_parameter("burning", minf(1.0, enemy.burn_time))
	surface.set_shader_parameter("visual_time", 0.0 if reduced else time)


func sync_player(at: Vector2, time: float, recoil: Vector2, hurt: float, delta: float, reduced: bool) -> void:
	position = at
	if reduced:
		_hit_motion.reset()
	else:
		_hit_motion.advance(delta, 6.0)
	body.position = recoil + _hit_motion.position + Vector2(0.0, 0.0 if reduced else sin(time * 2.3) * 2.0)
	var compression := minf(0.15, _hit_motion.position.length() / 5.0 * 0.12)
	body.scale = (Vector2.ONE * (1.0 + compression * 0.45) - _hit_axis * _hit_axis * (compression * 1.45)) * 0.43
	surface.set_shader_parameter("flash", minf(0.68, hurt * 1.36))
