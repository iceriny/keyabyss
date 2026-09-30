class_name VocabularyRepository
extends RefCounted

const INDEX_PATH := "res://assets/vocabulary/index.json"
const SOURCES_PATH := "res://assets/vocabulary/sources.json"
const USER_DIRECTORY := "user://vocabulary"
const MAX_TEXT_LENGTH := 5_000_000
const MAX_RECORDS := 100_000

var last_error: String = ""
var user_directory: String = USER_DIRECTORY


func _init(directory: String = USER_DIRECTORY) -> void:
	user_directory = directory


func catalog() -> Array[Dictionary]:
	last_error = ""
	var result: Array[Dictionary] = []
	var index: Variant = _read_json(INDEX_PATH)
	if index is Dictionary and index.get("books") is Array:
		for item in index["books"]:
			if item is Dictionary:
				result.append({"id": str(item.get("id", "")), "title": str(item.get("title", "")), "count": int(item.get("count", 0))})
	else:
		last_error = "内置词库索引不可读取。"
	var directory := DirAccess.open(user_directory)
	if directory == null:
		return result
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and (filename.begins_with("custom-") or filename.begins_with("sync-")) and filename.ends_with(".json"):
			var book: Variant = _read_json(user_directory.path_join(filename))
			if book is Dictionary and book.get("words") is Array:
				result.append({"id": filename.get_basename(), "title": str(book.get("title", filename.get_basename())), "count": book["words"].size()})
		filename = directory.get_next()
	directory.list_dir_end()
	return result


func describe(id: String) -> Dictionary:
	for book in catalog():
		if str(book.id) == id:
			var path := _book_path(id)
			var data: Variant = _read_json(path)
			if data is Dictionary:
				return {"title": str(data.get("title", book.title)), "description": str(data.get("description", "自定义词咒词库")), "source": str(data.get("sourceLabel", "本机导入")), "scope": str(data.get("scope", ""))}
	return {}


func load_entries(id: String) -> Array[VocabularyEntry]:
	last_error = ""
	var entries: Array[VocabularyEntry] = []
	var path := ""
	for book in catalog():
		if book["id"] == id:
			path = _book_path(id)
			break
	if path.is_empty():
		last_error = "找不到词库：" + id
		return entries
	var data: Variant = _read_json(path)
	if not (data is Dictionary) or not (data.get("words") is Array):
		last_error = "词库数据无法读取：" + id
		return entries
	var seen := {}
	for item in data["words"]:
		if not (item is Dictionary):
			continue
		var word := _normalize_word(str(item.get("word", "")))
		if _valid_word(word) and not seen.has(word):
			seen[word] = true
			entries.append(VocabularyEntry.new(word, str(item.get("meaning", ""))))
	if entries.is_empty():
		last_error = "词库没有可用词条：" + id
	return entries


func parse_import(text: String, filename: String) -> VocabularyImport:
	var result := VocabularyImport.new()
	result.title = filename.get_file().get_basename().substr(0, 80)
	if text.to_utf8_buffer().size() > MAX_TEXT_LENGTH:
		result.error = "文件过大，请使用不超过 5 MB 的 UTF-8 文本。"
		return result
	text = text.trim_prefix("\uFEFF")
	if text.strip_edges().is_empty():
		result.error = "词库是空的。"
		return result
	var records: Array[Dictionary] = []
	var extension := filename.get_extension().to_lower()
	var content := text.strip_edges()
	if extension == "json" or extension == "jsonl" or content.begins_with("[") or content.begins_with("{"):
		records = _parse_json_records(text, extension, result)
	else:
		var first := ""
		for candidate in text.split("\n"):
			if not candidate.strip_edges().is_empty() and not candidate.strip_edges().begins_with("#"):
				first = candidate
				break
		if extension == "csv" or extension == "tsv" or first.contains("\t") or first.contains(","):
			records = _parse_delimited(text, "\t" if extension == "tsv" or first.contains("\t") else ",", result)
		else:
			var line_number := 0
			for line in text.split("\n"):
				line_number += 1
				if not line.strip_edges().is_empty() and not line.strip_edges().begins_with("#"):
					records.append({"value": line.trim_suffix("\r"), "location": "第 %d 行" % line_number})
	if not result.error.is_empty():
		return result
	if records.size() > MAX_RECORDS:
		result.error = "一次最多导入 100,000 条记录。"
		return result
	result.raw_count = records.size()
	var seen := {}
	for record in records:
		var value: Variant = record["value"]
		var word := _normalize_word(_entry_word(value))
		if not _valid_word(word):
			result.issues.append("%s：词形不合规（%s）" % [record["location"], word.substr(0, 70)])
			continue
		if seen.has(word):
			result.duplicates += 1
			continue
		seen[word] = true
		result.entries.append(VocabularyEntry.new(word, _entry_meaning(value).substr(0, 240)))
	if result.entries.is_empty():
		result.error = "没有可用词条。支持 1–24 位可输入字符的英文词或短语，以及数字、下划线、连字符和英文撇号。"
	return result


func save_import(result: VocabularyImport) -> String:
	var id := "custom-" + Crypto.new().generate_random_bytes(16).hex_encode()
	return id if _save_book(result, id, {}) else ""


func sync_source(id: String) -> Dictionary:
	var source_id := id.trim_prefix("sync-")
	var provenance: Variant = _read_json(SOURCES_PATH)
	if provenance is Dictionary and provenance.get("books") is Array:
		for book in provenance["books"]:
			if book is Dictionary and str(book.get("id", "")) == source_id and book.get("sources") is Array and not book["sources"].is_empty():
				return book
	return {}


func save_synced(source_id: String, entries: Array[VocabularyEntry]) -> String:
	var source := sync_source(source_id)
	if source.is_empty():
		last_error = "这个词库没有可同步的上游来源。"
		return ""
	var result := VocabularyImport.new()
	result.title = str(source.get("title", source_id)) + " · 同步版"
	result.entries = entries
	var id := "sync-" + source_id
	var metadata := {
		"description": str(source.get("description", "")),
		"sourceLabel": str(source.get("sourceLabel", "")),
		"source_id": source_id,
		"scope": "%d 个可用词条" % entries.size(),
	}
	return id if _save_book(result, id, metadata) else ""


func _save_book(result: VocabularyImport, id: String, metadata: Dictionary) -> bool:
	last_error = ""
	if result == null or not result.error.is_empty() or result.entries.is_empty():
		last_error = "导入结果没有可保存的词条。"
		return false
	var words: Array[Dictionary] = []
	var seen := {}
	for entry in result.entries:
		if entry == null or not _valid_word(entry.word) or seen.has(entry.word):
			last_error = "导入结果含有无效或重复词条。"
			return false
		seen[entry.word] = true
		words.append({"word": entry.word, "meaning": entry.meaning.substr(0, 240)})
	var folder := ProjectSettings.globalize_path(user_directory)
	var make_error := DirAccess.make_dir_recursive_absolute(folder)
	if make_error != OK:
		last_error = "无法创建用户词库目录（错误码 %d）。" % make_error
		return false
	var target := folder.path_join(id + ".json")
	var temporary := folder.path_join(id + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp")
	var data := {"schema_version": 1, "title": result.title.substr(0, 80), "words": words}
	data.merge(metadata)
	var payload := JSON.stringify(data)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入用户词库（错误码 %d）。" % FileAccess.get_open_error()
		return false
	file.store_string(payload)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "写入用户词库失败（错误码 %d）；临时文件保留在 %s。" % [write_error, temporary]
		return false
	var verification := FileAccess.get_file_as_string(temporary)
	if verification.sha256_text() != payload.sha256_text():
		last_error = "用户词库写入校验失败；临时文件保留在 %s。" % temporary
		return false
	var rename_error := DirAccess.rename_absolute(temporary, target)
	if rename_error != OK:
		last_error = "无法完成用户词库保存（错误码 %d）；临时文件保留在 %s。" % [rename_error, temporary]
		return false
	return true


func select_entries(ids: PackedStringArray, min_length: int, max_length: int) -> Array[VocabularyEntry]:
	last_error = ""
	var selected: Array[VocabularyEntry] = []
	if min_length < 1 or max_length > 24 or min_length > max_length:
		last_error = "词长范围应在 1–24 之间。"
		return selected
	var seen := {}
	for id in ids:
		for entry in load_entries(id):
			if not seen.has(entry.word) and entry.playable_length() >= min_length and entry.playable_length() <= max_length:
				seen[entry.word] = true
				selected.append(entry)
	return selected


func _parse_json_records(text: String, extension: String, result: VocabularyImport) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK and extension == "jsonl":
		var line_number := 0
		for line in text.split("\n"):
			line_number += 1
			if line.strip_edges().is_empty():
				continue
			var line_parser := JSON.new()
			if line_parser.parse(line) != OK:
				result.error = "JSONL 第 %d 行格式不正确：%s" % [line_number, line_parser.get_error_message()]
				return records
			records.append({"value": line_parser.data, "location": "第 %d 行" % line_number})
		return records
	if parse_error != OK:
		result.error = "JSON 第 %d 行格式不正确：%s" % [parser.get_error_line(), parser.get_error_message()]
		return records
	var data: Variant = parser.data
	if extension == "jsonl" and data is Dictionary and not (data.has("words") or data.has("entries") or data.has("data")):
		records.append({"value": data, "location": "第 1 行"})
		return records
	if data is Dictionary:
		result.title = str(data.get("title", data.get("name", result.title))).substr(0, 80)
		data = data.get("words", data.get("entries", data.get("data", null)))
	if not (data is Array):
		result.error = "词库需要是数组，或包含 words 数组的对象。"
		return records
	for i in data.size():
		records.append({"value": data[i], "location": "第 %d 条" % (i + 1)})
	return records


func _parse_delimited(text: String, separator: String, result: VocabularyImport) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var cells: Array[String] = []
	var value := ""
	var quoted := false
	var line := 1
	var row_line := 1
	var i := 0
	while i < text.length():
		var character := text.substr(i, 1)
		if character == "\"":
			if quoted and i + 1 < text.length() and text.substr(i + 1, 1) == "\"":
				value += "\""
				i += 1
			else:
				quoted = not quoted
		elif character == separator and not quoted:
			cells.append(value)
			value = ""
		elif (character == "\n" or character == "\r") and not quoted:
			cells.append(value)
			if not _empty_row(cells) and not (cells.size() == 1 and cells[0].strip_edges().begins_with("#")):
				rows.append({"cells": cells, "line": row_line})
			cells = []
			value = ""
			if character == "\r" and i + 1 < text.length() and text.substr(i + 1, 1) == "\n":
				i += 1
			line += 1
			row_line = line
		else:
			value += character
			if character == "\n":
				line += 1
		i += 1
	if quoted:
		result.error = "CSV/TSV 第 %d 行引号没有闭合。" % row_line
		return []
	cells.append(value)
	if not _empty_row(cells) and not (cells.size() == 1 and cells[0].strip_edges().begins_with("#")):
		rows.append({"cells": cells, "line": row_line})
	var word_column := 0
	var meaning_column := 1
	if not rows.is_empty():
		var header: Array = rows[0]["cells"]
		for index in header.size():
			var label := str(header[index]).strip_edges().to_lower()
			if label in ["word", "name", "headword", "text", "单词", "词条"]:
				word_column = index
				meaning_column = -1
				for meaning_index in header.size():
					if str(header[meaning_index]).strip_edges().to_lower() in ["meaning", "translation", "trans", "释义", "中文"]:
						meaning_column = meaning_index
				rows.remove_at(0)
				break
	var records: Array[Dictionary] = []
	for row in rows:
		var parts: Array = row["cells"]
		records.append({"value": [parts[word_column] if word_column < parts.size() else "", parts[meaning_column] if meaning_column >= 0 and meaning_column < parts.size() else ""], "location": "第 %d 行" % row["line"]})
	return records


func _empty_row(cells: Array[String]) -> bool:
	for cell in cells:
		if not cell.strip_edges().is_empty():
			return false
	return true


func _entry_word(value: Variant) -> String:
	if value is String:
		return value
	if value is Array:
		return str(value[0]) if not value.is_empty() else ""
	if value is Dictionary:
		for key in ["word", "name", "headWord", "text"]:
			if value.has(key) and value[key] != null:
				return str(value[key])
	return ""


func _entry_meaning(value: Variant) -> String:
	var meaning: Variant = ""
	if value is Array and value.size() > 1:
		meaning = value[1]
	elif value is Dictionary:
		for key in ["meaning", "translation", "trans"]:
			if value.has(key) and value[key] != null:
				meaning = value[key]
				break
		if meaning is String and meaning == "" and value.get("content") is Dictionary:
			var content: Dictionary = value["content"]
			var nested: Variant = content.get("word", {})
			if nested is Dictionary:
				nested = nested.get("content", {})
			if nested is Dictionary:
				nested = nested.get("trans", [])
			if nested is Array:
				var translations: PackedStringArray = PackedStringArray()
				for item in nested:
					if item is Dictionary:
						translations.append(str(item.get("tranCn", "")))
				meaning = "；".join(translations)
	if meaning is Array:
		var parts: PackedStringArray = PackedStringArray()
		for part in meaning:
			parts.append(str(part))
		return "；".join(parts)
	return "" if meaning == null else str(meaning)


func _normalize_word(value: String) -> String:
	# Godot has no NFKC operation; cover fullwidth ASCII and common spacing used by imported lists.
	var normalized := ""
	var pending_space := false
	for position in value.length():
		var code := value.unicode_at(position)
		if code >= 0xFF01 and code <= 0xFF5E:
			code -= 0xFEE0
		if code >= 65 and code <= 90:
			code += 32
		if code in [9, 10, 11, 12, 13, 32, 0xA0, 0x3000]:
			pending_space = not normalized.is_empty()
			continue
		if pending_space:
			normalized += " "
			pending_space = false
		normalized += char(code)
	return normalized


func _valid_word(word: String) -> bool:
	if word.is_empty() or word.length() - word.count(" ") > 24:
		return false
	var segments := word.split(" ", false)
	if segments.size() > 6:
		return false
	for segment in segments:
		if segment.is_empty():
			return false
		for index in segment.length():
			var code := segment.unicode_at(index)
			if index == 0:
				if code < 97 or code > 122:
					return false
			elif not (code >= 97 and code <= 122 or code >= 48 and code <= 57 or code in [39, 45, 95]):
				return false
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data


func _book_path(id: String) -> String:
	return user_directory.path_join(id + ".json") if id.begins_with("custom-") or id.begins_with("sync-") else "res://assets/vocabulary/" + id + ".json"
