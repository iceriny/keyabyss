class_name BattleStage
extends Control
## Lit world in an HDR viewport; readable HUD and warnings stay on the main canvas.

var viewport: SubViewport
var scenery: Control
var output: TextureRect
var environment: Environment
var periphery: ShaderMaterial


static func create(quality: int = 2) -> BattleStage:
	var stage := load("res://ui/scenes/battle_stage.tscn").instantiate() as BattleStage
	stage._bind_scene()
	stage.set_quality(quality)
	return stage


func _bind_scene() -> void:
	viewport = $World
	scenery = $World/Scenery
	output = $Output
	environment = ($World/Lighting as WorldEnvironment).environment
	periphery = output.material as ShaderMaterial
	output.texture = viewport.get_texture()


static func arena_scale(view_size: Vector2) -> float:
	return minf(view_size.x / BattleSession.ARENA_SIZE.x, view_size.y / BattleSession.ARENA_SIZE.y)


static func arena_origin(view_size: Vector2) -> Vector2:
	return (view_size - BattleSession.ARENA_SIZE * arena_scale(view_size)) * 0.5


static func arena_point(at: Vector2, view_size: Vector2) -> Vector2:
	return arena_origin(view_size) + at * BattleSession.ARENA_SIZE * arena_scale(view_size)


func set_quality(quality: int) -> void:
	periphery.set_shader_parameter("quality", quality)
	periphery.set_shader_parameter("softness", [8.0, 13.0, 18.0][quality])
	output.material = periphery
	environment.glow_enabled = quality > 0
	environment.glow_intensity = 0.7 if quality == 2 else 0.5


func _ready() -> void:
	if viewport == null:
		_bind_scene()
	resized.connect(_resize)
	get_window().size_changed.connect(_resize, CONNECT_DEFERRED)
	_resize()


func _resize() -> void:
	# This full-window layer shares the output pixel dimensions with the HUD.
	# A window resize can change canvas scale without resizing this Control.
	var window := get_window()
	# The render texture can still report its previous allocation during size_changed.
	viewport.size = window.content_scale_size if window.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT else window.size
	var pixel_scale := Vector2(viewport.size) / size.max(Vector2.ONE)
	viewport.canvas_transform = Transform2D(0.0, pixel_scale, 0.0, Vector2.ZERO)
	scenery.size = size
	periphery.set_shader_parameter("arena_origin", arena_origin(size) / size.max(Vector2.ONE))
	periphery.set_shader_parameter("arena_span", BattleSession.ARENA_SIZE * arena_scale(size) / size.max(Vector2.ONE))
	periphery.set_shader_parameter("edge_width", BattleSession.EDGE_WIDTH)
