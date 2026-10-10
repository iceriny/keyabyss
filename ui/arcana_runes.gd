class_name ArcanaRunes
extends RefCounted
## Authored source: docs/art/Arcana384. Imported textures are shared on the GPU.

const ATLAS: Texture2D = preload("res://assets/art/runes/arcana-atlas.svg")
const ROOTS := "存生灭始终命时循复空域光力水火电雷风灵凝冷热流聚散击反护全形界能"
const SEALS := {
	&"frost": [preload("res://assets/art/runes/frost-seal-small.svg"), preload("res://assets/art/runes/frost-seal-medium.svg"), preload("res://assets/art/runes/frost-seal.svg")],
	&"flame": [preload("res://assets/art/runes/flame-seal-small.svg"), preload("res://assets/art/runes/flame-seal-medium.svg"), preload("res://assets/art/runes/flame-seal.svg")],
	&"storm": [preload("res://assets/art/runes/storm-seal-small.svg"), preload("res://assets/art/runes/storm-seal-medium.svg"), preload("res://assets/art/runes/storm-seal.svg")],
	&"spirit": [preload("res://assets/art/runes/spirit-seal-small.svg"), preload("res://assets/art/runes/spirit-seal-medium.svg"), preload("res://assets/art/runes/spirit-seal.svg")],
}


static func seal(book: StringName, diameter: float) -> Texture2D:
	return SEALS[book][0 if diameter <= 160.0 else (1 if diameter <= 480.0 else 2)]


static func draw(surface: CanvasItem, root: String, center: Vector2, diameter: float, tint: Color) -> void:
	var index := ROOTS.find(root)
	var source := Rect2(Vector2(index % 8, floori(index / 8.0)) * 128.0, Vector2.ONE * 128.0)
	surface.draw_texture_rect_region(ATLAS, Rect2(center - Vector2.ONE * diameter * .5, Vector2.ONE * diameter), source, tint)
