class_name SoundBank
extends RefCounted
## Every consumer owns its no-repeat history; PCM resources remain shared.


static func load_cue(cue: String) -> AudioStreamRandomizer:
	var pool := load("res://assets/audio/cues/%s.tres" % cue) as AudioStreamRandomizer
	return pool.duplicate() as AudioStreamRandomizer
