extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_directory := "res://.temp/godot-m1/vocabulary/user/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository := VocabularyRepository.new(test_directory)
	_check(repository.catalog().size() == 12, "built-in catalog")
	_check(repository.load_entries("primary1").size() == 96, "built-in entries")

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
	_check(sync_source.get("sources", []).size() == 2, "built-in source has both upstream files")
	var first_sync: Array[VocabularyEntry] = [VocabularyEntry.new("first", "旧释义")]
	var sync_id := repository.save_synced("primary1", first_sync)
	_check(sync_id == "sync-primary1" and repository.load_entries(sync_id).size() == 1, "synced edition is stored separately from the offline snapshot")
	var next_sync: Array[VocabularyEntry] = [VocabularyEntry.new("newer", "新释义")]
	_check(repository.save_synced("primary1", next_sync) == sync_id and repository.load_entries(sync_id)[0].word == "newer", "verified sync replaces its previous edition")
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
