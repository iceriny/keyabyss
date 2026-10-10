extends SceneTree
## Runtime regression for input ownership, first/repeat entry, and animated layers.
var app: KeyabyssApp
var failures: int = 0
var evidence: String
var cues: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	evidence = "res://.temp/legacy-ui-review/presentation-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	await _create_app()
	var gate := _gate()
	_check(gate != null and not gate.can_skip, "first visit owns input and cannot skip the ritual")
	gate.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	await _key(KEY_F11)
	_check(app.settings.fullscreen and not gate.started and cues.is_empty(), "F11 changes display without starting the ritual")
	await _key(KEY_F11)
	await create_timer(.15).timeout
	await _capture("01-ready")
	await _key(KEY_A,97)
	await create_timer(.42).timeout
	await _key(KEY_ENTER)
	_check(is_instance_valid(gate) and not gate.skipping and app.router.buffer.is_empty(), "entry gesture and early second key cannot leak into menu commands")
	await _capture("02-first-wave")
	while is_instance_valid(gate) and gate.elapsed < 2.65:
		await process_frame
	await _capture("03-heavy-wave")
	while is_instance_valid(gate):
		await process_frame
	_check(cues == ["ui.enter","ui.ritualRise","ui.ritualImpact","ui.ritualChime"], "ritual cues occur once in source order")
	_check(app.route == "home" and app.router.context == InputRouter.Context.MENU and app.settings.intro_complete, "ritual hands input back to the archive and persists completion")
	await _capture("04-arrived")
	var rear_book := app.archive.cards[3]
	var rear_material := app.archive.artworks[3].material as ShaderMaterial
	var resting_blur: float = rear_material.get_shader_parameter("blur_pixels")
	await _mouse_at(root.get_screen_transform() * rear_book.get_global_transform() * (rear_book.size * .5))
	await create_timer(.08).timeout
	_check(app.archive.hover_amount[3] > 0.0 and app.archive.hover_amount[3] < .9 and float(rear_material.get_shader_parameter("blur_pixels")) < resting_blur, "hover clarity and brightness ease toward the pointer instead of snapping")
	await create_timer(.65).timeout
	_check(app.archive.hover_amount[3] > .98 and float(rear_material.get_shader_parameter("blur_pixels")) < .1, "hovered rear book becomes clear after settling")
	await _capture("04-hover-clear")
	await _mouse_at(Vector2(5,5))
	await create_timer(.08).timeout
	_check(app.archive.hover_amount[3] > .05 and app.archive.hover_amount[3] < .95, "pointer exit smoothly restores depth blur")
	var menu_button := app.archive.menu.find_child("Vocab", true, false) as OpenButton
	await _mouse_at(root.get_screen_transform() * menu_button.get_global_transform() * (menu_button.size * 0.5))
	await create_timer(.4).timeout
	await _capture("04-menu-hover")
	app.queue_free()
	await process_frame
	await _create_app()
	gate = _gate()
	cues.clear()
	gate.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	_check(gate.can_skip, "repeat visit enables skip from persisted completion")
	await _key(KEY_ENTER)
	await create_timer(.4).timeout
	await _key(KEY_ENTER)
	await create_timer(.75).timeout
	_check(not is_instance_valid(gate) and cues == ["ui.enter"], "skip dissolves the current frame and cancels remaining ritual cues")
	app.settings.reduce_motion = true
	app.settings.save_settings()
	app.queue_free()
	await process_frame
	await _create_app()
	gate = _gate()
	cues.clear()
	gate.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	await _key(KEY_ENTER)
	await create_timer(.35).timeout
	_check(not is_instance_valid(gate) and cues == ["ui.enter"] and app.archive.modulate.a == 1., "reduced motion reaches a visible interactive home without light waves")
	app.archive.set_prepared(true)
	await process_frame
	_check(app.archive.left_wing.is_visible_in_tree() and app.archive.deployment == 1. and app.archive.title_group.modulate.a == 0., "reduced motion unfolds readable preparation without displacement or overlapping background text")
	await _capture("05-prepared")
	var original_theme := app.root.theme
	var original_color := app.archive.accent
	var room_rect := app.archive.effects._book_plane.get_rect()
	var emblem_position := app.archive.seal_layers[0].position
	app.archive.select_book(1)
	_check(app.archive.accent.is_equal_approx(original_color), "book selection starts from the displayed accent without a color jump")
	_check(app.archive.effects._book_plane.get_rect() == room_rect and app.archive.seal_layers[1].position == emblem_position and app.archive.seal_weights[0] == 1.0, "room geometry stays anchored while school emblems begin from existing weights")
	await create_timer(.3).timeout
	var intermediate := app.archive.accent
	var intermediate_weights := app.archive.seal_weights.duplicate()
	_check(intermediate_weights[0] > 0.0 and intermediate_weights[1] > 0.0 and is_equal_approx(intermediate_weights[0]+intermediate_weights[1],1.0), "school emblems crossfade without resetting the room or doubling opacity")
	_check(not intermediate.is_equal_approx(original_color) and not intermediate.is_equal_approx(ArchiveHome.BOOKS[1].color), "theme passes through intermediate colors even with reduced motion")
	_check(app.root.theme == original_theme and app.root.theme.get_color("accent", "Archive").is_equal_approx(intermediate) and (app.archive.floor_plane.material as ShaderMaterial).get_shader_parameter("school_color").is_equal_approx(intermediate), "UI and scenery share the interpolated accent without replacing the theme")
	app.archive.select_book(2)
	_check(app.archive.accent.is_equal_approx(intermediate), "interrupted color transition resumes from its current color")
	_check(app.archive.seal_weights == intermediate_weights, "rapid selection preserves the currently blended emblems")
	app._guide()
	_check(app.page.accent.is_equal_approx(intermediate), "page opened during transition inherits its current color")
	await create_timer(.3).timeout
	await _capture("06-theme-transition")
	await create_timer(1.0).timeout
	_check(app.archive.accent.is_equal_approx(ArchiveHome.BOOKS[2].color) and app.page.accent.is_equal_approx(app.archive.accent), "archive and open page settle on the last selected book color")
	_check(is_equal_approx(app.archive.seal_weights[2],1.0) and not app.archive.seal_layers[0].visible and app.archive.effects._book_plane.get_rect() == room_rect, "old emblems retire and the room remains fixed after transition")
	print("Presentation checks: %d failure(s) | %s" % [failures,evidence])
	quit(0 if failures == 0 else 1)

func _create_app() -> void:
	app = load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.sound = false
	# This fixture exercises the welcome and archive; configuration has its own
	# first-entry interaction coverage in test_ui_refinement --setup-feedback.
	app.settings.first_setup_complete = true
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	root.add_child(app)
	await process_frame

func _gate() -> ArchiveGate:
	for child in app.root.get_children():
		if child is ArchiveGate:
			return child as ArchiveGate
	return null

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

func _mouse_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var encoded := Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			encoded.set_pixel(x,y,source.get_pixel(x,y).linear_to_srgb())
	encoded.save_png(evidence.path_join(label+".png"))

func _check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ")+label)
	if not condition:
		failures += 1
