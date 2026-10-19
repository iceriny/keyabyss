class_name SoundBank
extends RefCounted
## Every consumer owns its no-repeat history; PCM resources remain shared.

static var _pools: Dictionary[String, AudioStreamRandomizer] = {}


static func prepare(cues: Array, tree: SceneTree) -> void:
	# Bound outstanding I/O; only collect completed resources on the main thread.
	for offset in range(0, cues.size(), 4):
		var pending: Array[String] = []
		for index in range(offset, mini(offset + 4, cues.size())):
			var cue: String = cues[index]
			if _pools.has(cue): continue
			var path := "res://assets/audio/cues/%s.tres" % cue
			var error := ResourceLoader.load_threaded_request(path, "AudioStreamRandomizer")
			assert(error == OK, "Audio request failed: %s (%s)" % [path, error_string(error)])
			pending.append(cue)
		for cue in pending:
			var path := "res://assets/audio/cues/%s.tres" % cue
			while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await tree.process_frame
			_pools[cue] = ResourceLoader.load_threaded_get(path) as AudioStreamRandomizer
			assert(_pools[cue] != null, "Audio load failed: " + path)


static func load_cue(cue: String) -> AudioStreamRandomizer:
	if not _pools.has(cue):
		_pools[cue] = load("res://assets/audio/cues/%s.tres" % cue) as AudioStreamRandomizer
	return _pools[cue].duplicate() as AudioStreamRandomizer
