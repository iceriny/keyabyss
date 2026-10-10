extends SceneTree

var failures: int = 0

class CountingRepository extends VocabularyRepository:
	var builds := 0
	func _init(directory: String) -> void:
		super(directory)
	func _store_index(id: String, entries: Array[VocabularyEntry], source: Array) -> void:
		builds += 1
		super._store_index(id, entries, source)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_sampling()
	_check_battle_reservations()
	_check_word_renewal()
	await _check_practice()
	var test_directory := "res://.temp/godot-m1/vocabulary/user/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository := VocabularyRepository.new(test_directory)
	_check(repository.catalog().size() == 12, "built-in catalog")
	_check(repository.load_entries("primary1").size() == 96, "built-in entries")
	_check(repository.load_entries("extension").size() == 84620 and repository.prepared_index("extension").count(0, 1, 8) == 84620, "large built-in string records use the same persisted index")

	var txt := repository.parse_import("\uFEFF# comment\r\nＢＯＯＫ\r\nbook\r\nco_await\r\n", "sample.txt")
	_check(txt.error.is_empty() and txt.entries.size() == 2 and txt.duplicates == 1, "TXT normalization and duplicates")
	_check(txt.entries[0].word == "book" and txt.entries[1].word == "co_await", "fullwidth ASCII and underscore")

	var csv := repository.parse_import("meaning,word\n\"甲,乙\",token\n\"第一行\n第二行\",other\n坏词,中文", "sample.csv")
	_check(csv.entries.size() == 2 and csv.raw_count == 3, "CSV quoted fields and multiline meaning")
	_check(csv.entries[0].meaning == "甲,乙" and csv.entries[1].meaning == "第一行\n第二行", "CSV meanings")
	_check(csv.issues.size() == 1 and csv.issues[0].contains("第 5 行"), "CSV error location")

	var tsv := repository.parse_import("单词\t中文\nhello world\t你好\nlong\t长", "sample.tsv")
	_check(tsv.entries.size() == 2 and tsv.entries[0].playable_length() == 10, "TSV and visible space")
	var json := repository.parse_import("{\"title\":\"词库\",\"words\":[{\"name\":\"true\",\"trans\":[\"真\",\"对\"]}]}", "sample.json")
	_check(json.title == "词库" and json.entries[0].meaning == "真；对", "JSON fields")
	var jsonl := repository.parse_import("{\"word\":\"one\"}\n{\"word\":\"two\"}", "sample.jsonl")
	_check(jsonl.entries.size() == 2, "JSONL records")
	var one_jsonl := repository.parse_import("{\"word\":\"one\"}", "single.jsonl")
	_check(one_jsonl.entries.size() == 1, "single-line JSONL")
	var bad_jsonl := repository.parse_import("\n{\"word\":\"one\"}\n{broken}", "sample.jsonl")
	_check(bad_jsonl.error.contains("第 3 行"), "JSONL error location")
	var limits := repository.parse_import("a b c d e f g\nabcdefghijklmnopqrstuvwxy\n7up\nwe're\nhello-world", "limits.txt")
	_check(limits.entries.size() == 2 and limits.issues.size() == 3, "segment, length and first-letter limits")

	var saved_id := repository.save_import(tsv)
	_check(saved_id.begins_with("custom-") and repository.last_error.is_empty(), "atomic user save")
	if not saved_id.is_empty():
		_check(repository.load_entries(saved_id).size() == 2, "user load")
		var filtered := repository.select_entries(PackedStringArray([saved_id, saved_id]), 4, 4)
		_check(filtered.size() == 1 and filtered[0].word == "long", "strict length filter and deduplication")
		_check(repository.catalog().size() == 13, "isolated custom catalog")
		print("Vocabulary test user directory: ", ProjectSettings.globalize_path(test_directory))
	var sync_source := repository.sync_source("primary1")
	var index_path := test_directory.path_join("indices/primary1.bin")
	_check(FileAccess.file_exists(index_path), "built-in index is persisted before gameplay")
	var cold_repository := CountingRepository.new(test_directory)
	_check(cold_repository.load_entries("primary1").size() == 96 and cold_repository.prepared_index("primary1").count(0, 1, 24) == 96, "fresh repository reads persisted buckets")
	_check(cold_repository.builds == 0, "unchanged persisted vocabulary is not preprocessed again")
	_check(sync_source.get("sources", []).size() == 2, "built-in source has both upstream files")
	var first_sync: Array[VocabularyEntry] = [VocabularyEntry.new("first", "旧释义")]
	var sync_id := repository.save_synced("primary1", first_sync)
	_check(sync_id == "sync-primary1" and repository.load_entries(sync_id).size() == 1, "synced edition is stored separately from the offline snapshot")
	var next_sync: Array[VocabularyEntry] = [VocabularyEntry.new("newer", "新释义")]
	_check(repository.save_synced("primary1", next_sync) == sync_id and repository.load_entries(sync_id)[0].word == "newer", "verified sync replaces its previous edition")
	var reloaded := CountingRepository.new(test_directory)
	reloaded.load_entries(sync_id)
	_check(reloaded.prepared_index(sync_id).meanings.get("newer") == "新释义" and reloaded.prepared_index(sync_id).count(1 << 13, 1, 24) == 0, "sync persists updated buckets and meanings")
	# External edits can keep both file size and timestamp; source comparison must win.
	var source_path := test_directory.path_join(sync_id + ".json")
	var source_text := FileAccess.get_file_as_string(source_path)
	var edited := FileAccess.open(source_path, FileAccess.WRITE)
	edited.store_string(source_text.replace("newer", "other"))
	edited.close()
	reloaded.load_entries(sync_id)
	_check(reloaded.prepared_index(sync_id).entries[0].word == "other" and reloaded.prepared_index(sync_id).count(1 << 14, 1, 24) == 0, "external same-size edit rebuilds and persists index")
	_check(reloaded.builds == 1, "only changed source triggers preprocessing")
	var edited_again := VocabularyRepository.new(test_directory)
	_check(edited_again.load_entries(sync_id)[0].word == "other", "rebuilt index survives a new repository")
	# Restore through the supported update path for the remaining save checks.
	repository.save_synced("primary1", next_sync)
	var invalid_sync: Array[VocabularyEntry] = [VocabularyEntry.new("7bad", "无效")]
	_check(repository.save_synced("primary1", invalid_sync).is_empty() and repository.load_entries(sync_id)[0].word == "newer", "invalid source data leaves the previous edition intact")
	_check(repository.load_entries("primary1").size() == 96 and repository.catalog().size() == 14, "sync does not modify the built-in book")

	if failures == 0:
		print("Vocabulary tests passed")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Vocabulary test failed: " + label)


func _check_sampling() -> void:
	var entries: Array[VocabularyEntry] = []
	for word: String in ["a", "an", "ant", "apple", "be", "bee", "hello world", "we're", "co_await"]:
		entries.append(VocabularyEntry.new(word, word))
	var index := VocabularyIndex.build(entries)
	var restored := VocabularyIndex.from_data(index.to_data())
	# Enumerate every random ticket, so uneven bucket weights are checked exactly.
	for bounds: Vector2i in [Vector2i(1,24), Vector2i(2,3), Vector2i(7,10), Vector2i(20,24)]:
		for mask: int in [0, 1, 3, (1 << 26) - 1]:
			var expected: Array[String] = []
			for entry in entries:
				if (mask & (1 << (entry.word.unicode_at(0) - 97))) == 0 and entry.playable_length() >= bounds.x and entry.playable_length() <= bounds.y:
					expected.append(entry.word)
			var actual: Array[String] = []
			for rank in restored.count(mask, bounds.x, bounds.y): actual.append(restored.at_rank(rank, mask, bounds.x, bounds.y).word)
			actual.sort()
			expected.sort()
			_check(actual == expected, "each legal word owns exactly one ticket %s mask=%d" % [bounds, mask])
	var sampler := VocabularySampler.new(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8301
	var first := sampler.take(&"first", rng, 2, 3)
	var second := sampler.take(&"second", rng, 2, 3)
	_check(first.word[0] != second.word[0] and sampler.take(&"blocked", rng, 2, 3) == null, "strict initial exclusion and exhausted range")
	sampler.release(&"first")
	sampler.release(&"first")
	_check(sampler.take(&"replacement", rng, 2, 3).word[0] == first.word[0], "release restores only its own initial")
	_check(sampler.take(&"phrase", rng, 10, 10).word == "hello world", "range changes and phrase spaces")
	var long_sampler := VocabularySampler.new(index)
	_check(long_sampler.take(&"long", rng, 1, 24, true).playable_length() >= 7, "long-word preference stays within the eligible range")
	_check(long_sampler.take(&"short", rng, 2, 3, true).playable_length() <= 3, "long-word preference never escapes the requested upper bound")
	for size in [100, 10000]:
		var large: Array[VocabularyEntry] = []
		for n in size:
			large.append(VocabularyEntry.new(String.chr(97+n%26) + "word" + String.chr(97+floori(n/26.0)%26) + String.chr(97+floori(n/676.0)%26), ""))
		var prepared := VocabularyIndex.build(large)
		var online := VocabularySampler.new(prepared)
		var started := Time.get_ticks_usec()
		for n in 5000:
			online.take(&"sample", rng, 1, 24)
			online.release(&"sample")
		print("Sampling %d entries: 5000 take/release pairs %.3f ms (preparation excluded)" % [size, (Time.get_ticks_usec()-started)/1000.0])


func _check_battle_reservations() -> void:
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("ant", "蚂蚁"), VocabularyEntry.new("ape", "猿"), VocabularyEntry.new("bee", "蜂"), VocabularyEntry.new("cat", "猫")]
	var session := BattleSession.new()
	session.start_baseline(&"frost", words, "normal", "word-reservations", false)
	var initials: Dictionary = {}
	for enemy in session.enemies:
		initials[enemy.word[0]] = true
		enemy.position = Vector2(.5,.5)
		enemy.combat_locked = true
	_check(initials.size() == 3 and session.spawn_pickup(&"rune") == null, "enemy and pickup reservations share the same mask")
	session._advance_enemies(0.0)
	var target := session.enemies[0]
	session.typing.feed(target.word[0])
	var reserved := session._word_sampler.used
	session.commit_damage(target, target.hp_q, target.hp_q, &"test", target.position)
	_check(session._word_sampler.used == reserved and session.typing.progress == 1, "death retains the in-progress initial")
	session.typing.cancel()
	_check(session._word_sampler.selected.size() == 2, "cancel releases the dead word")
	var pickup := session.spawn_pickup(&"rune")
	_check(pickup != null and pickup.word[0] == target.word[0], "pickup can reuse released initial")
	pickup.age = pickup.life
	session._advance_pickups(0.0)
	_check(not session._word_sampler.selected.has(pickup.id), "pickup expiry releases reservation")
	var waiting := session._spawn_enemy(load("res://game/content/enemies/nib.tres"), Vector2(.5,.5))
	var overflow := session._spawn_enemy(load("res://game/content/enemies/nib.tres"), Vector2(.5,.5))
	_check(not waiting.word.is_empty() and overflow.word.is_empty(), "no duplicate word fallback on exhaustion")
	session.commit_damage(waiting, waiting.hp_q, waiting.hp_q, &"test", waiting.position)
	session._advance_enemies(0.0)
	_check(not overflow.word.is_empty() and session.typing._targets.has(overflow.id), "waiting enemy receives a released initial")
	session.free()


func _check_word_renewal() -> void:
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("ant", ""), VocabularyEntry.new("bee", ""), VocabularyEntry.new("cat", ""), VocabularyEntry.new("dog", "")]
	var session := BattleSession.new()
	session.start_baseline(&"flame", words, "normal", "renewal", false)
	for n in session.enemies.size():
		var enemy := session.enemies[n]
		enemy.position = Vector2(.65+n*.06,.5)
		enemy.previous_position = enemy.position
		enemy.combat_locked = true
		enemy.speed = 0.0
		enemy.attack_clock = 100.0
		enemy.hp_q = 1000 * BattleSession.Q
	session._advance_enemies(0.0)
	var target := session.enemies[0]
	var original := target.word
	for letter in original: session.typing.feed(letter)
	session.step(0.0)
	_check(target.word_pending and session._word_sampler.selected.has(target.id), "in-flight primary retains the word reservation")
	for n in 90: session.step(1.0/60.0)
	_check(not target.word_pending and session.typing._targets.has(target.id) and session._word_sampler.selected.size() == 3, "actual projectile hit renews exactly one reserved word")
	var used: Dictionary = {}
	for enemy in session.enemies:
		if not enemy.word.is_empty(): used[enemy.word[0]] = true
	_check(used.size() == 3, "renewal keeps all active initials distinct")
	session.typing.feed(target.word[0])
	session.commit_damage(target, target.hp_q, target.hp_q, &"test", target.position)
	for letter in session.typing.word.substr(1): session.typing.feed(letter)
	_check(not session._word_sampler.selected.has(target.id), "finishing a dead target releases its initial")
	session.step(0.0)
	_check(session.runtime.book_cast_count() == 2, "dead-target completion still casts at a living enemy")
	session.start_baseline(&"flame", words, "normal", "new-room", false)
	_check(session._word_sampler.selected.size() == 3 and session._retained_word_id == &"", "room restart resets reservations")
	session.free()


func _check_practice() -> void:
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("ant", ""), VocabularyEntry.new("ape", ""), VocabularyEntry.new("bee", "")]
	var settings := AppSettings.new("res://.temp/word-sampling-20261009/practice.cfg")
	settings.min_length = 1
	settings.max_length = 3
	var prepared := VocabularyIndex.build(words)
	var page := PracticePage.create_practice(words, settings, prepared)
	root.add_child(page)
	_check(page.active.size() == 2 and page._sampler.index == prepared, "practice uses the prepared index and displays only distinct initials")
	for id: StringName in page.active.keys():
		var word: String = page.active[id].word
		for letter in word: page.typing.feed(letter)
	await process_frame
	_check(page.completed_words == 2 and page.active.size() == 2 and page._sampler.selected.size() == 2, "practice completes a sparse batch and reuses released initials")
	page.queue_free()
	await process_frame
