class_name IcePatch
extends Control
## A paid ice region owns its growth; render settings never alter combat state.

var growth := FrostGrowth.new()
var surface := preload("res://ui/materials/ice_surface.tres").duplicate() as ShaderMaterial
var _age := 0.0
var _steps := 0
var _resolution := 160
var _configured := false
var _growth_age := 0.0
var _static_entry := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mask = 2
	add_child(growth)
	surface.set_shader_parameter("crystal_surface", growth.surface_texture)
	surface.set_shader_parameter("microstructure", preload("res://assets/art/effects/frost_microfacets.png"))
	surface.set_shader_parameter("film_structure", preload("res://assets/art/effects/ice_microstructure.png"))
	material = surface


func sync_patch(center: Vector2, radius: float, age: float, fade: float, quality: int, reduced: bool, seed_value: int) -> void:
	# Resolving the lattice once avoids popping when quality changes mid-growth.
	# Give large ultimate fields more samples; keep short-lived hits cheaper.
	if not _configured:
		var visual_seed := posmod(seed_value, 65521)
		_resolution = [128,160,224][quality] if radius < 220.0 else [160,256,384][quality]
		surface.set_shader_parameter("lattice_angle", fposmod(visual_seed * 2.39996, TAU))
		RenderingServer.call_on_render_thread(growth.configure.bind(_resolution, visual_seed, radius >= 220.0))
		_configured = true
		_static_entry = reduced
	var extent := radius * 2.5
	size = Vector2.ONE * extent
	position = center - size * .5
	surface.set_shader_parameter("patch_size", extent)
	surface.set_shader_parameter("refraction", 0.0 if reduced or quality == 0 else 1.0)
	surface.set_shader_parameter("fade", fade)
	# Growth is tied to the paid clock, including pause. Bound per-frame catch-up.
	var dt := clampf(age - _age, 0.0, .05)
	var elapsed := maxf(0.0, age - _age)
	_age = age
	# New reduced-motion ice gets one brief entrance, then a stable structure.
	# Existing ice freezes immediately; resuming never catches up skipped ages.
	if not reduced: _static_entry = false
	if reduced and (not _static_entry or _growth_age >= .5):
		return
	_growth_age += elapsed
	var rate := _resolution * 7.0
	var next := mini(int(_growth_age * rate), _steps + ceili(rate * .05))
	var count := maxi(0, next - _steps)
	_steps += count
	if count > 0 or dt > 0.0:
		RenderingServer.call_on_render_thread(growth.step.bind(count, dt * 2.5))
	queue_redraw()


func set_fade(value: float) -> void:
	surface.set_shader_parameter("fade", value)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)
