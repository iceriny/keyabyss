class_name ProseDecoration
extends Control
## The original Label keeps sizing and shaped-character hit testing. A native
## rich-text child supplies color; this child supplies the glossary's dashed ink.

const VALUE_COLOR := Color("f1c982")
static var _numbers := RegEx.create_from_string("[+−-]?[0-9]+(?:\\.[0-9]+)?(?:%|％)?")
var source: Label
var underline_terms := true
var _rich: RichTextLabel
var _last_text := ""
var _terms: Array[RegExMatch] = []
var _dirty := true


static func attach(label: Label, terms: bool = true) -> ProseDecoration:
	if label.has_node("ProseDecoration"): return label.get_node("ProseDecoration") as ProseDecoration
	var decoration := ProseDecoration.new()
	decoration.name = "ProseDecoration"
	decoration.source = label
	decoration.underline_terms = terms
	label.add_child(decoration)
	return decoration


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rich = RichTextLabel.new()
	_rich.name = "ColoredText"
	_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich.focus_mode = Control.FOCUS_NONE
	_rich.scroll_active = false
	_rich.clip_contents = false
	_rich.bbcode_enabled = false
	_rich.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_child(_rich)
	_rich.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source.resized.connect(_invalidate)
	source.theme_changed.connect(_invalidate)
	_sync()


func _invalidate() -> void:
	_dirty = true
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	if _last_text != source.text or _dirty: _sync()


func _sync() -> void:
	_dirty = false
	_last_text = source.text
	_terms.clear()
	if underline_terms: _terms = GameTerms.matches(source.text)
	var matches := _numbers.search_all(source.text)
	_rich.visible = not matches.is_empty()
	source.self_modulate.a = 0.0 if _rich.visible else 1.0
	if _rich.visible:
		_rich.horizontal_alignment = source.horizontal_alignment
		_rich.vertical_alignment = source.vertical_alignment
		_rich.autowrap_mode = source.autowrap_mode
		_rich.add_theme_font_override("normal_font", source.get_theme_font("font"))
		_rich.add_theme_font_size_override("normal_font_size", source.get_theme_font_size("font_size"))
		_rich.add_theme_color_override("default_color", source.get_theme_color("font_color"))
		_rich.add_theme_color_override("font_shadow_color", source.get_theme_color("font_shadow_color"))
		_rich.add_theme_color_override("font_outline_color", source.get_theme_color("font_outline_color"))
		for key in ["shadow_offset_x", "shadow_offset_y", "outline_size", "line_spacing"]:
			_rich.add_theme_constant_override(key, source.get_theme_constant(key))
		_rich.add_theme_constant_override("paragraph_separation", source.get_theme_constant("line_spacing"))
		_rich.clear()
		var cursor := 0
		for found in matches:
			_rich.add_text(source.text.substr(cursor, found.get_start() - cursor))
			_rich.push_color(VALUE_COLOR)
			_rich.add_text(found.get_string())
			_rich.pop()
			cursor = found.get_end()
		_rich.add_text(source.text.substr(cursor))
	queue_redraw()


func _draw() -> void:
	var tint := source.get_theme_color("font_color")
	tint.a *= 0.65
	for term in _terms:
		var row := Rect2()
		for index in range(term.get_start(), term.get_end()):
			var bounds := source.get_character_bounds(index)
			if bounds.size.x <= 0.0: continue
			if row.has_area() and not is_equal_approx(bounds.position.y, row.position.y):
				_dash(row, tint)
				row = Rect2()
			row = row.merge(bounds) if row.has_area() else bounds
		if row.has_area(): _dash(row, tint)


func _dash(bounds: Rect2, tint: Color) -> void:
	var y := bounds.end.y - 1.0
	var x := bounds.position.x
	while x < bounds.end.x:
		draw_line(Vector2(x, y), Vector2(minf(x + 3.0, bounds.end.x), y), tint, 1.0, true)
		x += 5.0
