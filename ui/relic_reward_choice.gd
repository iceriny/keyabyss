class_name RelicRewardChoice
extends MarginContainer

signal picked

var content: VBoxContainer
var definition: CombatContentDefinition
var reduced_motion := false
var shortcut := ""
var _surface: ShaderMaterial
var _hover := 0.0
var _clock := 0.0


func _ready() -> void:
	_surface = $Wash.material as ShaderMaterial
	content = $Content
	$Content/Shortcut.visible = not shortcut.is_empty()
	$Content/Shortcut.text = shortcut
	$Content/Pedestal/Glyph.definition = definition
	$Content/Category.text = "演化遗物" if definition.replaces != &"" else "遗物"
	$Content/Title.text = definition.title
	$Content/Description.text = definition.description
	mouse_entered.connect(func() -> void: _hover = 1.0)
	mouse_exited.connect(func() -> void: _hover = 0.0)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			picked.emit())


func _process(delta: float) -> void:
	_clock += delta
	_surface.set_shader_parameter("clock", 0.0 if reduced_motion else _clock)
	_surface.set_shader_parameter("hover", _hover)
