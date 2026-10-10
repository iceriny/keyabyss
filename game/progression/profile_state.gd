class_name ProfileState
extends RefCounted

const MAX_JSON_INTEGER: int = 9007199254740991

var mode: StringName = &"normal"
var revision: int = 0
var manual_characters: int = 0
var allocations: Dictionary = {}
var settlements: Dictionary = {"rooms": {}, "runs": {}, "checkpoints": {}}
var run_checkpoint: Dictionary = {}
var records: Array[Dictionary] = []
var content_version: int = 2
var graph_version: int = 1
var layout_version: int = 1
var diagnostics: PackedStringArray = []


func has_pending_run() -> bool:
	if run_checkpoint.is_empty(): return false
	if not run_checkpoint.get("facts") is Dictionary: return true
	return run_checkpoint.get("phase") != "RESULT" or bool(run_checkpoint.get("facts", {}).get("victory_pending", false))


func to_dict() -> Dictionary:
	return {
		"mode": String(mode), "revision": revision, "manual_characters": manual_characters,
		"allocations": allocations.duplicate(true), "settlements": settlements.duplicate(true),
		"run_checkpoint": run_checkpoint.duplicate(true), "records": records.duplicate(true),
		"content_version": content_version, "graph_version": graph_version, "layout_version": layout_version,
		"diagnostics": Array(diagnostics),
	}


func copy() -> ProfileState:
	var result := ProfileState.new()
	result.mode = mode
	result.revision = revision
	result.manual_characters = manual_characters
	result.allocations = allocations.duplicate(true)
	result.settlements = settlements.duplicate(true)
	result.run_checkpoint = run_checkpoint.duplicate(true)
	result.records.assign(records.duplicate(true))
	result.content_version = content_version
	result.graph_version = graph_version
	result.layout_version = layout_version
	result.diagnostics = diagnostics.duplicate()
	return result


# Parsing is the trust boundary; services consume an already validated profile.
static func from_dict(data: Dictionary) -> ProfileState:
	if not is_json_data(data) or data.get("mode") not in ["normal", "god"]:
		return null
	for field: String in ["revision", "manual_characters", "content_version", "graph_version", "layout_version"]:
		if not is_count(data.get(field)):
			return null
	for field: String in ["content_version", "graph_version", "layout_version"]:
		if int(data[field]) < 1:
			return null
	for field: String in ["allocations", "settlements", "run_checkpoint"]:
		if not data.get(field) is Dictionary:
			return null
	for value: Variant in data.allocations.values():
		if not value is Dictionary:
			return null
	if not data.get("records") is Array or not data.get("diagnostics", []) is Array:
		return null
	for value: Variant in data.records:
		if not value is Dictionary:
			return null
	for value: Variant in data.get("diagnostics", []):
		if not value is String:
			return null
	if not _valid_settlements(data.settlements, StringName(data.mode), int(data.manual_characters)):
		return null
	var result := ProfileState.new()
	result.mode = StringName(data.mode)
	result.revision = int(data.revision)
	result.manual_characters = int(data.manual_characters)
	result.allocations = data.allocations.duplicate(true)
	result.settlements = data.settlements.duplicate(true)
	result.run_checkpoint = data.run_checkpoint.duplicate(true)
	result.records.assign(data.records.duplicate(true))
	result.content_version = int(data.content_version)
	result.graph_version = int(data.graph_version)
	result.layout_version = int(data.layout_version)
	result.diagnostics = PackedStringArray(data.get("diagnostics", []))
	return result


static func is_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= MAX_JSON_INTEGER and float(value) == floor(float(value))


static func is_json_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_INT:
			return value >= -MAX_JSON_INTEGER and value <= MAX_JSON_INTEGER
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item: Variant in value:
				if not is_json_data(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not (key is String or key is StringName) or not is_json_data(value[key]):
					return false
			return true
	return false


static func _valid_settlements(data: Dictionary, profile_mode: StringName, total: int) -> bool:
	for field: String in ["rooms", "runs", "checkpoints"]:
		if not data.get(field) is Dictionary:
			return false
	var counted_by_run: Dictionary = {}
	for field: String in ["rooms", "checkpoints"]:
		for key: String in data[field]:
			if not data[field][key] is Dictionary:
				return false
			var receipt := RoomSettlementReceipt.from_dict(data[field][key])
			if receipt == null or receipt.identity() != key or receipt.mode != profile_mode:
				return false
			if (field == "checkpoints") != (receipt.reason == &"checkpoint"):
				return false
			if field == "checkpoints" and data.rooms.has(key):
				return false
			counted_by_run[receipt.run_id] = int(counted_by_run.get(receipt.run_id, 0)) + receipt.manual_characters
	var committed_total := 0
	for key: String in data.runs:
		var run: Variant = data.runs[key]
		if key.is_empty() or not run is Dictionary or not is_count(run.get("manual_characters")) or not is_count(run.get("committed_characters")):
			return false
		if run.manual_characters != run.committed_characters:
			return false
		if int(run.manual_characters) != int(counted_by_run.get(key, 0)):
			return false
		committed_total += int(run.committed_characters)
	for run_id: String in counted_by_run:
		if not data.runs.has(run_id):
			return false
	return committed_total <= total
