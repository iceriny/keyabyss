class_name VocabularySampler
extends RefCounted
## A session owns reservations; the shared vocabulary index stays immutable.

var index: VocabularyIndex
var used: int = 0
var selected: Dictionary[StringName, int] = {}


func _init(prepared: VocabularyIndex) -> void:
	index = prepared


func take(owner: StringName, rng: RandomNumberGenerator, minimum: int, maximum: int, prefer_long: bool = false) -> VocabularyEntry:
	assert(not selected.has(owner))
	minimum = maxi(1, minimum)
	maximum = mini(24, maximum)
	if prefer_long and index.count(used, maxi(7, minimum), maximum) > 0:
		minimum = maxi(7, minimum)
	var total := index.count(used, minimum, maximum)
	if total == 0: return null
	var entry := index.at_rank(rng.randi_range(0, total - 1), used, minimum, maximum)
	var letter := entry.word.unicode_at(0) - 97
	selected[owner] = letter
	used |= 1 << letter
	return entry


func release(owner: StringName) -> void:
	if selected.has(owner):
		used &= ~(1 << selected[owner])
		selected.erase(owner)
