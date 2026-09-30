extends SceneTree
## Real RenderingDevice regression: transport, solids, masks, lifecycle and UI.

var evidence: String
var failures := 0
var timings: Array[float] = []
var reports: Array[Dictionary] = []
var _last_timestamp_frame := -1
var _movie_srgb := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Fluid regression requires the actual GPU renderer")
	evidence = "res://.temp/fluid/run-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1280, 720)
	if "--usage" in OS.get_cmdline_user_args():
		await _node_usage()
		print("Fluid node usage: ", failures, " failures")
		quit(0 if failures == 0 else 1)
		return
	if "--clip" in OS.get_cmdline_user_args():
		await _visual_clip()
		print("Fluid motion clip: ", evidence)
		quit(0 if failures == 0 else 1)
		return
	if "--materials" in OS.get_cmdline_user_args():
		await _material_and_effects()
		print("Fluid material regression: ", failures, " failures")
		quit(0 if failures == 0 else 1)
		return
	if "--motion" in OS.get_cmdline_user_args():
		await _continuous_motion()
		await _wake_transport()
		await _battle_interactions()
		print("Fluid motion regression: ", failures, " failures | ", evidence)
		quit(0 if failures == 0 else 1)
		return
	await _node_usage()
	var field := FluidField2D.new()
	field.position = Vector2(160, 80)
	field.size = Vector2(960, 540)
	field.rotation = .07
	field.wind = Vector2.ZERO
	field.buoyancy = 0
	field.vorticity = 0
	field.velocity_decay = 0
	field.density_decay = .1
	var source := FluidInfluence.new()
	source.center = Vector2(360, 260)
	source.extent = Vector2(120, 100)
	source.density = 1
	source.velocity = Vector2(80, 0)
	field.sources.append(source)
	# Bind before allocation, just as scene and particle materials do at _ready.
	var probe := SubViewport.new()
	probe.size = Vector2i(160, 90)
	probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var readout := ColorRect.new()
	readout.size = probe.size
	var readout_material := ShaderMaterial.new()
	var readout_shader := Shader.new()
	readout_shader.code = "shader_type canvas_item; render_mode unshaded; uniform sampler2D state_texture : filter_nearest; void fragment() { COLOR = vec4(vec3(texture(state_texture, UV).b), 1.0); }"
	readout_material.shader = readout_shader
	readout_material.set_shader_parameter("state_texture", field.field_texture())
	readout.material = readout_material
	probe.add_child(readout)
	root.add_child(probe)
	root.add_child(field)
	field.set_process(false)
	await _settle()
	_check(field.canvas_to_local(field.get_global_transform_with_canvas() * Vector2(123, 87)).distance_to(Vector2(123, 87)) < .01, "transformed local coordinates")
	for i in 40:
		field._process(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
	var first := field.field_texture().get_image()
	_check(first != null and _density_sum(first) > 5.0, "GPU density injection")
	var displayed := probe.get_texture().get_image()
	_check(absf(displayed.get_pixel(150, 45).r - first.get_pixel(150, 45).b) < .01, "empty fluid stays transparent: material sampler is bound to the actual GPU texture")
	_check(displayed.get_pixel(60, 43).r > .05, "density reaches the CanvasItem material")
	await _particle_transport(field, source.center)
	var initial_center := _density_center(first)
	field.sources.clear()
	for i in 35:
		field._process(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
	var transported := field.field_texture().get_image()
	_check(_density_center(transported).x > initial_center.x + .3, "density follows velocity rather than procedural animation")
	_check(_density_sum(transported) < _density_sum(first), "density dissipates")
	var obstacle := FluidInfluence.new()
	obstacle.center = Vector2(400, 260)
	obstacle.extent = Vector2(70, 70)
	obstacle.velocity = Vector2(32, 0)
	field.obstacles.append(obstacle)
	field._process(.04)
	await _settle()
	var solid := field.field_texture().get_image()
	var solid_cell := Vector2i(obstacle.center / field.size * Vector2(field.grid_size))
	var contact := solid.get_pixelv(solid_cell)
	_check(contact.b == 0 and absf(contact.r - 32.0) < .1, "moving solid excludes density and supplies body velocity")
	var mask_image := Image.create(32, 32, false, Image.FORMAT_R8)
	mask_image.fill(Color.WHITE)
	mask_image.fill_rect(Rect2i(16, 0, 16, 32), Color.BLACK)
	field.domain_mask = ImageTexture.create_from_image(mask_image)
	field.set_options(2, false)
	field.sources.append(source)
	field.obstacles.clear()
	await _settle()
	for i in 20:
		field._process(.04)
		await process_frame
		await RenderingServer.frame_post_draw
	var masked := field.field_texture().get_image()
	var blocked_density := 0.0
	for y in masked.get_height():
		for x in range(int(masked.get_width() / 2.0), masked.get_width()):
			blocked_density += masked.get_pixel(x, y).b
	_check(blocked_density == 0 and _density_sum(masked) > 0, "arbitrary texture domain participates in solver boundaries")
	var ticks := field.tick_count
	field.set_active(false)
	field._process(1.0)
	_check(field.tick_count == ticks, "inactive field does not dispatch")
	field.set_active(true)
	field.set_options(2, true)
	field._process(1.0)
	_check(field.tick_count == ticks, "reduced motion does not dispatch")
	field.domain_mask = null
	for quality in [1, 2, 3, 4]:
		field.set_options(quality, false)
		await _settle()
		timings.clear()
		for frame in 80:
			RenderingServer.call_on_render_thread(_timestamp.bind("fluid_begin"))
			field._process(1.0 / 60.0)
			RenderingServer.call_on_render_thread(_timestamp.bind("fluid_end"))
			await process_frame
			await RenderingServer.frame_post_draw
			RenderingServer.call_on_render_thread(_read_timestamps)
		await _settle()
		_check(field.field_texture().get_width() == FluidField2D.LONG_EDGES[quality], "quality grid allocation %d" % quality)
		_check(field._gpu.density_texture.get_width() == FluidField2D.FOG_LONG_EDGES[quality], "independent fog resolution %d" % quality)
		var before_tick := field.tick_count
		field._process(1.0 / 144.0)
		_check(field.tick_count == before_tick + 1, "quality %d responds on a high-refresh render frame" % quality)
		timings.sort()
		# Godot's Vulkan driver returns nanoseconds (despite the class reference unit).
		var report := {"quality": quality, "grid": str(field.grid_size), "fog_grid": str(field.fog_grid_size), "gpu_ms_p50": timings[int(timings.size() / 2.0)] / 1000000.0 if not timings.is_empty() else 0.0, "samples": timings.size()}
		reports.append(report)
		print("Fluid compute timing: ", report)
	field.set_options(0, false)
	await _settle()
	# OFF keeps the same sampler identity with one zero texel, without solver storage.
	_check(field.field_texture().get_width() == 1 and field._gpu._owned.size() == 1 and field._gpu._sets.is_empty(), "off releases solver storage and keeps a zero sampler")
	_check(probe.get_texture().get_image().get_pixel(60, 43).r == 0.0, "off retains a valid zero sampler in existing materials")
	field.set_options(2, false)
	await _settle()
	var rigid := RigidBody2D.new()
	rigid.freeze = true
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(60, 40)
	collision.shape = box
	rigid.add_child(collision)
	var adapter := FluidBody2D.new()
	adapter.field = field
	adapter.collision = collision
	adapter.interaction = FluidBody2D.Interaction.SOLID
	rigid.add_child(adapter)
	root.add_child(rigid)
	rigid.position = Vector2(430, 290)
	await _settle()
	_check(field.obstacles.size() == 1 and field.obstacles[0].shape == FluidInfluence.Shape.BOX, "rigid body adapter registers collision shape")
	rigid.position += Vector2(30, 0)
	adapter._process(.1)
	_check(field.obstacles[0].velocity.length() > 100, "rigid movement supplies local fluid velocity")
	adapter.interaction = FluidBody2D.Interaction.DISPLACE
	adapter._process(.04)
	_check(field.obstacles.is_empty() and field.sources.has(adapter._obstacle) and adapter._obstacle.density == 0.0, "projected rigid body uses the same density-preserving momentum input")
	rigid.queue_free()
	await _settle()
	_check(field.obstacles.is_empty(), "rigid body adapter unregisters on removal")
	field.sources.clear()
	var capsule := FluidInfluence.new()
	capsule.shape = FluidInfluence.Shape.CAPSULE
	capsule.center = Vector2(450, 260)
	capsule.extent = Vector2(110, 35)
	capsule.rotation = .7
	capsule.density = .5
	capsule.temperature = .5
	capsule.spin = 2
	field.buoyancy = 20
	field.wind = Vector2(3, 0)
	field.vorticity = .5
	_check(field.inject(capsule), "rotated capsule impulse accepted")
	field._process(.05)
	await _settle()
	_check(_density_sum(field.field_texture().get_image()) > 0, "capsule disturbance, heat and wind execute on GPU")
	field.queue_free()
	probe.queue_free()
	await _settle()
	await _material_and_effects()
	await _continuous_motion()
	await _wake_transport()
	await _application()
	var file := FileAccess.open(evidence.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "failures": failures, "timings": reports}, "\t"))
	print("Fluid regression: %d failures | %s" % [failures, evidence])
	quit(0 if failures == 0 else 1)


func _node_usage() -> void:
	var field := FluidField2D.new()
	field.position = Vector2(60, 40)
	field.size = Vector2(320, 180)
	field.wind = Vector2.ZERO
	root.add_child(field)
	field.set_process(false)
	var visual := Node2D.new()
	visual.position = Vector2(170, 130)
	root.add_child(visual)
	var body := FluidBody2D.new()
	body.field = field
	body.position = Vector2(8, -5)
	body.scale = Vector2(2, 1)
	body.shape = FluidInfluence.Shape.BOX
	body.extent = Vector2(12, 8)
	body.body_shape = FluidInfluence.BodyShape.POINTED
	visual.add_child(body)
	body.set_process(false)
	body._process(.02)
	_check(field.sources.has(body._obstacle) and body._obstacle.center.is_equal_approx(Vector2(118, 85)), "manual visual body registers in field-local coordinates without a collider")
	_check(body._obstacle.extent.is_equal_approx(Vector2(24, 8) * body.reach), "manual footprint respects node scale and interaction reach")
	visual.position.x += 20
	body._process(.02)
	field._process(1.0 / 60.0)
	await _settle()
	_check(_velocity_energy(field.field_texture().get_image()) > 1.0 and _density_sum(field.field_texture().get_image()) == 0.0, "manual body moves GPU air without emitting fog")
	visual.position += Vector2(100, -40)
	body.rebase()
	body._process(.02)
	_check(body._obstacle.velocity == Vector2.ZERO and body._obstacle.sweep_length == 0.0, "body rebase prevents a teleport from becoming a swept impulse")
	body.hide()
	body._process(.02)
	_check(not field.sources.has(body._obstacle), "hidden manual body unregisters")
	body.show()
	body.interaction = FluidBody2D.Interaction.SOLID
	body._process(.02)
	_check(field.obstacles.has(body._obstacle) and not field.sources.has(body._obstacle) and body._obstacle.shape == FluidInfluence.Shape.BOX, "manual wall uses its footprint and switches registration cleanly")
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	collision.shape = circle
	visual.add_child(collision)
	var adapter := FluidBody2D.new()
	adapter.field = field
	adapter.collision = collision
	visual.add_child(adapter)
	adapter.set_process(false)
	adapter._process(.02)
	_check(adapter._obstacle.displacement_radius == 9.0 and adapter._obstacle.shape == FluidInfluence.Shape.ELLIPSE, "assigned collision continues to override the manual footprint")
	var profile := FluidEffectProfile.new()
	profile.duration = 0.0
	profile.along_path = true
	var source := FluidInfluence.new()
	source.extent = Vector2(20, 10)
	source.density = .1
	profile.influences.assign([source])
	var emitter := field.emit_effect(profile, Vector2(70, 60), .4)
	emitter.end_offset = Vector2(100, 0)
	emitter.set_process(false)
	var sample := emitter.sample(.02)[0]
	_check(sample.center.is_equal_approx(Vector2(70, 60) + Vector2(50, 0).rotated(.4)) and sample.shape == FluidInfluence.Shape.CAPSULE, "along-path emitter uses its local endpoint and rotation")
	_check(source.center == Vector2.ZERO and source.extent == Vector2(20, 10), "emitter leaves the shared effect definition unchanged")
	profile.duration = 2.0
	profile.fade_out = 0.0
	emitter.age = .5
	_check(emitter.strength() == 1.0, "zero fade retains full effect strength until its duration ends")
	emitter.age = 2.0
	_check(emitter.strength() == 0.0, "zero fade ends the effect at its duration")
	emitter.queue_free()
	visual.queue_free()
	await _settle()
	_check(field.sources.is_empty() and field.obstacles.is_empty() and field._emitters.is_empty(), "visual body and effect removal release registrations")
	field.queue_free()
	await _settle()


func _application() -> void:
	var app := load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await create_timer(8).timeout
	var home_fog := app.archive.fluid.field_texture().get_image()
	var upper_fog := home_fog.get_region(Rect2i(0, 0, home_fog.get_width(), home_fog.get_height() / 2))
	_check(_density_sum(upper_fog) < _density_sum(home_fog) * .1, "resting home mist occupies the lower room instead of a full-screen veil")
	await _capture("home")
	await _home_lighting(app.archive)
	var idle_energy := _velocity_energy(app.archive.fluid.field_texture().get_image())
	await _key(KEY_RIGHT)
	await create_timer(.3).timeout
	_check(_velocity_energy(app.archive.fluid.field_texture().get_image()) > idle_energy * 2.0, "menu selection actually drives the GPU velocity field")
	await _capture("home-flow")
	await create_timer(.9).timeout
	await _capture("home-settle")
	await _deployment(app.archive)
	var viewport := app.archive.stage.viewport
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	for quality in [0, 1, 2, 3, 4]:
		app.settings.fluid_quality = quality
		app._apply_visual_settings()
		await create_timer(.5).timeout
		if quality == 0:
			await _capture("home-off")
			_check(app.archive.fluid._lights.any(func(light: PointLight2D) -> bool: return light.enabled), "fluid off preserves independent native scene lighting")
		var samples: Array[float] = []
		for i in 60:
			await process_frame
			await RenderingServer.frame_post_draw
			samples.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
		samples.sort()
		var report := {"home_fluid_quality": quality, "hdr_viewport_gpu_ms_p50": samples[30], "output": str(viewport.size), "samples": samples.size()}
		reports.append(report)
		print("Fluid home render timing: ", report)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), false)
	app.settings.fluid_quality = 2
	app._apply_visual_settings()
	app._settings_page("home")
	await _settle()
	for tab in ["display", "visuals", "audio", "gameplay"]:
		app._select_settings_tab(tab)
		await _settle()
		await _capture("settings-" + tab)
		_check(app._settings_groups[tab].is_visible_in_tree(), "settings tab %s" % tab)
	app._activate_control(app.settings_controls["fluid_quality"])
	_check(app.settings_tab == "visuals", "fluid command reveals owning tab")
	(app.settings_controls["fluid_quality"] as OptionButton).get_popup().hide()
	(app.settings_controls["fluid_quality"] as OptionButton).select(1)
	app._save_settings()
	_check(app.archive.fluid.quality == 1, "independent setting updates home immediately")
	var restored := AppSettings.new(app.settings.path)
	restored.load_settings()
	_check(restored.fluid_quality == 1, "fluid setting persists")
	app._start_battle()
	await create_timer(6).timeout
	_check(app.battle.visuals.fluid.quality == 1 and not app.archive.fluid.active, "battle receives fluid quality and hidden home stops")
	await _capture("battle")
	app._pause()
	var tick := app.battle.visuals.fluid.tick_count
	await create_timer(.2).timeout
	_check(app.battle.visuals.fluid.tick_count == tick, "pause freezes field")
	app._settings_page("pause")
	await _settle()
	(app.settings_controls["fluid_quality"] as OptionButton).select(3)
	app._save_settings()
	_check(app.battle.visuals.fluid.quality == 3, "paused settings update battle immediately")
	app._defaults()
	_check(app.settings.fluid_quality == 2, "defaults restore independent fluid quality")
	app._home()
	await _settle()
	app.queue_free()
	await _settle()
	await _battle_interactions()


func _visual_clip() -> void:
	# MovieWriter quantizes HDR before sRGB encoding, losing dark gradients.
	# Pre-encode here; the final transcode must undo the writer's second encoding.
	_movie_srgb = root.use_hdr_2d
	if _movie_srgb:
		var output := CanvasLayer.new()
		output.layer = 100
		var encode := ColorRect.new()
		encode.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		encode.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; render_mode unshaded; uniform sampler2D screen : hint_screen_texture, filter_nearest; void fragment() { vec3 c = max(texture(screen, SCREEN_UV).rgb, vec3(0.0)); COLOR = vec4(mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)), 1.0); }"
		material.shader = shader
		encode.material = material
		output.add_child(encode)
		root.add_child(output)
	if "--battle" in OS.get_cmdline_user_args():
		await _battle_interactions()
		return
	var app := load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("clip.cfg"))
	app.settings.sound = false
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	await create_timer(3).timeout
	await _capture("home-air-start")
	await create_timer(3).timeout
	var room := app.archive.fluid
	_check(room.position == Vector2.ZERO and room.size.is_equal_approx(app.archive.size), "home air covers the whole scene")
	var resting_air := room.field_texture().get_image()
	var outer_area := Rect2i(Vector2i(Vector2(room.grid_size) * Vector2(.06, .65)), Vector2i(Vector2(room.grid_size) * Vector2(.12, .3)))
	_check(_density_sum(resting_air.get_region(outer_area)) > 1.0 and _velocity_energy(resting_air, Rect2(.06, .25, .12, .4)) > .1, "lower ambient mist and clear upper air both exist beyond the book orbit")
	await _capture("home-air-rest")
	var mist_before := _density_sum(resting_air)
	var ambient_rate := room._ambient[0].density
	room._ambient[0].density = 0.0
	await _key(KEY_RIGHT)
	await create_timer(.07).timeout
	await _capture("home-air-starting")
	await create_timer(.28).timeout
	var carried_air := room.field_texture().get_image()
	_check(_density_sum(carried_air) < mist_before * 1.05, "book movement carries existing mist without emitting new density")
	_check(_velocity_energy(carried_air) > _velocity_energy(resting_air) * 1.5, "book movement stirs the room air")
	await _capture("home-air-carried")
	room._ambient[0].density = ambient_rate
	await create_timer(2.25).timeout
	await _key(KEY_LEFT)
	await create_timer(2.6).timeout
	var gesture := PackedVector2Array([Vector2(440, 740), Vector2(1450, 740), Vector2(1450, 280), Vector2(470, 280)])
	var last := gesture[0]
	for i in 19:
		var segment := mini(i / 6, 2)
		var fraction := float(i - segment * 6) / 6.0
		var at := gesture[segment].lerp(gesture[segment + 1], fraction)
		var pointer := InputEventMouseMotion.new()
		pointer.position = root.get_screen_transform() * at
		pointer.global_position = pointer.position
		pointer.relative = root.get_screen_transform().basis_xform(at - last)
		Input.warp_mouse(pointer.position)
		Input.parse_input_event(pointer)
		last = at
		await process_frame
	await process_frame
	var pointer_motion: Dictionary = app.archive.fluid._motion.get(&"pointer", {})
	_check(not pointer_motion.is_empty() and (pointer_motion.point as Vector2).distance_to(gesture[-1] - app.archive.fluid.position) < 2, "native fast pointer gesture reaches the fluid motion source: %s" % pointer_motion.get("point", Vector2.INF))
	await _capture("pointer-wake")
	await create_timer(1.0).timeout
	await _deployment(app.archive)
	# The same reusable inputs operate over the existing home air.
	room.emit_effect(load("res://ui/effects/presets/electric_flash.tres"), room.size * Vector2(.35, .6))
	await create_timer(.12).timeout
	await _capture("electric-fog")
	var pull := room.emit_effect(load("res://ui/effects/presets/suction.tres"), room.size * Vector2(.65, .65))
	await create_timer(1.5).timeout
	pull.queue_free()
	room.emit_effect(load("res://ui/effects/presets/burst.tres"), room.size * Vector2(.65, .65))
	await create_timer(.4).timeout
	await _capture("air-burst")
	await create_timer(.8).timeout
	app.queue_free()
	await _settle()
	await _battle_interactions()


func _battle_interactions() -> void:
	for book: BookPresentation in [ArchiveHome.BOOKS[0], ArchiveHome.BOOKS[3]]:
		var session := BattleSession.new()
		var words: Array[VocabularyEntry] = [VocabularyEntry.new("lumen", "光"), VocabularyEntry.new("ember", "余烬"), VocabularyEntry.new("quill", "羽笔")]
		session.start_baseline(book.id, words, "normal", "fluid-motion", false)
		for i in session.enemies.size():
			var enemy := session.enemies[i]
			enemy.position = Vector2(.8, .35 + i * .15)
			enemy.previous_position = enemy.position
			enemy.hp_q = 120 * BattleSession.Q
			enemy.max_hp_q = enemy.hp_q
			enemy.attack_clock = 12.0
		var options := AppSettings.new(evidence.path_join("motion.cfg"))
		options.sound = false
		var page := BattlePage.create(session, options, book)
		page.theme = ArchiveTheme.create(book.color)
		root.add_child(page)
		var router := InputRouter.new()
		router.typing = session.typing
		router.configure(InputRouter.Context.TYPING)
		router.action_requested.connect(session.queue_action)
		page.add_child(router)
		await create_timer(2).timeout
		if _movie_srgb and book.id == &"frost" and "--battle" not in OS.get_cmdline_user_args():
			session.set_physics_process(false)
			await create_timer(12).timeout
			await _capture("battle-ambient-rest")
			session.set_physics_process(true)
		var start := session.player_position
		var field := page.visuals.fluid
		var trail_area := Rect2i(Vector2i(Vector2(field.grid_size) * Vector2(.465, .29)), Vector2i(Vector2(field.grid_size) * Vector2(.07, .18)))
		var before_dodge := _density_sum(field.field_texture().get_image().get_region(trail_area))
		await _key(KEY_UP)
		await create_timer(.08).timeout
		_check(session.player_position.distance_to(start) > .1 and _velocity_energy(field.field_texture().get_image(), Rect2(Vector2(.43, .23), Vector2(.14, .3))) > 10, "%s dodge moves air along its actual path" % book.id)
		var after_dodge := field.field_texture().get_image()
		_check(_density_sum(after_dodge.get_region(trail_area)) > before_dodge + 1.0, "%s dodge leaves actual fog along the travelled path" % book.id)
		await _capture(str(book.id) + "-dodge")
		await create_timer(.08).timeout
		session.typing.select_target(session.enemies[1].id)
		for character in session.typing.word:
			await _key(character.to_upper().unicode_at(0) as Key, character.unicode_at(0))
		await create_timer(.07).timeout
		_check(not session.projectiles.is_empty(), "%s real input creates projectile" % book.id)
		_check(field.tracked_count > session.enemies.size() + 1, "%s projectile contributes motion" % book.id)
		await _capture(str(book.id) + "-flight")
		await create_timer(.45).timeout
		await _capture(str(book.id) + "-wake")
		await create_timer(1.1).timeout
		await _capture(str(book.id) + "-dispersed")
		page.queue_free()
		await _settle()
	# A real storm cast uses its resource-selected path light, without school
	# branches in the field, emitter or shader.
	var storm := BattleSession.new()
	var storm_book := ArchiveHome.BOOKS[1]
	var storm_words: Array[VocabularyEntry] = [VocabularyEntry.new("lumen", "光")]
	storm.start_baseline(storm_book.id, storm_words, "normal", "fluid-storm", false)
	var storm_options := AppSettings.new(evidence.path_join("storm.cfg"))
	storm_options.sound = false
	var storm_page := BattlePage.create(storm, storm_options, storm_book)
	root.add_child(storm_page)
	var storm_router := InputRouter.new()
	storm_router.typing = storm.typing
	storm_router.configure(InputRouter.Context.TYPING)
	storm_router.action_requested.connect(storm.queue_action)
	storm_page.add_child(storm_router)
	await create_timer(2.0).timeout
	storm.typing.select_target(storm.enemies[0].id)
	for character in storm.typing.word:
		await _key(character.to_upper().unicode_at(0) as Key, character.unicode_at(0))
	await create_timer(.07).timeout
	_check(storm_page.visuals.fluid._emitters.any(func(emitter: FluidEmitter2D) -> bool: return emitter.profile.along_path and emitter.end_offset.length_squared() > 1.0), "real lightning impact contributes a native light along its arc")
	await _capture("storm-fog-light")
	await create_timer(.5).timeout
	storm_page.queue_free()
	await _settle()


func _deployment(home: ArchiveHome) -> void:
	home.set_prepared(true)
	await create_timer(.9).timeout
	_check(home.fluid.obstacles.is_empty(), "projected books never erase a solid column of fog")
	for i in home.book_visuals.size():
		if home.book_visuals[i].modulate.a < .02:
			_check(not home.fluid._motion.has(StringName("book_%d" % i)), "faded book unregisters its momentum and light")
	var state := home.fluid.field_texture().get_image()
	for center in [Vector2(.25, .38), Vector2(.75, .38)]:
		var area := Rect2(center - Vector2(.035, .04), Vector2(.07, .08))
		_check(_velocity_energy(state, area) > .1, "clear upper air keeps flowing after side books fade")
	await _capture("home-deployed")
	home.set_prepared(false)
	await create_timer(.8).timeout


func _continuous_motion() -> void:
	var field := FluidAtmosphere.new()
	field.size = Vector2(640, 360)
	root.add_child(field)
	field.set_process(false)
	field.wind = Vector2.ZERO
	field.buoyancy = 0.0
	field.settling = 0.0
	field.turbulence = 0.0
	field.vorticity = 0.0
	field.velocity_decay = 0.0
	field.density_decay = 0.0
	field._ambient[0].density = 0.0
	for quality in [1, 2]:
		field.set_options(quality, false)
		field.reset_field()
		field._motion.clear()
		await _settle()
		var cloud := FluidInfluence.new()
		cloud.center = Vector2(125, 170)
		cloud.extent = Vector2(85, 65)
		cloud.density = 1.0
		field.inject(cloud)
		field._process(1.0 / 60.0)
		await _settle()
		var initial := field.field_texture().get_image()
		# Several fast turns arrive within one displayed frame, including a return
		# leg. The endpoints alone would incorrectly turn this into a short diagonal.
		for point in [Vector2(90, 170), Vector2(480, 170), Vector2(480, 280), Vector2(140, 280)]:
			field.track_body(&"gesture", point, Vector2.ONE * 18, 0, Color.WHITE, 0, false, 36, 1.0, FluidInfluence.BodyShape.POINTED)
		field._process(1.0 / 60.0)
		await _settle()
		var state := field.field_texture().get_image()
		for at in [Vector2(80, 170), Vector2(220, 170), Vector2(380, 170), Vector2(480, 220), Vector2(370, 280), Vector2(180, 280)]:
			var region := Rect2((at - Vector2(8, 8)) / field.size, Vector2(16, 16) / field.size)
			_check(_velocity_energy(state, region) > 8.0, "quality %d fast sweep remains continuous at %s" % [quality, at])
		# A compact incompressible push also returns air at the flanks: the whole
		# broad cloud's centroid can cancel even though its departure patch moves.
		var departure_change := 0.0
		for y in range(int(145.0 / field.size.y * field.grid_size.y), int(195.0 / field.size.y * field.grid_size.y)):
			for x in range(int(70.0 / field.size.x * field.grid_size.x), int(155.0 / field.size.x * field.grid_size.x)):
				departure_change = maxf(departure_change, absf(state.get_pixel(x, y).b - initial.get_pixel(x, y).b))
		_check(departure_change > .002, "quality %d departure mist deforms on the very first tick: %.5f" % [quality, departure_change])
		var origin_area := Rect2(Vector2(68, 130) / field.size, Vector2(50, 28) / field.size)
		_check(_velocity_energy(state, origin_area) > 1.0, "quality %d pressure disturbs air surrounding the departure point" % quality)
		field.set_active(false)
		field.track_body(&"gesture", Vector2(600, 60), Vector2.ONE * 18, 0, Color.WHITE)
		field._process(.1)
		field.set_active(true)
		field._process(1.0 / 60.0)
		_check(field._scene_sources.all(func(source: FluidInfluence) -> bool: return source.displacement_radius == 0.0 or (source.sweep_length == 0.0 and source.velocity == Vector2.ZERO)), "resuming does not sweep across motion made while inactive")
		field.reset_field()
		field._motion.clear()
		await _settle()
		var rear_cloud := FluidInfluence.new()
		rear_cloud.center = Vector2(262, 151)
		rear_cloud.extent = Vector2(22, 18)
		rear_cloud.density = 1.0
		field.inject(rear_cloud)
		field._process(1.0 / 60.0)
		await _settle()
		var rear_initial := field.field_texture().get_image()
		var rear_center := _density_center(rear_initial)
		var rear_mass := _density_sum(rear_initial)
		field.track_body(&"body", Vector2(320, 180), Vector2.ONE * 40, 0, Color.WHITE, 0, true, 24)
		for step in 3:
			field.track_body(&"body", Vector2(330 + step * 10, 180), Vector2.ONE * 40, 0, Color.WHITE, 0, true, 24)
			field._process(1.0 / 30.0)
			await _settle()
		var refill := field.field_texture().get_image()
		var upper := refill.get_pixelv(Vector2i(Vector2(280, 155) / field.size * Vector2(field.grid_size)))
		var lower := refill.get_pixelv(Vector2i(Vector2(280, 205) / field.size * Vector2(field.grid_size)))
		_check(upper.r > 5.0 and upper.g > 5.0 and lower.r > 5.0 and lower.g < -5.0,
			"quality %d rear-side air converges into the departing body's wake: upper %s lower %s" % [quality, upper, lower])
		var rear_after := _density_center(refill)
		var peak := 0.0
		for y in refill.get_height():
			for x in refill.get_width():
				peak = maxf(peak, refill.get_pixel(x, y).b)
		_check(peak <= 1.001, "passive mist does not brighten from residual pressure compression")
		print("Fluid rear refill: quality ", quality, " | upper ", Vector2(upper.r, upper.g), " lower ", Vector2(lower.r, lower.g),
			" | mist displacement ", (rear_after - rear_center) * field.size / Vector2(field.grid_size), " | mass ratio ", _density_sum(refill) / rear_mass)
		_check(rear_after.x > rear_center.x + .1 and rear_after.y > rear_center.y + .08,
			"quality %d existing rear mist moves forward and inward: %s -> %s" % [quality, rear_center, rear_after])
		_check(_density_sum(refill) > rear_mass * .85 and _density_sum(refill) < rear_mass * 1.15,
			"quality %d rear refill transports existing mist without creating a plume" % quality)
	field.queue_free()
	await _settle()
	# Let the real battle ambient field reach a mature state without combat VFX.
	var arena := FluidAtmosphere.new()
	arena.battle = BattleSession.new()
	arena.size = Vector2(960, 540)
	root.add_child(arena)
	arena.set_process(false)
	await _settle()
	for i in 600:
		arena._process(.05)
		await process_frame
		await RenderingServer.frame_post_draw
	var ambient := arena.field_texture().get_image()
	var total := _density_sum(ambient) / (ambient.get_width() * ambient.get_height())
	_check(total < .1, "battle ambient stays thin after 30 simulated seconds: %.4f" % total)
	await _capture("battle-ambient-mature")
	arena.battle.free()
	arena.battle = null
	arena.queue_free()
	await _settle()


func _wake_transport() -> void:
	var field := FluidAtmosphere.new()
	var session := BattleSession.new()
	field.battle = session
	field.size = Vector2(960, 540)
	root.add_child(field)
	field.set_process(false)
	field.wind = Vector2.ZERO
	field.turbulence = 0.0
	field.vorticity = 0.0
	field.buoyancy = 0.0
	field.settling = 0.0
	field.density_decay = 0.0
	field._ambient[0].density = 0.0
	for row in 3:
		var effect := BattleEffect.new()
		effect.origin = Vector2(740, 130 + row * 120) / field.size
		var projectile := BattleProjectile.new(effect)
		session.projectiles.append(projectile)
	field._process(1.0 / 60.0)
	for step in 30:
		for projectile in session.projectiles:
			projectile.position.x -= 15.0 / field.size.x
			projectile.previous_position = projectile.position
		field._process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
	var trails := field.field_texture().get_image()
	for row in 3:
		var area := Rect2i(Vector2i(Vector2(540, 80 + row * 120) / field.size * Vector2(field.grid_size)), Vector2i(Vector2(180, 100) / field.size * Vector2(field.grid_size)))
		var old_tail := trails.get_region(area)
		_check(_density_sum(old_tail) > .5, "three projectiles leave mist in the already travelled region")
		var center_y := (_density_center(old_tail).y + area.position.y + .5) * field.size.y / field.grid_size.y
		_check(absf(center_y - (130 + row * 120)) < 8.0, "parallel old trails do not gather into an artificial common suction: %.2f" % center_y)
	await _capture("parallel-wakes")
	session.projectiles.clear()
	field._motion.clear()
	field.reset_field()
	await _settle()
	session.player_position = Vector2(220, 270) / field.size
	session.previous_player_position = session.player_position
	field._process(1.0 / 60.0)
	field.present({"kind": &"dodge", "at": session.player_position, "target": Vector2(460, 270) / field.size})
	field._dodge_trail.set_process(false)
	for step in 30:
		var time := (step + 1) / 60.0
		var fraction := 1.0 - pow(1.0 - minf(time / .17, 1.0), 3)
		session.player_position.x = lerpf(220, 460, fraction) / field.size.x
		session.previous_player_position = session.player_position
		field._dodge_trail.age = time
		field._process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if step == 10:
			var stopped := field._dodge_trail.sample(1.0 / 60.0)
			_check(field._dodge_trail.strength() > 0.0 and stopped.all(func(source: FluidInfluence) -> bool: return source.density == 0.0), "a stopped but still live distance-emitter adds no terminal fog pool")
	var dodge := field.field_texture().get_image()
	var nose := dodge.get_region(Rect2i(Vector2i(Vector2(530, 160) / field.size * Vector2(field.grid_size)), Vector2i(Vector2(180, 220) / field.size * Vector2(field.grid_size))))
	var trail := dodge.get_region(Rect2i(Vector2i(Vector2(230, 210) / field.size * Vector2(field.grid_size)), Vector2i(Vector2(210, 120) / field.size * Vector2(field.grid_size))))
	var forward_fraction := _density_sum(nose) / maxf(_density_sum(trail), .00001)
	print("Fluid dodge forward mist / rear trail: ", forward_fraction)
	_check(forward_fraction < .05, "dodge retains a rear trail instead of launching a detached forward fog ring")
	await _capture("dodge-settled")
	session.free()
	field.battle = null
	field.queue_free()
	await _settle()


func _material_and_effects() -> void:
	var field := FluidField2D.new()
	field.size = Vector2(640, 360)
	field.wind = Vector2.ZERO
	field.vorticity = 0.0
	field.buoyancy = 65.0
	field.settling = 2.0
	root.add_child(field)
	field.set_process(false)
	await _settle()
	var cold := FluidInfluence.new()
	cold.center = Vector2(270, 180)
	cold.extent = Vector2(100, 100)
	cold.density = 1.0
	cold.temperature = -1.0
	cold.color = Color.RED
	var hot := cold.duplicate() as FluidInfluence
	hot.center.x = 370
	hot.temperature = 1.0
	hot.color = Color.BLUE
	field.inject(cold)
	field.inject(hot)
	field._process(.04)
	await _settle()
	var state := field.field_texture().get_image()
	var matter := field._gpu.matter_texture.get_image()
	var mixed_cell := Vector2i(Vector2(320, 180) / field.size * Vector2(field.fog_grid_size))
	var pigment := matter.get_pixelv(mixed_cell)
	_check(pigment.r > .1 and pigment.b > .1 and absf(pigment.r - pigment.b) < .15, "different emitters mix advected color by density")
	for i in 20:
		field._process(.04)
		await process_frame
		await RenderingServer.frame_post_draw
	state = field.field_texture().get_image()
	matter = field._gpu.matter_texture.get_image()
	var cold_cell := Vector2i(cold.center / field.size * Vector2(field.grid_size))
	var hot_cell := Vector2i(hot.center / field.size * Vector2(field.grid_size))
	_check(state.get_pixelv(cold_cell).g > 0.0 and state.get_pixelv(hot_cell).g < 0.0, "signed temperature makes cold mist settle and hot mist rise")
	var cold_matter_cell := Vector2i(cold.center / field.size * Vector2(field.fog_grid_size))
	_check(matter.get_pixelv(cold_matter_cell).a / state.get_pixelv(cold_cell).b > .5, "material age travels and increases in the solver")
	var mass := _density_sum(state)
	var pusher := FluidInfluence.new()
	pusher.center = Vector2(310, 180)
	pusher.extent = Vector2(160, 130)
	pusher.velocity = Vector2(400, 0)
	pusher.coupling = 24.0
	field.sources.append(pusher)
	for i in 8:
		field._process(.04)
		await process_frame
		await RenderingServer.frame_post_draw
	state = field.field_texture().get_image()
	_check(_density_sum(state) > mass * .7 and _density_sum(state) < mass * 1.1, "momentum displacement preserves fog instead of erasing or injecting it: %.3f -> %.3f" % [mass, _density_sum(state)])
	_check(_density_center(state).x > 80, "moving body's broad footprint transports material forward")
	field.sources.clear()
	field.buoyancy = 0.0
	field.settling = 0.0
	# Compare body kernels in empty air, then remove the source: air must retain
	# momentum without density, while the pointed nose spreads it longitudinally.
	pusher.displacement_radius = 18.0
	pusher.center = Vector2(320, 180)
	pusher.extent = Vector2.ONE * 57.6
	pusher.velocity = Vector2(600, 0)
	var nose_energies: Array[float] = []
	for body_shape in [FluidInfluence.BodyShape.BLUNT, FluidInfluence.BodyShape.POINTED]:
		field.reset_field()
		await _settle()
		pusher.body_shape = body_shape
		field.sources.assign([pusher])
		field._process(1.0 / 60.0)
		await _settle()
		var driven := field.field_texture().get_image()
		_check(_density_sum(driven) == 0.0, "body shape %d moves air without manufacturing mist" % body_shape)
		_check(_velocity_energy(driven, Rect2(Vector2(308, 172) / field.size, Vector2(24, 16) / field.size)) > 30.0, "small body shape %d has a clear local response" % body_shape)
		nose_energies.append(_velocity_energy(driven, Rect2(Vector2(385, 170) / field.size, Vector2(12, 20) / field.size)))
		field.sources.clear()
		field._process(1.0 / 30.0)
		await _settle()
		_check(_velocity_energy(field.field_texture().get_image()) > _velocity_energy(driven) * .5, "stopping body shape %d retains air inertia" % body_shape)
	_check(nose_energies[1] > nose_energies[0] * 2.0, "pointed flow tapers along its nose rather than reusing the round footprint: %s" % str(nose_energies))
	field.turbulence = .85
	var eddy_energies: Array[float] = []
	for fog_amount in [0.0, 1.0]:
		field.reset_field()
		await _settle()
		var cloud := FluidInfluence.new()
		cloud.center = Vector2(320, 180)
		cloud.extent = Vector2(220, 140)
		cloud.density = fog_amount
		field.inject(cloud)
		for i in 4:
			field._process(.04)
			await process_frame
			await RenderingServer.frame_post_draw
		eddy_energies.append(_velocity_energy(field.field_texture().get_image()))
	_check(eddy_energies[0] > .05 and is_equal_approx(eddy_energies[0], eddy_energies[1]), "ambient air evolves identically with and without passive fog: %s" % str(eddy_energies))
	var curl_details: Array[float] = []
	for detail in [0.0, .8]:
		field.turbulence_detail = detail
		field.reset_field()
		await _settle()
		var cloud := FluidInfluence.new()
		cloud.center = Vector2(320, 180)
		cloud.extent = Vector2(220, 140)
		cloud.density = 1.0
		cloud.initial_age = 2.0
		field.inject(cloud)
		for i in 8:
			field._process(1.0 / 60.0)
			await process_frame
			await RenderingServer.frame_post_draw
		curl_details.append(_velocity_detail(field.field_texture().get_image()))
	_check(curl_details[1] > curl_details[0] * 1.3, "fine eddies add resolved local flow detail without changing the emitted cloud: %s" % str(curl_details))
	field.reset_field()
	await _settle()
	var pull := field.emit_effect(load("res://ui/effects/presets/suction.tres"), Vector2(320, 180))
	for i in 12:
		field._process(.04)
		await process_frame
		await RenderingServer.frame_post_draw
	state = field.field_texture().get_image()
	_check(_density_sum(state) == 0.0 and _velocity_energy(state) > 1.0, "suction profile moves empty air without manufacturing fog")
	_check(state.get_pixel(60, 45).r > 0.0 and state.get_pixel(100, 45).r < 0.0, "signed radial field pulls from both sides")
	pull.hide()
	field._process(.04)
	await _settle()
	_check(pull.strength() == 0.0, "hidden effect stops contributing")
	pull.queue_free()
	var flash := field.emit_effect(load("res://ui/effects/presets/electric_flash.tres"), Vector2(320, 180))
	field._sync_lights()
	_check(field._lights.any(func(light: PointLight2D) -> bool: return light.enabled and light.energy > 1.0), "effect resource drives the shared native light pool")
	await create_timer(.35).timeout
	_check(not is_instance_valid(flash) and field._emitters.is_empty(), "effect lifetime unregisters sources and lights")
	field.queue_free()
	await _settle()


func _particle_transport(field: FluidField2D, at: Vector2) -> void:
	var particles := GPUParticles2D.new()
	particles.position = field.get_global_transform() * at
	particles.amount = 1
	particles.lifetime = 5
	particles.one_shot = true
	particles.explosiveness = 1
	particles.use_fixed_seed = true
	particles.texture = GradientTexture2D.new()
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0
	motion.gravity = Vector3.ZERO
	motion.initial_velocity_min = 0
	motion.initial_velocity_max = 0
	particles.process_material = motion
	root.add_child(particles)
	field.bind_particles(particles, 8)
	await create_timer(.15).timeout
	var before := particles.capture_rect().get_center()
	await create_timer(.5).timeout
	var travelled := particles.capture_rect().get_center() - before
	_check(travelled.dot(Vector2.RIGHT.rotated(field.rotation)) > 2.0, "GPU particle with zero initial velocity is transported by the same field")
	particles.queue_free()
	await _settle()


func _home_lighting(home: ArchiveHome) -> void:
	var field := home.fluid
	home.set_process(false)
	field.set_process(false)
	var hidden: Array[CanvasItem] = []
	for child in home.stage.scenery.get_children():
		if child is CanvasItem and child != field and child.visible:
			hidden.append(child)
			child.hide()
	await _settle()
	var fog_lit := _image_energy(home.stage.viewport.get_texture().get_image())
	for light in field._lights:
		light.enabled = false
	await _settle()
	var fog_dark := _image_energy(home.stage.viewport.get_texture().get_image())
	_check(fog_lit > fog_dark + .000001, "native PointLight2D lights the density material, isolated from other scenery")
	field._surface.hide()
	home.paper.show()
	await _settle()
	var paper_dark := _image_energy(home.stage.viewport.get_texture().get_image())
	field._sync_lights()
	await _settle()
	var paper_lit := _image_energy(home.stage.viewport.get_texture().get_image())
	_check(paper_lit > paper_dark + .00001, "the same native lights illuminate the scene surface shader")
	print("Native light response: ", {"fog_delta": fog_lit - fog_dark, "paper_delta": paper_lit - paper_dark})
	for child in hidden:
		child.show()
	field.update_appearance()
	field.set_process(true)
	home.set_process(true)
	await _settle()


func _image_energy(image: Image) -> float:
	var energy := 0.0
	var count := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			energy += color.r + color.g + color.b
			count += 1
	return energy / count


func _key(code: Key, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _velocity_energy(image: Image, region: Rect2 = Rect2(0, 0, 1, 1)) -> float:
	var energy := 0.0
	var count := 0
	for y in range(int(region.position.y * image.get_height()), int(region.end.y * image.get_height())):
		for x in range(int(region.position.x * image.get_width()), int(region.end.x * image.get_width())):
			var pixel := image.get_pixel(x, y)
			energy += Vector2(pixel.r, pixel.g).length()
			count += 1
	return energy / count


func _velocity_detail(image: Image) -> float:
	var total := 0.0
	for y in range(1, image.get_height() - 1):
		for x in range(1, image.get_width() - 1):
			var laplacian := image.get_pixel(x, y) * 4.0 - image.get_pixel(x - 1, y) - image.get_pixel(x + 1, y) - image.get_pixel(x, y - 1) - image.get_pixel(x, y + 1)
			total += Vector2(laplacian.r, laplacian.g).length()
	return total / (image.get_width() * image.get_height())


func _timestamp(label: String) -> void:
	RenderingServer.get_rendering_device().capture_timestamp(label)


func _read_timestamps() -> void:
	var rd := RenderingServer.get_rendering_device()
	var frame := rd.get_captured_timestamps_frame()
	if frame == _last_timestamp_frame:
		return
	_last_timestamp_frame = frame
	var start := -1
	for index in rd.get_captured_timestamps_count():
		var name := rd.get_captured_timestamp_name(index)
		if name == "fluid_begin":
			start = rd.get_captured_timestamp_gpu_time(index)
		elif name == "fluid_end" and start >= 0:
			call_deferred("_add_timing", float(rd.get_captured_timestamp_gpu_time(index) - start))


func _add_timing(value: float) -> void:
	timings.append(value)


func _density_sum(image: Image) -> float:
	var sum := 0.0
	var finite := true
	for y in image.get_height():
		for x in image.get_width():
			var value := image.get_pixel(x, y)
			finite = finite and is_finite(value.r) and is_finite(value.g) and is_finite(value.b)
			sum += value.b
	_check(finite, "finite GPU state")
	return sum


func _density_center(image: Image) -> Vector2:
	var sum := 0.0
	var center := Vector2.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var density := image.get_pixel(x, y).b
			sum += density
			center += Vector2(x, y) * density
	return center / maxf(sum, .00001)


func _settle() -> void:
	for i in 5:
		await process_frame
		await RenderingServer.frame_post_draw


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if root.use_hdr_2d and not _movie_srgb:
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, image.get_pixel(x, y).linear_to_srgb())
	image.convert(Image.FORMAT_RGBA8)
	image.save_png(evidence.path_join(label + ".png"))


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Fluid test failed: " + label)
