class_name ArchiveEffects
extends Control
## Field-driven dust and two lit ritual planes.

const DUST_CAPACITY := 56

var _center := Vector2.ZERO
var _viewport_size := Vector2(1920.0, 1080.0)
var _quality := 2
var _reduce_motion := false
var _clock := 0.0
var _hero_center := Vector2.ZERO
var _hero_radius := 0.0
var _book_center := Vector2.ZERO
var _book_radius := 0.0
var _custom_anchors := false
var _accent := Color("8bdeff")

var _dust: GPUParticles2D
var _dust_process: ParticleProcessMaterial
var _hero_plane: ColorRect
var _book_plane: ColorRect


func _ready() -> void:
	_dust = $Dust
	_hero_plane = $HeroPlane
	_book_plane = $BookPlane
	_dust_process = _dust.process_material.duplicate(true) as ParticleProcessMaterial
	_dust_process.color = Color(1.0,1.0,1.0,0.38)
	_dust.process_material = _dust_process
	resized.connect(_layout)
	_apply_configuration()


func configure(center: Vector2, viewport_size: Vector2, quality: int, reduce_motion: bool) -> void:
	_center = center
	_viewport_size = viewport_size
	_quality = clampi(quality, 0, 2)
	_reduce_motion = reduce_motion
	if is_node_ready():
		_apply_configuration()


func set_anchors(hero_center: Vector2, hero_radius: float, selected_center: Vector2, selected_radius: float) -> void:
	# Both planes belong to the room, not the newly selected moving book.
	_hero_center = hero_center
	_hero_radius = maxf(0.0, hero_radius)
	_book_center = selected_center
	_book_radius = maxf(0.0, selected_radius)
	_custom_anchors = true
	if is_node_ready():
		_layout()


func _process(delta: float) -> void:
	if not _reduce_motion:
		_clock += delta
	var time := 0.0 if _reduce_motion else _clock
	for plane: ColorRect in [_hero_plane, _book_plane]:
		(plane.material as ShaderMaterial).set_shader_parameter("clock", time)


func _apply_configuration() -> void:
	size = _viewport_size
	set_accent(_accent)
	var dust_amount := 20 if _quality == 0 else (36 if _quality == 1 else DUST_CAPACITY)
	if _dust.amount != dust_amount:
		_dust.amount = dust_amount
	_dust.visible = not _reduce_motion
	_dust.speed_scale = 0.0 if _reduce_motion else 1.0
	for plane: ColorRect in [_hero_plane, _book_plane]:
		(plane.material as ShaderMaterial).set_shader_parameter("quality", [0.35, 0.75, 1.0][_quality])
	_layout()


func set_accent(value: Color) -> void:
	_accent = value
	# Tint all living particles together, including those emitted before selection.
	_dust.modulate = value
	for plane: ColorRect in [_hero_plane, _book_plane]:
		plane.light_mask = 2
		(plane.material as ShaderMaterial).set_shader_parameter("school_color", value)


func _layout() -> void:
	if _dust == null:
		return
	_dust.position = _viewport_size * 0.5
	_dust_process.emission_box_extents = Vector3(_viewport_size.x * 0.5, _viewport_size.y * 0.5, 0.0)
	_dust.visibility_rect = Rect2(-_viewport_size * 0.5, _viewport_size)
	if _custom_anchors:
		_position_plane(_hero_plane, _hero_center, _hero_radius)
		_position_plane(_book_plane, _book_center, _book_radius)
	else:
		var hero_radius := minf(_viewport_size.x * 0.51, _viewport_size.y * 0.46)
		_position_plane(_hero_plane, _center, hero_radius)
		_book_plane.visible = false
func _position_plane(plane: ColorRect, anchor: Vector2, radius: float) -> void:
	plane.visible = radius > 0.0
	if radius <= 0.0:
		return
	plane.position = anchor - Vector2.ONE * radius
	plane.size = Vector2.ONE * (radius * 2.0)
