class_name PageShell
extends Control

const SMALL_FONT = preload("res://assets/fonts/jinghua-song.ttf")
const READING_MATERIALS := {
	"settings": preload("res://ui/materials/open_crystal_settings.tres"),
	"guide": preload("res://ui/materials/open_crystal_guide.tres"),
	"words": preload("res://ui/materials/open_crystal_words.tres"),
}

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
var reading_style := ""
var _crystal_clock := 0.0
var entrance_ready := true
var _covered_page: PageShell
static var _scene: PackedScene


static func create(title: String = "", subtitle: String = "") -> PageShell:
	var started := DebugLog.begin()
	if _scene == null:
		_scene = load("res://ui/scenes/page_shell.tscn") as PackedScene
	DebugLog.end(&"page.load", started)
	started = DebugLog.begin()
	var page := _scene.instantiate() as PageShell
	DebugLog.end(&"page.instantiate", started)
	started = DebugLog.begin()
	page.configure(title, subtitle)
	DebugLog.end(&"page.configure", started)
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
	content_layer.modulate.a = 0.0
	wash.modulate.a = 0.0
	set_reading_style("settings", 2)
	heading.add_theme_color_override("font_color", Color("f0ddae"))
	pattern.texture = seal_texture
	pattern.modulate = Color(accent, pow(.12, 2.2))
	_layout_panel()
	_schedule_layout()
	(scroll as SmoothScroll).set_motion_reduced(reduced_motion)
	$ContentLayer/GoldBranch.set_motion_reduced(reduced_motion)
	$ContentLayer/GoldDivider.set_motion_reduced(reduced_motion)
	if get_parent() is PageShell:
		# Nested reading replaces the parent's material instead of blurring its
		# already softened output. The parent's capture still supplies the scene.
		_covered_page = get_parent() as PageShell
		_covered_page.wash.hide()
		_covered_page.content_layer.hide()
		$Capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED


func _exit_tree() -> void:
	if is_instance_valid(_covered_page) and not _covered_page.is_queued_for_deletion():
		_covered_page.wash.show()
		_covered_page.content_layer.show()


func set_accent(value: Color) -> void:
	accent = value
	heading.add_theme_color_override("font_color", Color("f0ddae"))
	pattern.modulate = Color(accent, pow(.12, 2.2))
	if not reading_style.is_empty():
		var tint := Color("94b7be").lerp(accent, 0.24).srgb_to_linear()
		(wash.material as ShaderMaterial).set_shader_parameter("cold_tint", Vector3(tint.r, tint.g, tint.b))


func _process(delta: float) -> void:
	if closing:
		return
	if entrance_ready: arrival += delta
	var progress := 0.0 if not entrance_ready else (1.0 if reduced_motion else MotionCurve.cubic(arrival/.4,Vector2(0,0),Vector2(.58,1)))
	content_layer.modulate.a = progress
	# The annotation fades into place; the title and action baseline never move.
	content_layer.position.y = 0.0
	wash.modulate.a = progress
	if not reading_style.is_empty():
		if not reduced_motion:
			_crystal_clock += delta
		(wash.material as ShaderMaterial).set_shader_parameter("clock", _crystal_clock)
	($CrystalSheets.material as ShaderMaterial).set_shader_parameter("arrival", progress)
	($CrystalSheets.material as ShaderMaterial).set_shader_parameter("clock", 0.0 if reduced_motion else arrival)


func dismiss() -> void:
	closing = true
	for node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(content_layer,"modulate:a",0.,.01 if reduced_motion else .18)
	tween.tween_property(wash,"modulate:a",0.,.01 if reduced_motion else .18)
	tween.tween_property($CrystalSheets.material,"shader_parameter/arrival",0.,.01 if reduced_motion else .18)
	tween.chain().tween_callback(queue_free)


func set_reading_style(route: String, quality: int) -> void:
	# One optical language, with compositions chosen for content density.
	reading_style = "settings"
	if route in ["words", "import", "history", "profile", "result", "route"]:
		reading_style = "words"
	elif route in ["guide", "tutorial", "relics", "build", "reward"]:
		reading_style = "guide"
	wash.material = READING_MATERIALS[reading_style].duplicate()
	$CrystalSheets.hide()
	$ContentLayer/GoldBranch.hide()
	$ContentLayer/GoldDivider.modulate.a = 0.32
	pattern.hide()
	set_accent(accent)
	if route == "calibration":
		(wash.material as ShaderMaterial).set_shader_parameter("background_transmission", 0.78)
		(wash.material as ShaderMaterial).set_shader_parameter("outer_transmission", 0.88)
	set_reading_quality(quality)
	_layout_panel()


func set_reading_quality(quality: int) -> void:
	if not reading_style.is_empty():
		(wash.material as ShaderMaterial).set_shader_parameter("quality", quality)


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


func center_heading() -> void:
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	command_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$ContentLayer/Panel/Layout/Header/Balance.visible = close_button.visible
	$ContentLayer/GoldBranch.hide()


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
	if $CrystalSheets.visible:
		$CrystalSheets.arrange(Rect2(panel.position, panel.size))
	if not reading_style.is_empty():
		_layout_reading_crystal()


func _layout_reading_crystal() -> void:
	var optical := wash.material as ShaderMaterial
	optical.set_shader_parameter("canvas_size", size)
	optical.set_shader_parameter("reading_rect", Vector4(panel.position.x, panel.position.y, panel.size.x, panel.size.y))
	# Overscan the 16:9 fields: roots live outside the viewport, leaving continuous
	# branches across the margins instead of two complete illustrations per page.
	var span := maxf(size.x * 1.28, size.y * 2.0)
	var first := Vector4(-span * 0.19, size.y - span * 0.47, span, span * 0.5625)
	var second := Vector4(size.x - span * 0.83, -span * 0.14, span, span * 0.5625)
	if reading_style == "guide":
		first = Vector4(-span * 0.27, -span * 0.06, span, span * 0.5625)
		second = Vector4(-span * 0.10, size.y - span * 0.36, span, span * 0.5625)
	elif reading_style == "words":
		first = Vector4(-span * 0.10, size.y - span * 0.36, span, span * 0.5625)
		second = Vector4(-span * 0.20, -span * 0.19, span, span * 0.5625)
	optical.set_shader_parameter("art_a", first)
	optical.set_shader_parameter("art_b", second)


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
