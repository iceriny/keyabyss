class_name OpenButton
extends Button

const SMALL_FONT: FontFile = preload("res://assets/fonts/jinghua-song.ttf")
const MUTED := Color("81918b")
const LIGHT_PADDING := 48.0
const CONTENT_PADDING := 12.0
@export var caption_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
@export var filament_extension: float = 0.0

var motion_reduced: bool = false
var selected_visual: bool = false
var _command_word: String = ""
var _command_prefix: String = ""
var _command_badge: HBoxContainer
var _prefix_label: Label
var _suffix_label: Label
var _caption_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
var _base_minimum_width: float = 0.0
var _line_progress: float = 0.0
var _press_flash: float = 0.0
var _held: bool = false
var _light: ColorRect
var _light_material: ShaderMaterial
var _gold: GoldFilaments
var _gold_clock := 0.0


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	add_to_group("open_motion_controls")
	_caption_alignment = caption_alignment
	alignment = caption_alignment
	_base_minimum_width = custom_minimum_size.x
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var clear := StyleBoxEmpty.new()
		clear.content_margin_left = CONTENT_PADDING
		clear.content_margin_right = CONTENT_PADDING
		clear.content_margin_top = 7
		clear.content_margin_bottom = 7
		add_theme_stylebox_override(state, clear)
	_light = ColorRect.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.show_behind_parent = true
	_light_material = ShaderMaterial.new()
	_light_material.shader = preload("res://ui/materials/open_button_light.gdshader")
	_light.material = _light_material
	add_child(_light)
	_gold = GoldFilaments.new()
	_gold.name = "GoldFilaments"
	_light.add_child(_gold)
	resized.connect(_sync_light_layout)
	theme_changed.connect(_sync_light_theme)
	_sync_light_layout()
	_sync_light_theme()
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 40.0
	if not has_theme_font_size_override("font_size"):
		add_theme_font_size_override("font_size", 16)
	_sync_light_text()
	var parts := text.split("    ", false, 1)
	if parts.size() == 2:
		text = parts[0]
		_command_word = parts[1].to_lower()
	if not _command_word.is_empty():
		_ensure_badge()
	resized.connect(_layout_badge)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sync_light_text()
	mouse_entered.connect(_refresh_state)
	mouse_entered.connect(_gold.trigger_flow)
	mouse_exited.connect(_refresh_state)
	button_down.connect(func() -> void:
		_held = true
		_press_flash = 1.0
		_gold.trigger_flow()
		_refresh_state()
	)
	button_up.connect(func() -> void:
		_held = false
		_refresh_state()
	)


func set_motion_reduced(value: bool) -> void:
	motion_reduced = value
	if value:
		_line_progress = 1.0 if _is_active() else 0.0
		_press_flash = 0.0
	_sync_light_state()


func set_selected_visual(value: bool) -> void:
	selected_visual = value
	_refresh_state()


func set_caption(value: String) -> void:
	text = value
	if _command_badge != null:
		_layout_badge()
	else:
		_sync_light_text()


func set_command_word(value: String) -> void:
	_command_word = value.to_lower()
	if not is_node_ready():
		return
	if _command_word.is_empty():
		if _command_badge != null:
			_command_badge.queue_free()
			_command_badge = null
			_prefix_label = null
			_suffix_label = null
		alignment = _caption_alignment
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			get_theme_stylebox(state).content_margin_left = CONTENT_PADDING
		custom_minimum_size.x = _base_minimum_width
		_sync_light_text()
	else:
		_ensure_badge()
	_refresh_state()


func set_command_prefix(value: String) -> void:
	_command_prefix = value.to_lower()
	_update_badge()
	_refresh_state()


func _make_badge_label(color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", SMALL_FONT)
	label.add_theme_font_size_override("font_size", maxi(10, roundi(float(get_theme_font_size("font_size")) * 0.75)))
	label.add_theme_color_override("font_color", color)
	return label


func _ensure_badge() -> void:
	if _command_badge == null:
		_command_badge = HBoxContainer.new()
		_command_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_command_badge.add_theme_constant_override("separation", 0)
		add_child(_command_badge)
		_prefix_label = _make_badge_label(get_theme_color("accent", "Archive"))
		_suffix_label = _make_badge_label(MUTED)
		_command_badge.add_child(_prefix_label)
		_command_badge.add_child(_suffix_label)
		alignment = HORIZONTAL_ALIGNMENT_LEFT
	_update_badge()
	call_deferred("_layout_badge")


func _update_badge() -> void:
	if _command_badge == null:
		return
	var matched := not _command_prefix.is_empty() and _command_word.begins_with(_command_prefix)
	_prefix_label.text = _command_prefix if matched else ""
	_suffix_label.text = _command_word.substr(_command_prefix.length()) if matched else _command_word
	_layout_badge()


func _layout_badge() -> void:
	if _command_badge == null:
		return
	var caption_width := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
	var badge_size := _command_badge.get_combined_minimum_size()
	var icon_width := 0.0
	if icon != null:
		icon_width = icon.get_width() + get_theme_constant("h_separation")
	var group_width := icon_width + caption_width + 20.0 + badge_size.x
	custom_minimum_size.x = maxf(_base_minimum_width, group_width + CONTENT_PADDING * 2.0)
	var content_left := CONTENT_PADDING
	if _caption_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		content_left = maxf(CONTENT_PADDING, (size.x - group_width) * 0.5)
	elif _caption_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		content_left = maxf(CONTENT_PADDING, size.x - group_width - CONTENT_PADDING)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		get_theme_stylebox(state).content_margin_left = content_left
	_command_badge.position = Vector2(content_left + icon_width + caption_width + 20.0, maxf(0.0, (size.y - badge_size.y) * 0.5))
	_sync_light_text()


func _is_active() -> bool:
	return not disabled and (selected_visual or is_hovered() or _held or (not _command_prefix.is_empty() and _command_word.begins_with(_command_prefix)))


func _refresh_state() -> void:
	if motion_reduced:
		_line_progress = 1.0 if _is_active() else 0.0
	_sync_light_state()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not motion_reduced:
		_gold_clock += delta
		_gold.ribbon.set_shader_parameter("clock", _gold_clock)
	var target := 1.0 if _is_active() else 0.0
	var before := _line_progress
	var flash_before := _press_flash
	if motion_reduced:
		_line_progress = target
		_press_flash = 0.0
	else:
		_line_progress = lerpf(_line_progress, target, 1.0 - pow(0.01, delta / 0.4))
		if absf(_line_progress - target) < 0.005:
			_line_progress = target
		_press_flash = maxf(0.0, _press_flash - delta / 0.18)
	if before != _line_progress or flash_before != _press_flash:
		_sync_light_state()


func _sync_light_state() -> void:
	if _light_material == null:
		return
	_light_material.set_shader_parameter("activity", _line_progress)
	_light_material.set_shader_parameter("selection", 1.0 if selected_visual else 0.0)
	_light_material.set_shader_parameter("press", _press_flash)
	_gold.ribbon.set_shader_parameter("activity", _line_progress)
	_gold.ribbon.set_shader_parameter("pulse", _press_flash)
	_gold.ribbon.set_shader_parameter("motion_enabled", not motion_reduced)


func _sync_light_layout() -> void:
	_light.position = Vector2.ONE * -LIGHT_PADDING
	_light.size = size + Vector2.ONE * LIGHT_PADDING * 2.0
	_light_material.set_shader_parameter("canvas_size", _light.size)
	_sync_light_text()


func _sync_light_text() -> void:
	if _light_material == null:
		return
	var content_left := get_theme_stylebox("normal").get_content_margin(SIDE_LEFT)
	var content_right := size.x - get_theme_stylebox("normal").get_content_margin(SIDE_RIGHT)
	if icon != null:
		content_left += icon.get_width() + get_theme_constant("h_separation")
	var text_width := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
	var text_left := content_left
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		text_left = content_left + maxf(0.0, (content_right - content_left - text_width) * 0.5)
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		text_left = maxf(content_left, content_right - text_width)
	var text_right := text_left + text_width
	if _command_badge != null:
		text_right = maxf(text_right, _command_badge.position.x + _command_badge.get_combined_minimum_size().x)
	_light_material.set_shader_parameter("text_center_x", LIGHT_PADDING + (text_left + text_right) * 0.5)
	_light_material.set_shader_parameter("text_half_width", maxf(12.0, (text_right - text_left) * 0.5))
	_gold.position = Vector2(LIGHT_PADDING + text_left - 12.0 - filament_extension, _light.size.y - 81.0)
	_gold.configure(Vector2(maxf(48.0, text_right - text_left + 24.0 + filament_extension * 2.0), 40.0), hash(_command_word if not _command_word.is_empty() else text))


func _sync_light_theme() -> void:
	_light_material.set_shader_parameter("accent", get_theme_color("accent", "Archive"))
	_sync_light_text()
	if _prefix_label != null:
		_prefix_label.add_theme_color_override("font_color", get_theme_color("accent", "Archive"))
