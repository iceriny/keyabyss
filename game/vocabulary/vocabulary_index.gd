class_name VocabularyIndex
extends RefCounted
## Immutable, persisted letter/length index. Length excludes phrase spaces.

const VERSION := 1
const MAX_LENGTH := 24
var entries: Array[VocabularyEntry] = []
var buckets: Array[PackedInt32Array] = []
var prefix := PackedInt32Array()
var meanings: Dictionary[String, String] = {}
var shortest := MAX_LENGTH


static func build(source: Array[VocabularyEntry]) -> VocabularyIndex:
	var index := VocabularyIndex.new()
	index.entries = source.duplicate()
	index.prefix.resize(26 * (MAX_LENGTH + 1))
	for letter in 26: index.buckets.append(PackedInt32Array())
	for id in source.size():
		var entry := source[id]
		var letter := entry.word.unicode_at(0) - 97
		index.buckets[letter].append(id)
		index.prefix[letter * 25 + entry.playable_length()] += 1
		index.meanings[entry.word] = entry.meaning
		index.shortest = mini(index.shortest, entry.playable_length())
	for letter in 26:
		var ids: Array[int] = []
		ids.assign(index.buckets[letter])
		ids.sort_custom(func(a: int, b: int) -> bool: return source[a].playable_length() < source[b].playable_length())
		index.buckets[letter] = PackedInt32Array(ids)
		for length in range(1, 25):
			index.prefix[letter * 25 + length] += index.prefix[letter * 25 + length - 1]
	return index


func count(used: int, minimum: int, maximum: int) -> int:
	if minimum > maximum: return 0
	var total := 0
	for letter in 26:
		if used & (1 << letter) == 0:
			total += prefix[letter * 25 + maximum] - prefix[letter * 25 + minimum - 1]
	return total


func at_rank(rank: int, used: int, minimum: int, maximum: int) -> VocabularyEntry:
	for letter in 26:
		if used & (1 << letter): continue
		var start := prefix[letter * 25 + minimum - 1]
		var size := prefix[letter * 25 + maximum] - start
		if rank < size: return entries[buckets[letter][start + rank]]
		rank -= size
	return null


func to_data() -> Dictionary:
	var words: Array = []
	for entry in entries: words.append([entry.word, entry.meaning])
	return {"version": VERSION, "words": words, "buckets": buckets, "prefix": prefix, "shortest": shortest}


static func from_data(data: Dictionary) -> VocabularyIndex:
	var index := VocabularyIndex.new()
	for word: Array in data.words:
		index.entries.append(VocabularyEntry.new(word[0], word[1]))
		index.meanings[word[0]] = word[1]
	index.buckets.assign(data.buckets)
	index.prefix = data.prefix
	index.shortest = data.shortest
	return index
