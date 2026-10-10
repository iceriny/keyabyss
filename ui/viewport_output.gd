@tool
extends TextureRect
## Resolve relative to the output node, including when the stage is instanced.
@export_node_path("SubViewport") var viewport_path := NodePath("../World")

func _ready() -> void:
	texture = (get_node(viewport_path) as SubViewport).get_texture()
