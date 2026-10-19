extends Node
## Keep the first frame independent from gameplay scripts and their resources.

@onready var ritual: DepartureRitual = $Overlay/DepartureRitual
var preparation: Node
var application: Node
var _loading := true
var settings := AppSettings.new()
var _vocabulary_worker := Thread.new()


func _enter_tree() -> void:
	# Set the final output before the loading scene presents its first frame.
	settings.load_settings()
	get_window().size_changed.connect(_resize_output)
	settings.apply(get_window())
	$Overlay/DepartureRitual.reduced_motion = settings.reduce_motion


func _ready() -> void:
	_run.call_deferred()


func _input(event: InputEvent) -> void:
	if _loading and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()


func _run() -> void:
	ritual.feedback.update_stage("正在载入画面资源", 0, 0)
	await _present()
	var scene := await _load_scene("res://ui/scenes/render_preparation.tscn")
	if scene == null: return
	preparation = scene.instantiate()
	add_child(preparation)
	await preparation.prepare(ritual.feedback)
	ritual.feedback.update_stage("正在载入书库", 0, 0)
	await _present()
	var main := await _load_scene("res://app/main.tscn")
	if main == null: return
	ritual.feedback.update_stage("正在准备战斗音效", 0, 0)
	await SoundBank.prepare(BattleAudio.CUE_GAIN.keys(), get_tree())
	application = main.instantiate()
	application.settings = settings
	application.settings_prepared = true
	# Read or rebuild persistent vocabulary indices while the welcome stays live.
	_vocabulary_worker.start(application.vocabulary.prepare_catalog)
	while _vocabulary_worker.is_alive(): await _present()
	_vocabulary_worker.wait_to_finish()
	application.process_mode = Node.PROCESS_MODE_DISABLED
	# ArchiveGate remains the authored welcome ritual after resource preparation.
	add_child(application)
	get_window().size_changed.disconnect(_resize_output)
	while not application.initialized: await _present()
	await _present()
	await _present()
	application.welcome_gate.reveal_from_loading(ritual)
	await application.welcome_gate.welcome_ready
	application.process_mode = Node.PROCESS_MODE_ALWAYS
	_loading = false
	set_process_input(false)
	print("[RENDER] Startup preparation complete")


func _load_scene(path: String) -> PackedScene:
	# Loading the preparation's inherited script/resource graph on a worker
	# leaves zero-reference placeholders behind in the locked Mono engine.
	# Resolve that graph on the main thread after the loading frame is shown.
	if path == "res://ui/scenes/render_preparation.tscn":
		return load(path) as PackedScene
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error != OK:
		ritual.feedback.show_error("资源载入失败：%s" % error_string(error))
		push_error("Startup load failed: %s (%s)" % [path, error_string(error)])
		return null
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ritual.feedback.show_error("资源载入失败，请检查游戏文件")
			push_error("Startup resource failed: " + path)
			return null
		await get_tree().process_frame
	return null


func _present() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _resize_output() -> void:
	settings.update_output(get_window())


func _exit_tree() -> void:
	# A close during index preparation must finish the reader before disposing
	# its application, which has not entered the tree yet.
	if _vocabulary_worker.is_started():
		_vocabulary_worker.wait_to_finish()
	if is_instance_valid(application) and application.get_parent() == null:
		application.free()
