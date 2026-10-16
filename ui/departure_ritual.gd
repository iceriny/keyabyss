class_name DepartureRitual
extends Control
## Owns the visual handover; combat starts only after the veil has cleared.

signal covered
signal completed
signal cue_requested(cue: String)

var reduced_motion := false
var chapter_entry := true
@export var startup := false
var ready_to_reveal := false
@onready var feedback: LoadingFeedback = $LoadingFeedback
var book: BookPresentation
var stage_text := "第 1 章 · 失落书库"
var elapsed := 0.0
var _light_clock := 0.0
var _handed_over := false
var _surface: ShaderMaterial


func _ready() -> void:
	feedback.reduced_motion = reduced_motion
	_surface = $Veil.material as ShaderMaterial
	if startup:
		$Veil.hide()
		$Backdrop.show()
		$Backdrop.reduced_motion = reduced_motion
		_surface.set_shader_parameter("startup", true)
		feedback.radial_progress = true
		feedback.stage_changed.connect(_update_runes)
		$LoadingRunes.show()
		if not reduced_motion:
			$LoadingRunes/Rotation.play("spin")
		elapsed = 0.44 * (0.36 if reduced_motion else 2.4)
		_handed_over = true
		$Seal.hide()
		$Book.text = "键  渊"
		$Book.material = preload("res://ui/materials/engraved_gold.tres").duplicate()
		$Chapter.text = "失 控 咒 典"
		$Chapter.add_theme_color_override("font_color", Color("9d8b63"))
		feedback.get_node("Stage").add_theme_color_override("font_color", Color("b7a67d"))
		feedback.get_node("Count").add_theme_color_override("font_color", Color("897e60"))
		feedback.show()
	else:
		_surface.set_shader_parameter("tint", book.color)
		$Seal.texture = book.seal
		$Seal.material = preload("res://ui/materials/book_seal.tres").duplicate()
		($Seal.material as ShaderMaterial).set_shader_parameter("tint", book.color)
		$Book.text = stage_text
		$Book.add_theme_font_size_override("font_size", 38 if chapter_entry else 26)
		$Chapter.text = book.title
		_surface.set_shader_parameter("ceremony", 1.0 if chapter_entry else 0.28)
	resized.connect(_layout)
	_layout()
	if not startup:
		cue_requested.emit("ui.ritualRise" if chapter_entry and not reduced_motion else "ui.confirm")


func _layout() -> void:
	_surface.set_shader_parameter("canvas_size", size)
	$Seal.position = size * 0.5 - Vector2(112, 150)
	$LoadingRunes.position = size * 0.5 - Vector2(0, 100)
	$LoadingRunes.scale = Vector2.ONE * minf(size.x, size.y) / 1080.0
	$Book.position = Vector2(0, size.y * 0.5 + 94)
	$Book.size.x = size.x
	$Chapter.position = Vector2(0, size.y * 0.5 + 133)
	$Chapter.size.x = size.x
	feedback.position = Vector2(size.x * 0.5 - 200.0, size.y * 0.5 + 188.0)
	feedback.size = Vector2(400, 90)
	if not startup and not chapter_entry:
		$Seal.position = size * 0.5 - Vector2(52, 82)
		$Seal.size = Vector2(104, 104)
		$Book.position.y = size.y * 0.5 + 38
		$Chapter.position.y = size.y * 0.5 + 80
	if startup:
		var unit := size.y / 1080.0
		$LoadingRunes.position = Vector2(size.x * 0.5, size.y * 0.385)
		$LoadingRunes.scale = Vector2.ONE * unit * 1.28
		$Book.position.y = size.y * 0.385 + 278.0 * unit
		$Book.size.y = 48.0 * unit
		$Book.add_theme_font_size_override("font_size", roundi(34.0 * unit))
		$Chapter.position.y = size.y * 0.385 + 334.0 * unit
		$Chapter.add_theme_font_size_override("font_size", roundi(16.0 * unit))
		feedback.position = Vector2(size.x * 0.5 - 210.0 * unit, size.y * 0.385 + 389.0 * unit)
		feedback.size = Vector2(420, 90) * unit
		feedback.get_node("Stage").add_theme_font_size_override("font_size", roundi(20.0 * unit))
		feedback.get_node("Count").add_theme_font_size_override("font_size", roundi(13.0 * unit))


func _process(delta: float) -> void:
	var duration := 0.36 if reduced_motion else (2.4 if startup else (2.8 if chapter_entry else 1.15))
	elapsed += delta
	if not ready_to_reveal:
		elapsed = minf(elapsed, duration * 0.44)
	var progress := minf(1.0, elapsed / duration)
	_surface.set_shader_parameter("progress", progress)
	_surface.set_shader_parameter("reduced_motion", reduced_motion)
	var inscription := smoothstep(0.38, 0.46, progress) * (1.0-smoothstep(0.68, 0.91, progress))
	var seal_light := smoothstep(0.12, 0.36, progress) * (1.0-smoothstep(0.58, 0.84, progress))
	if not startup:
		$Seal.modulate = Color(1,1,1,seal_light * 0.55)
		($Seal.material as ShaderMaterial).set_shader_parameter("clock", 0.0 if reduced_motion else elapsed)
	$Book.modulate.a = inscription
	$Chapter.modulate.a = inscription * 0.8
	if startup:
		var reveal := 1.0 - smoothstep(0.44, 1.0, progress)
		modulate.a = reveal
		$Book.modulate.a = 1.0
		$Chapter.modulate.a = 0.8
		if not reduced_motion:
			_light_clock += delta
		for layer: CanvasGroup in [$LoadingRunes/RingLight, $LoadingRunes/CoreLight]:
			(layer.material as ShaderMaterial).set_shader_parameter("clock", _light_clock)
		($Book.material as ShaderMaterial).set_shader_parameter("clock", _light_clock)
		$LoadingRunes.modulate.a = 1.0
	if not _handed_over and elapsed >= duration * 0.44:
		_handed_over = true
		feedback.update_stage("正在展开战场", 0, 0)
		feedback.show()
		# Present the waiting state before instantiating the battle.
		_handover.call_deferred()
		if chapter_entry and not reduced_motion:
			cue_requested.emit("ui.ritualChime")
	if progress >= 1.0:
		set_process(false)
		completed.emit()
		queue_free()


func _handover() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	covered.emit()


func release() -> void:
	ready_to_reveal = true
	feedback.hide()


func _update_runes(done: int, total: int) -> void:
	# Unknown-length catalog loading keeps the completed ring, rather than resetting it.
	if total > 0:
		$LoadingRunes/RingLight/Rotor/Progress.value = float(done) / total * 100.0
