@tool
class_name CrystalInlay
extends TextureRect
## A single optical layer: embedded gold, refracted scenery and surface light.

@export var backdrop_gain: float = 0.06
@export var control_surface: bool = false
var reduced_motion := false
var clock := 0.0
var activity := 0.0
var pulse := 0.0
var glass: ShaderMaterial
var host_hovered := false
var pointer_uv := Vector2(0.5, 0.5)
var filaments: GoldFilaments
var motif_seed: int = 0


static func decorate(control: Control, reduced: bool, on_page: bool) -> void:
	if control.has_node("CrystalInlay"):
		return
	var inlay := load("res://ui/scenes/crystal_inlay.tscn").instantiate() as CrystalInlay
	inlay.name = "CrystalInlay"
	inlay.control_surface = true
	inlay.backdrop_gain = 0.06 if on_page else 0.45
	inlay.reduced_motion = reduced
	inlay.motif_seed = hash(str(control.get_meta("word_command", control.name)))
	inlay.show_behind_parent = true
	control.add_child(inlay)
	inlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inlay.offset_left = -8
	inlay.offset_right = 8
	inlay.offset_top = -12
	inlay.offset_bottom = 16
	control.mouse_entered.connect(func() -> void:
		inlay.host_hovered = true
		inlay.filaments.trigger_flow()
	)
	control.mouse_exited.connect(func() -> void: inlay.host_hovered = false)
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			inlay.pointer_uv = (event.position - inlay.position) / inlay.size
	)
	if control is CheckButton:
		control.toggled.connect(func(_enabled: bool) -> void: inlay.flash())
	elif control is OptionButton:
		control.item_selected.connect(func(_index: int) -> void: inlay.flash())
	elif control is BaseButton:
		control.pressed.connect(inlay.flash)
	if control is LineEdit:
		control.text_changed.connect(func(_text: String) -> void: inlay.flash())


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass = material.duplicate() as ShaderMaterial
	material = glass
	glass.set_shader_parameter("backdrop_gain", backdrop_gain)
	glass.set_shader_parameter("control_surface", control_surface)
	var light_seed := motif_seed if control_surface else hash(texture.resource_path)
	glass.set_shader_parameter("phase", float(posmod(light_seed, 997)) / 997.0)
	if control_surface:
		filaments = GoldFilaments.new()
		filaments.name = "GoldFilaments"
		filaments.show_behind_parent = true
		add_child(filaments)
		resized.connect(_shape_filaments)
		_shape_filaments()
	add_to_group("crystal_motion_controls")
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()
	set_motion_reduced(reduced_motion)


func _shape_filaments() -> void:
	if size.x < 30.0 or size.y < 20.0:
		return # Containers have not assigned their first drawable size yet.
	filaments.configure(size, motif_seed)
	glass.set_shader_parameter("canvas_size", size)
	glass.set_shader_parameter("spine_heights", filaments.spine_heights)


func set_motion_reduced(value: bool) -> void:
	reduced_motion = value
	if glass != null:
		glass.set_shader_parameter("clock", 0.0 if value else clock)
	if filaments != null:
		filaments.ribbon.set_shader_parameter("motion_enabled", not value)


func flash() -> void:
	pulse = 1.0
	if filaments != null:
		filaments.trigger_flow()


func _visibility_changed() -> void:
	set_process(is_visible_in_tree() and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	var pointer := pointer_uv if control_surface else get_local_mouse_position() / size.max(Vector2.ONE)
	var hovered := host_hovered if control_surface else Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	var target := 1.0 if hovered else 0.0
	activity = target if reduced_motion else lerpf(activity, target, 1.0 - exp(-delta * 9.0))
	pulse = 0.0 if reduced_motion else maxf(0.0, pulse - delta * 1.8)
	if not reduced_motion:
		clock += delta
	glass.set_shader_parameter("clock", 0.0 if reduced_motion else clock)
	glass.set_shader_parameter("activity", activity)
	glass.set_shader_parameter("pulse", pulse)
	glass.set_shader_parameter("light_center", pointer.clamp(Vector2.ZERO, Vector2.ONE))
	if filaments != null:
		filaments.ribbon.set_shader_parameter("clock", clock)
		filaments.ribbon.set_shader_parameter("activity", activity)
		filaments.ribbon.set_shader_parameter("pulse", pulse)
