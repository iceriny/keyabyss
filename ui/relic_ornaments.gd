class_name RelicOrnaments
extends RefCounted

const NAMES := ["crescent", "quartz", "fan", "sail", "ribbon", "shell",
	"fern", "tide", "wing", "fold", "petals", "shards"]
static var _prepared: Dictionary[String, Texture2D] = {}


static func prepare(indices: PackedInt32Array, tree: SceneTree) -> void:
	var paths: Array[String] = []
	for index in indices:
		for suffix: String in [".png", "_optics.exr"]:
			var path: String = "res://assets/art/ui/relic_ornaments/" + NAMES[index] + suffix
			if _prepared.has(path): continue
			var error := ResourceLoader.load_threaded_request(path, "Texture2D")
			assert(error == OK, "Ornament request failed: " + path)
			paths.append(path)
	for path in paths:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
		_prepared[path] = ResourceLoader.load_threaded_get(path) as Texture2D
		assert(_prepared[path] != null, "Ornament load failed: " + path)


static func for_offer(candidates: Array) -> PackedInt32Array:
	assert(candidates.size() <= NAMES.size())
	# Stable across reopening the offer; decorative choices never consume run RNG.
	var variants := PackedInt32Array()
	for id: String in candidates:
		var index := posmod(hash(id), NAMES.size())
		while index in variants:
			index = (index + 1) % NAMES.size()
		variants.append(index)
	return variants


static func texture(index: int) -> Texture2D:
	return load("res://assets/art/ui/relic_ornaments/%s.png" % NAMES[index]) as Texture2D


static func optics(index: int) -> Texture2D:
	return load("res://assets/art/ui/relic_ornaments/%s_optics.exr" % NAMES[index]) as Texture2D
