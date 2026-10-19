class_name UltimateField
extends Control
## Presentation follows the paid timeline, including the frost field's longer tail.

var timeline: BattleUltimate
var _surface: ShaderMaterial
var ice: IcePatch
var _ice_light: PointLight2D
var _seal: Sprite2D
var _ice_seed: int
var budget: BattleVisualBudget


static func create(state: BattleUltimate, tint: Color) -> UltimateField:
	var field := load("res://ui/scenes/ultimate_field.tscn").instantiate() as UltimateField
	field.timeline = state
	field._surface = field.get_node("Light").material as ShaderMaterial
	field._surface.set_shader_parameter("school", [&"frost", &"flame", &"storm", &"spirit"].find(state.book))
	field._surface.set_shader_parameter("tint", tint)
	return field


func _ready() -> void:
	_seal = Sprite2D.new()
	_seal.texture = ArcanaRunes.seal(timeline.book, timeline.radius * 2.0)
	_seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_seal.material = preload("res://ui/materials/book_seal.tres").duplicate()
	(_seal.material as ShaderMaterial).set_shader_parameter("tint", _surface.get_shader_parameter("tint"))
	(_seal.material as ShaderMaterial).set_shader_parameter("strength", .65)
	(_seal.material as ShaderMaterial).set_shader_parameter("recession", 1.0)
	add_child(_seal)
	move_child(_seal, 0)
	if timeline.book != &"frost": return
	_ice_seed = hash(Vector3(timeline.center.x, timeline.center.y, get_instance_id()))
	ice = IcePatch.new()
	add_child(ice)
	_ice_light = preload("res://ui/scenes/ultimate_ice_light.tscn").instantiate() as PointLight2D
	_ice_light.height = timeline.radius * .5
	_ice_light.texture_scale = timeline.radius * 4.0 / 128.0
	add_child(_ice_light)
	budget.register_light(_ice_light, 1)


func sync_frame(world_size: Vector2, detail: int, less_motion: bool, fire_fallback: bool = false) -> void:
	size = Vector2.ONE * timeline.radius * 2.5
	position = timeline.center * world_size - size * 0.5
	_seal.position = size * .5
	_seal.scale = Vector2.ONE * timeline.radius * 2.0 / _seal.texture.get_width()
	_seal.modulate = Color(1,1,1,.028 * smoothstep(0.0, .24, timeline.age) * smoothstep(0.0, .7, timeline.lifetime - timeline.age))
	(_seal.material as ShaderMaterial).set_shader_parameter("clock", 0.0 if less_motion else timeline.age)
	_surface.set_shader_parameter("age", timeline.age)
	_surface.set_shader_parameter("lifetime", timeline.lifetime)
	_surface.set_shader_parameter("motion", 0.0 if less_motion else 1.0)
	_surface.set_shader_parameter("detail", float(detail) / 2.0)
	_surface.set_shader_parameter("fire_fallback", fire_fallback)
	if ice != null:
		var fade := smoothstep(0.0,.6,timeline.lifetime-timeline.age)
		ice.sync_patch(size*.5,timeline.radius,timeline.age,fade,detail,less_motion,_ice_seed)
		_ice_light.position = size*.5 + Vector2(-.32,-.24)*timeline.radius
		_ice_light.energy = 1.4*fade*smoothstep(0.0,.45,timeline.age)
		_ice_light.visible = detail > 0
