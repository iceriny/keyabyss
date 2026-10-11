class_name RelicRewardChoice
extends MarginContainer

signal picked

var content: VBoxContainer
var definition: CombatContentDefinition
var catalog: BuildCatalog
var build: CompiledBuild
var reduced_motion := false
var shortcut := ""
var detail_mode := false
var keyboard_selected := false
var _summary := ""
var _details := ""
var _surface: ShaderMaterial
var _hover := 0.0
var _clock := 0.0


func _ready() -> void:
	_surface = $Wash.material.duplicate() as ShaderMaterial
	$Wash.material = _surface
	content = $Content
	var relic := definition as RelicDefinition
	var color: Color = ContentDescription.COLORS[str(relic.rarity)]
	_surface.set_shader_parameter("rarity_color", color)
	_surface.set_shader_parameter("awakening", relic.rarity == &"awakening")
	_surface.set_shader_parameter("signature", float(posmod(hash(relic.id), 101)) / 100.0)
	_surface.set_shader_parameter("school", ["frost", "flame", "storm", "spirit"].find(str(build.book())) if build != null else 0)
	$Content/ReadingArea/Pedestal/Glyph.definition = definition
	$Content/ReadingArea/Pedestal/Glyph.tint = color
	var owned := build.asset_stacks(relic.id) if build != null else 0
	$Content/Meta/Category.text = ContentDescription.RARITIES[str(relic.rarity)] + (" · 通用" if relic.allowed_books.is_empty() else " · 专属")
	$Content/Meta/Category.add_theme_color_override("font_color", color)
	$Content/Meta/Stack.text = "%d → %d 层" % [owned, owned + 1] if owned > 0 else "首层 · 上限 %d" % relic.max_stacks
	$Content/Title.text = definition.title
	_summary = ContentDescription.summary(relic, owned + 1)
	_details = ContentDescription.text(relic, catalog, build, true)
	$Content/ReadingArea/Reading.set_motion_reduced(reduced_motion)
	set_detail_mode(Input.is_physical_key_pressed(KEY_ALT))
	mouse_entered.connect(func() -> void: _hover = 1.0)
	mouse_exited.connect(func() -> void: _hover = 0.0)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			picked.emit())


func set_detail_mode(value: bool) -> void:
	detail_mode = value
	$Content/ReadingArea/Pedestal.visible = not value
	_surface.set_shader_parameter("details", value)
	$Content/ReadingArea/Reading/Description.text = _details if value else _summary
	$Content/ReadingArea/Reading/Description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if value else HORIZONTAL_ALIGNMENT_CENTER
	$Content/ReadingArea/Reading.scroll_vertical = 0


func set_keyboard_selected(value: bool) -> void:
	keyboard_selected = value
	$Content/Title.add_theme_color_override("font_color", Color("fff0c9") if value else Color("e9d5a4"))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event.keycode == KEY_ALT or event.physical_keycode == KEY_ALT) and not event.echo:
		set_detail_mode(event.pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready(): set_detail_mode(false)


func _process(delta: float) -> void:
	_clock += delta
	_surface.set_shader_parameter("clock", 0.0 if reduced_motion else _clock)
	# Pixel-sized facets stay around the glyph at every card height and UI scale.
	_surface.set_shader_parameter("canvas_size", $Wash.size)
	_surface.set_shader_parameter("glyph_center", ($Content/ReadingArea.position + $Content/ReadingArea/Pedestal.position + $Content/ReadingArea/Pedestal.size * 0.5) / content.size)
	_surface.set_shader_parameter("hover", maxf(_hover, 1.0 if keyboard_selected else 0.0))
	_surface.set_shader_parameter("selected", keyboard_selected)
