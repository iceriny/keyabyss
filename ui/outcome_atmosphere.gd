class_name OutcomeAtmosphere
extends ColorRect

var victory := false
var reduced_motion := false
var elapsed := 0.0


func _ready() -> void:
	material = material.duplicate()
	(material as ShaderMaterial).set_shader_parameter("victory", victory)
	(material as ShaderMaterial).set_shader_parameter("tint", Color("dfc58b") if victory else Color("d58f83"))
	(material as ShaderMaterial).set_shader_parameter("reduced_motion", reduced_motion)
	resized.connect(func() -> void: (material as ShaderMaterial).set_shader_parameter("canvas_size", size))
	(material as ShaderMaterial).set_shader_parameter("canvas_size", size)


func _process(delta: float) -> void:
	elapsed += delta
	(material as ShaderMaterial).set_shader_parameter("clock", elapsed)
	if elapsed >= 4.0:
		set_process(false)
