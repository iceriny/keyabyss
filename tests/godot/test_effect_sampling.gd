extends SceneTree
## Deterministic native-resolution samples: shader contours, SVG seals and moving ribbons.
## Run before/after sampling changes; images are evidence, not an aesthetic pass flag.

var evidence: String
var stage: ArchiveStage
var samples_layer: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Sampling requires the real HDR renderer")
	evidence = "res://.temp/effect-sampling/run-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	if "--application" in OS.get_cmdline_user_args():
		await _application_samples()
		quit()
		return
	root.size = Vector2i(1280, 720)
	root.gui_snap_controls_to_pixels = false
	stage = ArchiveStage.create()
	root.add_child(stage)
	await process_frame
	assert(stage.viewport.msaa_2d == Viewport.MSAA_4X)
	assert(not stage.viewport.gui_snap_controls_to_pixels)
	stage.scenery.get_node("Paper").hide()
	stage.environment.glow_enabled = false
	samples_layer = Control.new()
	stage.scenery.add_child(samples_layer)
	var ritual := _field("res://ui/materials/archive_ritual.gdshader", Rect2(0, 0, 480, 480))
	ritual.set_shader_parameter("school_color", Color("c2a0ff"))
	ritual.set_shader_parameter("clock", 2.37)
	var seal := TextureRect.new()
	seal.texture = preload("res://assets/art/runes/spirit-seal.svg")
	assert(seal.texture.get_image().has_mipmaps(), "Reduced seals require prefiltered mip levels")
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.position = Vector2(490.37, 20.61)
	seal.size = Vector2(360, 360)
	seal.rotation = 0.073
	seal.modulate = Color("e7ca89")
	samples_layer.add_child(seal)
	var sigil := StartupSigil.new()
	sigil.position = Vector2(875.27, 40.43)
	sigil.size = Vector2(360, 360)
	samples_layer.add_child(sigil)
	_field("res://ui/materials/archive_floor.gdshader", Rect2(0, 470, 520, 180)).set_shader_parameter("school_color", Color("adc8dd"))
	var flight := load("res://ui/scenes/battle_spirit_visual.tscn").instantiate() as BattleSpiritVisual
	# The authored ribbon has no simulation dependency when extracted before _ready.
	var ribbon := flight.get_node("Filament") as Line2D
	flight.remove_child(ribbon)
	flight.free()
	var samples := PackedVector2Array([Vector2(550, 620), Vector2(620, 604), Vector2(702, 569), Vector2(787, 542), Vector2(876, 531), Vector2(970, 559), Vector2(1070, 614), Vector2(1220, 632)])
	ribbon.points = MotionTrail.build(samples, samples[-1], samples[-1], 900.0, true, 36)
	ribbon.width = 6.6
	samples_layer.add_child(ribbon)
	for output in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = output
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for frame in 5:
			await process_frame
		var previous_pixels := PackedByteArray()
		for offset in [0.0, 0.35]:
			samples_layer.position = Vector2(offset, offset)
			# Resolve the nested HDR target and its parent composition before readback.
			for frame in 3:
				await process_frame
				await RenderingServer.frame_post_draw
			var source := root.get_texture().get_image()
			var output_image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
			for y in source.get_height():
				for x in source.get_width():
					output_image.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
			var pixels := output_image.get_data()
			if offset > 0.0:
				assert(pixels != previous_pixels, "Subpixel movement must not snap back to the previous pixel grid")
			previous_pixels = pixels
			output_image.save_png(evidence.path_join("%dx%d-offset-%.2f.png" % [output.x, output.y, offset]))
	print("Effect sampling frames: " + evidence)
	stage.queue_free()
	await process_frame
	quit()

func _application_samples() -> void:
	# Exercise the saved application scenes and display settings, without overriding
	# their AA/filter properties as the isolated material samples do.
	var app := load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.sound = false
	app.settings.ambience = false
	app.settings.fullscreen = true
	app.settings.resolution = Vector2i(1920, 1080)
	app.settings.book_id = "spirit"
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await process_frame
	app.archive.set_process(false)
	app.archive.effects.set_process(false)
	var report: Array[Dictionary] = []
	for output in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		app.settings.resolution = output
		app.settings.apply(root)
		app.root.refresh()
		for frame in 5:
			await process_frame
			await RenderingServer.frame_post_draw
		var world := app.archive.stage.viewport
		assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)
		assert(Vector2i(root.get_texture().get_size()) == output and world.size == output)
		assert(root.msaa_2d == Viewport.MSAA_4X and world.msaa_2d == Viewport.MSAA_4X)
		assert(not root.gui_snap_controls_to_pixels and not world.gui_snap_controls_to_pixels)
		for emblem in app.archive.seal_layers:
			assert(emblem.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
				"The actual background seals must use mipmaps, not only the material fixture")
			assert(emblem.texture.get_image().has_mipmaps())
		var source := root.get_texture().get_image()
		var encoded := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		for y in source.get_height():
			for x in source.get_width():
				encoded.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
		encoded.save_png(evidence.path_join("application-%dx%d.png" % [output.x, output.y]))
		report.append({"output": str(output), "window": str(root.size), "world": str(world.size),
			"root_msaa": root.msaa_2d, "world_msaa": world.msaa_2d})
		print("Application sampling: ", report[-1])
	var file := FileAccess.open(evidence.path_join("application.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Application sampling frames: " + evidence)
	app.queue_free()
	await process_frame

func _field(path: String, rect: Rect2) -> ShaderMaterial:
	var field := ColorRect.new()
	field.position = rect.position
	field.size = rect.size
	var material := ShaderMaterial.new()
	material.shader = load(path)
	field.material = material
	samples_layer.add_child(field)
	return material
