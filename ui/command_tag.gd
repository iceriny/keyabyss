class_name CommandTag
extends Label
## Visible word-command label shared by fields, toggles and selectors.

var word: String

static func create(value: String) -> CommandTag:
	var tag := CommandTag.new()
	tag.word = value
	tag.text = value
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_override("font", preload("res://assets/fonts/jinghua-song.ttf"))
	tag.add_theme_font_size_override("font_size", 13)
	tag.set_command_prefix("")
	return tag

func _ready() -> void:
	add_to_group("word_command_tags")

func set_command_prefix(prefix: String) -> void:
	var matched := not prefix.is_empty() and word.begins_with(prefix)
	add_theme_color_override("font_color", Color("f3dcaa") if matched else Color("9aa8ac"))
