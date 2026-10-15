class_name RelicOrnaments
extends RefCounted

const NAMES := ["crescent", "quartz", "fan", "sail", "ribbon", "shell",
	"fern", "tide", "wing", "fold", "petals", "shards"]


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
