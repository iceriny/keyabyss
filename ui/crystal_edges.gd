class_name CrystalEdges
extends ColorRect
## Large cropped folds over the HDR scenery, underneath all text and warnings.

@export var battle := false
var reduced_motion := false
var clock := 0.0


func _ready() -> void:
	(material as ShaderMaterial).set_shader_parameter("screen_tex", ($"../World" as SubViewport).get_texture())
	add_to_group("crystal_motion_controls")
	resized.connect(_layout)
	_layout()


func configure(quality: int, reduce: bool, accent: Color) -> void:
	reduced_motion = reduce
	var optical := material as ShaderMaterial
	optical.set_shader_parameter("quality", quality)
	var tint := Color("94b7be").lerp(accent, 0.24).srgb_to_linear()
	optical.set_shader_parameter("cold_tint", Vector3(tint.r, tint.g, tint.b))


func set_motion_reduced(value: bool) -> void:
	reduced_motion = value


func _process(delta: float) -> void:
	if is_visible_in_tree() and not reduced_motion:
		clock += delta
		(material as ShaderMaterial).set_shader_parameter("clock", clock)


func _layout() -> void:
	var optical := material as ShaderMaterial
	var span := maxf(size.x * 1.35, size.y * 2.0)
	optical.set_shader_parameter("canvas_size", size)
	optical.set_shader_parameter("art_a", Vector4(-span * 0.21, size.y - span * 0.42, span, span * 0.5625))
	optical.set_shader_parameter("art_b", Vector4(size.x - span * 0.80, -span * 0.17, span, span * 0.5625))
	optical.set_shader_parameter("edge_width", Vector2(0.11, 0.11) if battle else Vector2(0.26, 0.23))
	optical.set_shader_parameter("edge_opacity", 0.18 if battle else 0.36)
