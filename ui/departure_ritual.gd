class_name DepartureRitual
extends Control
## Owns the visual handover; combat starts only after the veil has cleared.

signal covered
signal completed
signal cue_requested(cue: String)

var reduced_motion := false
var book: BookPresentation
var elapsed := 0.0
var _handed_over := false
var _surface: ShaderMaterial


func _ready() -> void:
	_surface = $Veil.material.duplicate() as ShaderMaterial
	$Veil.material = _surface
	_surface.set_shader_parameter("tint", book.color)
	$Seal.texture = book.seal
	$Book.text = book.title
	resized.connect(_layout)
	_layout()
	cue_requested.emit("ui.ritualRise" if not reduced_motion else "ui.confirm")


func _layout() -> void:
	_surface.set_shader_parameter("canvas_size", size)
	$Seal.position = size * 0.5 - Vector2(112, 150)
	$Book.position = Vector2(0, size.y * 0.5 + 94)
	$Book.size.x = size.x
	$Chapter.position = Vector2(0, size.y * 0.5 + 133)
	$Chapter.size.x = size.x


func _process(delta: float) -> void:
	elapsed += delta
	var progress := minf(1.0, elapsed / (0.36 if reduced_motion else 2.4))
	_surface.set_shader_parameter("progress", progress)
	_surface.set_shader_parameter("reduced_motion", reduced_motion)
	var inscription := smoothstep(0.38, 0.46, progress) * (1.0-smoothstep(0.68, 0.91, progress))
	var seal_light := smoothstep(0.12, 0.36, progress) * (1.0-smoothstep(0.58, 0.84, progress))
	$Seal.modulate = Color(book.color.lightened(0.2), seal_light * 0.55)
	$Book.modulate.a = inscription
	$Chapter.modulate.a = inscription * 0.8
	if not _handed_over and progress >= 0.44:
		_handed_over = true
		covered.emit()
		if not reduced_motion:
			cue_requested.emit("ui.ritualChime")
	if progress >= 1.0:
		set_process(false)
		completed.emit()
		queue_free()
