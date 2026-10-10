class_name ArchiveStage
extends Control
## Only scenery enters HDR glow and refraction. UI text stays on the main canvas.
var viewport: SubViewport
var scenery: Control
var output: TextureRect
var environment: Environment
var lens: ShaderMaterial
var wave_time := 2.0
var wave_origin := Vector2.ZERO
var reduced_motion := false
var active := true

static func create() -> ArchiveStage:
	return load("res://ui/scenes/archive_stage.tscn").instantiate() as ArchiveStage

func _ready() -> void:
	viewport = $World
	scenery = $World/Scenery
	output = $Output
	environment = ($World/Lighting as WorldEnvironment).environment
	lens = output.material as ShaderMaterial
	output.texture = viewport.get_texture()
	resized.connect(_resize)
	get_window().size_changed.connect(_resize, CONNECT_DEFERRED)
	_resize()

func _resize() -> void:
	if viewport == null:
		return
	# Render scenery at physical pixel density, without rasterizing UI into it.
	var pixel_scale := get_global_transform_with_canvas().get_scale().abs()
	viewport.size = Vector2i((size * pixel_scale).ceil().max(Vector2.ONE))
	viewport.canvas_transform = Transform2D(0.0, pixel_scale, 0.0, Vector2.ZERO)
	scenery.size = size
	lens.set_shader_parameter("canvas_size", size)
	request_render()

func configure(quality: int, reduce: bool) -> void:
	reduced_motion = reduce
	environment.glow_enabled = quality > 0
	environment.glow_intensity = 0.28 if quality == 1 else 0.4
	if reduce:
		wave_time = 2.0
		lens.set_shader_parameter("wave_progress", 1.0)
		set_process(false)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active and not reduce else SubViewport.UPDATE_DISABLED
	_resize()

func set_active(value: bool) -> void:
	active = value
	var fluid := scenery.get_node_or_null("FluidAtmosphere") as FluidAtmosphere
	if fluid != null:
		fluid.set_active(value)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active and not reduced_motion else SubViewport.UPDATE_DISABLED
	if active:
		request_render()

func request_render() -> void:
	if viewport != null and active and reduced_motion:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if not RenderingServer.frame_post_draw.is_connected(_finish_reduced_render):
			RenderingServer.frame_post_draw.connect(_finish_reduced_render, CONNECT_ONE_SHOT)

func _finish_reduced_render() -> void:
	if reduced_motion and viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func resonate(origin: Vector2) -> void:
	wave_origin = origin
	wave_time = 2.0 if reduced_motion else 0.0
	set_process(not reduced_motion)
	request_render()

func _process(delta: float) -> void:
	wave_time = minf(2.0, wave_time + delta)
	lens.set_shader_parameter("wave_center", wave_origin)
	lens.set_shader_parameter("wave_progress", clampf(wave_time / 1.3, 0.0, 1.0))
	if wave_time >= 1.3:
		set_process(false)
