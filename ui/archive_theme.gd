class_name ArchiveTheme
extends RefCounted

static func create(accent: Color) -> Theme:
	var result := preload("res://ui/theme/keyabyss.tres").duplicate(true) as Theme
	apply_accent(result, accent)
	return result


static func apply_accent(result: Theme, accent: Color) -> void:
	# The book accent belongs to state cues; shared metal stays warm gold.
	result.set_block_signals(true)
	result.set_color("accent", "Archive", accent)
	var bright := accent.lerp(Color.WHITE, 0.45)
	for type: String in ["LineEdit", "TextEdit"]:
		result.set_color("caret_color", type, bright)
		result.set_color("selection_color", type, Color(accent, 0.3))
	result.set_block_signals(false)
	result.emit_changed()
