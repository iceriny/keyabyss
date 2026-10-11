class_name PopupCrystal
extends Control
## Optical backing for the native PopupMenu; item navigation and scrolling stay native.

var reduced_motion := false
var clock := 0.0
var popup: PopupMenu


static func decorate(control: OptionButton, reduced: bool) -> void:
	var menu := control.get_popup()
	if menu.has_node("PopupCrystal"):
		return
	# Popup windows otherwise render this shared linear material as SDR.
	menu.use_hdr_2d = control.get_viewport().use_hdr_2d
	var surface := load("res://ui/scenes/popup_crystal.tscn").instantiate() as PopupCrystal
	surface.reduced_motion = reduced
	menu.add_child(surface)
	var update_limit := func() -> void:
		var display_scale := control.get_global_transform().get_scale().y
		menu.max_size = Vector2i(roundi(control.get_viewport_rect().size.x), roundi(minf(420.0 * display_scale, control.get_viewport_rect().size.y * 0.65)))
		menu.min_size.x = maxi(menu.min_size.x, roundi(160.0 * display_scale))
		menu.size.x = maxi(menu.size.x, menu.min_size.x)
		# PopupMenu computes its wrapping minimum before about_to_popup.
		menu.min_size.y = mini(menu.min_size.y, menu.max_size.y)
		menu.size.y = mini(menu.size.y, menu.max_size.y)
	update_limit.call()
	menu.about_to_popup.connect(update_limit)


func _ready() -> void:
	popup = get_parent() as PopupMenu
	$Depth.material = $Depth.material.duplicate()
	popup.size_changed.connect(_layout)
	popup.visibility_changed.connect(_visibility_changed)
	add_to_group("crystal_motion_controls")
	_layout()
	set_motion_reduced(reduced_motion)
	_visibility_changed()


func _layout() -> void:
	size = Vector2(popup.size)
	($Depth.material as ShaderMaterial).set_shader_parameter("canvas_size", size)


func _visibility_changed() -> void:
	set_process(popup.visible)
	if popup.visible:
		clock = 0.0
		($Depth.material as ShaderMaterial).set_shader_parameter("arrival", 1.0 if reduced_motion else 0.0)


func set_motion_reduced(value: bool) -> void:
	reduced_motion = value


func _process(delta: float) -> void:
	clock += delta
	($Depth.material as ShaderMaterial).set_shader_parameter("arrival", 1.0 if reduced_motion else smoothstep(0.0,0.18,clock))
