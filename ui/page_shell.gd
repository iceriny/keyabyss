class_name PageShell
extends Control

const SMALL_FONT = preload("res://assets/fonts/jinghua-song.ttf")

var body: VBoxContainer
var footer: HBoxContainer
var status: Label
var command_hint: Label
var scroll: ScrollContainer
var close_button: Button
var panel: MarginContainer
var panel_width: float = 760.0
var compact_height: float = 0.0
var layout_pending: bool = false
var reduced_motion: bool = false
var arrival: float = 0.0
var closing: bool = false
var content_layer: Control
var wash: ColorRect
var accent := Color("8bdeff")
var seal_texture: Texture2D = preload("res://assets/art/runes/frost-seal.svg")
var heading: Label
var subtitle_label: Label
var pattern: TextureRect


static func create(title: String = "", subtitle: String = "") -> PageShell:
	var scene := load("res://ui/scenes/page_shell.tscn") as PackedScene
	var page := scene.instantiate() as PageShell
	page.configure(title, subtitle)
	return page


func configure(title: String, subtitle: String) -> void:
	_bind_nodes()
	heading.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	heading.add_theme_color_override("font_color", Color("f0ddae"))
	pattern.modulate = Color(accent, pow(.12, 2.2))


func _bind_nodes() -> void:
	if body != null:
		return
	content_layer = $ContentLayer
	wash = $Wash
	panel = $ContentLayer/Panel
	pattern = $ContentLayer/Pattern
	heading = $ContentLayer/Panel/Layout/Header/Heading
	close_button = $ContentLayer/Panel/Layout/Header/CloseButton
	subtitle_label = $ContentLayer/Panel/Layout/Subtitle
	scroll = $ContentLayer/Panel/Layout/BodyRegion/BodyScroll
	body = $ContentLayer/Panel/Layout/BodyRegion/BodyScroll/ContentMargin/Body
	status = $ContentLayer/Panel/Layout/Status
	footer = $ContentLayer/Panel/Layout/Footer
	command_hint = $ContentLayer/Panel/Layout/CommandHint
	resized.connect(_layout_panel)
	panel.minimum_size_changed.connect(_schedule_layout)
	body.minimum_size_changed.connect(_schedule_layout)


func _ready() -> void:
	_bind_nodes()
	wash.material = wash.material.duplicate()
	heading.add_theme_color_override("font_color", Color("f0ddae"))
	pattern.texture = seal_texture
	pattern.modulate = Color(accent, pow(.12, 2.2))
	_layout_panel()
	_schedule_layout()
	(scroll as SmoothScroll).set_motion_reduced(reduced_motion)
	$ContentLayer/GoldBranch.set_motion_reduced(reduced_motion)
	$ContentLayer/GoldDivider.set_motion_reduced(reduced_motion)


func set_accent(value: Color) -> void:
	accent = value
	heading.add_theme_color_override("font_color", Color("f0ddae"))
	pattern.modulate = Color(accent, pow(.12, 2.2))


func _process(delta: float) -> void:
	if closing:
		return
	arrival += delta
	var progress := 1.0 if reduced_motion else MotionCurve.cubic(arrival/.4,Vector2(0,0),Vector2(.58,1))
	content_layer.modulate.a = progress
	# The annotation fades into place; the title and action baseline never move.
	content_layer.position.y = 0.0
	wash.modulate.a = progress
	(wash.material as ShaderMaterial).set_shader_parameter("light_center", get_local_mouse_position() / size)
	(wash.material as ShaderMaterial).set_shader_parameter("clock", 0.0 if reduced_motion else arrival)


func dismiss() -> void:
	closing = true
	for node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(content_layer,"modulate:a",0.,.01 if reduced_motion else .18)
	tween.tween_property(wash,"modulate:a",0.,.01 if reduced_motion else .18)
	tween.chain().tween_callback(queue_free)


func _schedule_layout() -> void:
	if layout_pending:
		return
	layout_pending = true
	call_deferred("_finish_layout")


func _finish_layout() -> void:
	layout_pending = false
	_layout_panel()


func set_width(value: float) -> void:
	panel_width = value
	_layout_panel()


func _layout_panel() -> void:
	var width := minf(panel_width, size.x - 128)
	var height := minf(compact_height, size.y-110) if compact_height > 0.0 else size.y-110
	panel.position = Vector2((size.x - width) * .5, (size.y-height)*0.5 if compact_height > 0.0 else 26.0)
	panel.size = Vector2(width, height)
	pattern.position = panel.position + Vector2(-25,-40)
	$ContentLayer/GoldBranch.position = panel.position + Vector2(width * 0.3, -8)
	$ContentLayer/GoldBranch.size = Vector2(380, 142.5)
	$ContentLayer/GoldDivider.position = panel.position + Vector2(10, panel.size.y - 158)
	$ContentLayer/GoldDivider.size = Vector2(width - 20, 100)
	(wash.material as ShaderMaterial).set_shader_parameter("reading_rect", Vector4(panel.position.x/size.x, panel.position.y/size.y, width/size.x, panel.size.y/size.y))


static func label(parent: Node, text_value: String, font_size: int = 18, color: Color = Color("e8e4d8")) -> Label:
	var node := Label.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if font_size <= 28:
		node.add_theme_font_override("font", SMALL_FONT)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node


static func button(parent: Node, caption: String, callback: Callable) -> OpenButton:
	var node := OpenButton.new()
	node.text = caption
	node.pressed.connect(callback)
	parent.add_child(node)
	return node
