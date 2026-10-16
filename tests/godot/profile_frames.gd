extends SceneTree
## Repeatable window-only idle sampling; run with -- --frame-profile.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var label := "sample"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-label="):
			label = argument.trim_prefix("--profile-label=").validate_filename()
	var evidence := "res://.temp/frame-review/" + label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.size = Vector2i(1920, 1080)
	var app := load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.settings.completed_lessons.assign(AppSettings.TUTORIAL_IDS)
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	var capture := load("res://app/frame_capture.gd").new() as Node
	capture.set("output_path", evidence.path_join("frames.json"))
	app.add_child(capture)
	await create_timer(8.0).timeout
	app._settings_page("home")
	await create_timer(8.0).timeout
	app._start_battle()
	await create_timer(8.0).timeout
	var hidden_clock := app.archive.clock
	print("Hidden archive: can_process=%s viewport=%d clock=%.3f" % [app.archive.can_process(), app.archive.stage.viewport.render_target_update_mode, hidden_clock])
	await create_timer(3.0).timeout
	print("Hidden archive clock advance: %.3f" % (app.archive.clock - hidden_clock))
	assert(app.archive.clock == hidden_clock and not app.archive.can_process())
	assert(app.archive.stage.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	app._home()
	await create_timer(0.3).timeout
	assert(app.archive.can_process() and app.archive.clock > hidden_clock)
	assert(app.archive.stage.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	quit()
