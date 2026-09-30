class_name UltimateField
extends Control
## Presentation follows the paid timeline, including the frost field's longer tail.

var timeline: BattleUltimate
var _surface: ShaderMaterial


static func create(state: BattleUltimate, tint: Color) -> UltimateField:
	var field := preload("res://ui/scenes/ultimate_field.tscn").instantiate() as UltimateField
	field.timeline = state
	field._surface = field.get_node("Light").material as ShaderMaterial
	field._surface.set_shader_parameter("school", [&"frost", &"flame", &"storm", &"spirit"].find(state.book))
	field._surface.set_shader_parameter("tint", tint)
	return field


func sync_frame(world_size: Vector2, detail: int, less_motion: bool) -> void:
	size = Vector2.ONE * timeline.radius * 2.5
	position = timeline.center * world_size - size * 0.5
	_surface.set_shader_parameter("age", timeline.age)
	_surface.set_shader_parameter("lifetime", timeline.lifetime)
	_surface.set_shader_parameter("motion", 0.0 if less_motion else 1.0)
	_surface.set_shader_parameter("detail", float(detail) / 2.0)
