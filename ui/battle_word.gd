class_name BattleWord
extends Control
## A measured word, optional two-line meaning and a shared feathered reading layer.

const FONT: FontFile = preload("res://assets/fonts/jinghua-song.ttf")
const MEANING_SIZE := 14
const MEANING_WIDTH := 240.0
const MEANING_LINE_HEIGHT := 19.0

@onready var word_label: RichTextLabel = $Word
@onready var meaning_label: Label = $Meaning
@onready var backdrop: ColorRect = $Backdrop
var meaning_lines := PackedStringArray()
var _display_word := ""
var _meaning := ""
var _show_meaning := false
var _selected := false
var _selection_weight := 0.0
var _font_size := 24
var _row_height := 34.0
var _surface: ShaderMaterial
var _trait := ""
var _marked_positions: PackedInt32Array = []


func _ready() -> void:
	_surface = backdrop.material.duplicate() as ShaderMaterial
	backdrop.material = _surface


func configure(display_word: String, meaning: String, show_meaning: bool, selected: bool, boundary: int, reduced_motion: bool, feature_text: String = "", marks: PackedInt32Array = []) -> void:
	_selected = selected
	if reduced_motion:
		_selection_weight = 1.0 if selected else 0.0
	_marked_positions = marks
	if _display_word != display_word or _meaning != meaning or _show_meaning != show_meaning or _trait != feature_text:
		_display_word = display_word
		_meaning = meaning
		_show_meaning = show_meaning
		_trait = feature_text
		_measure()
	word_label.text = "[center][color=#79d5b9]%s[/color][color=#f8e3ab]%s[/color][/center]" % [display_word.left(boundary), display_word.substr(boundary)] if selected else "[center][color=#b7c4c8]%s[/color][/center]" % display_word
	var word_width := FONT.get_string_size(display_word, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var accepted_width := FONT.get_string_size(display_word.left(boundary), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var next_width := FONT.get_string_size(display_word.substr(boundary, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	_surface.set_shader_parameter("cursor_start", (size.x-word_width)*0.5+accepted_width)
	_surface.set_shader_parameter("cursor_width", next_width if selected else 0.0)
	_update_selection()
	queue_redraw()


func _measure() -> void:
	_font_size = clampi(floori(430.0 / maxi(1, _display_word.length())), 18, 24)
	_row_height = _font_size + 10.0
	word_label.add_theme_font_size_override("normal_font_size", _font_size)
	meaning_lines.clear()
	if _show_meaning:
		var remaining := " ".join(_meaning.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ", false))
		for row in 2:
			if remaining.is_empty():
				break
			var line := ""
			while not remaining.is_empty() and FONT.get_string_size(line+remaining[0], HORIZONTAL_ALIGNMENT_LEFT, -1, MEANING_SIZE).x <= MEANING_WIDTH:
				line += remaining[0]
				remaining = remaining.substr(1)
			if row == 1 and not remaining.is_empty():
				while FONT.get_string_size(line+"…", HORIZONTAL_ALIGNMENT_LEFT, -1, MEANING_SIZE).x > MEANING_WIDTH:
					line = line.left(-1)
				line += "…"
			meaning_lines.append(line.strip_edges())
	var width := maxf(70.0, FONT.get_string_size(_display_word, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x + 24.0)
	for line in meaning_lines:
		width = maxf(width, FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, MEANING_SIZE).x + 24.0)
	if not _trait.is_empty(): width = maxf(width, FONT.get_string_size(_trait, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24)
	size = Vector2(width, _row_height + (meaning_lines.size()*MEANING_LINE_HEIGHT+5.0 if not meaning_lines.is_empty() else 0.0))
	if not _trait.is_empty(): size.y += 21
	word_label.size = Vector2(width, _row_height)
	meaning_label.position = Vector2(0.0, _row_height+4.0)
	meaning_label.size = Vector2(width, meaning_lines.size()*MEANING_LINE_HEIGHT)
	meaning_label.text = "\n".join(meaning_lines)
	meaning_label.visible = not meaning_lines.is_empty()
	_surface.set_shader_parameter("canvas_size", size+Vector2(24,18))
	_surface.set_shader_parameter("word_line_y", _row_height-2.0)


func _draw() -> void:
	if not _trait.is_empty():
		var width := FONT.get_string_size(_trait, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(FONT, Vector2((size.x - width) / 2, size.y - 3), _trait, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b5c8c1"))
	var word_width := FONT.get_string_size(_display_word, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	for letter_position in _marked_positions:
		var prefix := FONT.get_string_size(_display_word.left(letter_position - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var letter_width := FONT.get_string_size(_display_word.substr(letter_position - 1, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var center := Vector2((size.x - word_width) / 2 + prefix + letter_width / 2, _row_height - 2)
		draw_line(center - Vector2(letter_width * 0.4, 0), center + Vector2(letter_width * 0.4, 0), Color("d5bc7d"), 2.0, true)


func _process(delta: float) -> void:
	_selection_weight = lerpf(_selection_weight, 1.0 if _selected else 0.0, 1.0-exp(-delta*12.0))
	_update_selection()


func _update_selection() -> void:
	meaning_label.modulate = Color("8b9e9f").lerp(Color("c6bba4"), _selection_weight)
	_surface.set_shader_parameter("selection", _selection_weight)
