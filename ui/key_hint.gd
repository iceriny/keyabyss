@tool
class_name KeyHint
extends HBoxContainer

const SMALL_FONT: FontFile = preload("res://assets/fonts/jinghua-song.ttf")
const SCENE_PATH := "res://ui/scenes/key_hint.tscn"

@export var key_text := "Tab":
	set(value):
		if key_text == value:
			return
		key_text = value
		_refresh()
@export var description := "切换目标":
	set(value):
		if description == value:
			return
		description = value
		_refresh()
@export var accent := Color("84969e"):
	set(value):
		if accent == value:
			return
		accent = value
		_refresh()

@onready var _key_frame: PanelContainer = $KeyFrame
@onready var _key_label: Label = $KeyFrame/Key
@onready var _description_label: Label = $Description


static func create(key: String, caption: String, color: Color = Color("84969e")) -> KeyHint:
	var hint := (load(SCENE_PATH) as PackedScene).instantiate() as KeyHint
	hint.key_text = key
	hint.description = caption
	hint.accent = color
	return hint


static func create_row(items: Array[Dictionary], color: Color = Color("84969e")) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	for item: Dictionary in items:
		row.add_child(create(str(item["key"]), str(item["description"]), color))
	return row


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_key_label.text = key_text
	_description_label.text = description
	_description_label.visible = not description.is_empty()
	_key_label.add_theme_font_override("font", SMALL_FONT)
	_description_label.add_theme_font_override("font", SMALL_FONT)
	_key_label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.52))
	_description_label.add_theme_color_override("font_color", Color("b8c3bd"))
	var frame := _key_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	frame.border_color = Color(accent, 0.56)
	frame.bg_color = Color("101820", 0.24)
	_key_frame.add_theme_stylebox_override("panel", frame)
