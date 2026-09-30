extends SceneTree
## Explicit network smoke test for the first upstream book; run manually when syncing changes.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var evidence := "res://.temp/godot-m1/upstream-" + str(Time.get_ticks_usec())
	var app := load("res://app/main.tscn").instantiate() as KeyabyssApp
	app.settings = AppSettings.new(evidence.path_join("settings.cfg"))
	app.vocabulary = VocabularyRepository.new(evidence.path_join("vocabulary"))
	app.presentation_enabled = false
	root.add_child(app)
	for i in 3:
		await process_frame
	app._vocabulary_page()
	app._show_vocabulary("primary1")
	await app._sync_vocabulary("primary1")
	var id := "sync-primary1"
	var entries := app.vocabulary.load_entries(id)
	if entries.is_empty() or app.route != "words" or app.selected_id != id:
		failures += 1
		push_error("Upstream sync failed: " + app.page.status.text + " / " + app.vocabulary.last_error)
	else:
		print("Upstream sync succeeded: ", entries.size(), " words; ", app.page.status.text)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
