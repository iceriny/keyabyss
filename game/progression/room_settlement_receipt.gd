class_name RoomSettlementReceipt
extends RefCounted

var run_id: String:
	get: return _run_id
var room_serial: int:
	get: return _room_serial
var attempt_id: String:
	get: return _attempt_id
var reason: StringName:
	get: return _reason
var manual_characters: int:
	get: return _manual_characters
var mode: StringName:
	get: return _mode

var _run_id: String
var _room_serial: int
var _attempt_id: String
var _reason: StringName
var _manual_characters: int
var _mode: StringName


func _init(p_run_id: String = "", p_room_serial: int = 0, p_attempt_id: String = "", p_reason: StringName = &"victory", p_manual_characters: int = 0, p_mode: StringName = &"normal") -> void:
	_run_id = p_run_id
	_room_serial = p_room_serial
	_attempt_id = p_attempt_id
	_reason = p_reason
	_manual_characters = p_manual_characters
	_mode = p_mode


func identity() -> String:
	return JSON.stringify([run_id, room_serial, attempt_id])


func signature() -> String:
	return JSON.stringify([run_id, room_serial, attempt_id, String(reason), manual_characters, String(mode)]).sha256_text()


func to_dict() -> Dictionary:
	return {"run_id": run_id, "room_serial": room_serial, "attempt_id": attempt_id, "reason": String(reason), "manual_characters": manual_characters, "mode": String(mode)}


static func from_dict(data: Dictionary) -> RoomSettlementReceipt:
	for field: String in ["run_id", "attempt_id", "reason", "mode"]:
		if not data.get(field) is String or data[field].is_empty():
			return null
	if data.mode not in ["normal", "god"] or data.reason not in ["victory", "defeat", "abandon", "interrupted", "checkpoint"]:
		return null
	for field: String in ["room_serial", "manual_characters"]:
		var value: Variant = data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 9007199254740991 or float(value) != floor(float(value)):
			return null
	return RoomSettlementReceipt.new(data.run_id, int(data.room_serial), data.attempt_id, StringName(data.reason), int(data.manual_characters), StringName(data.mode))
