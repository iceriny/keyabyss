class_name TalentProgress
extends RefCounted


const CHARACTERS_PER_LEVEL := 1000
const MAX_LEVEL := 5
const HP_PER_LEVEL := 4


static func level_for(characters: int) -> int:
	return mini(MAX_LEVEL, floori(float(characters) / CHARACTERS_PER_LEVEL))


static func health_for(characters: int) -> int:
	return level_for(characters) * HP_PER_LEVEL


static func prepare(profile: ProfileState, receipt: RoomSettlementReceipt) -> Dictionary:
	return _prepare(profile, receipt, false)


# Persist accepted room characters without consuming the terminal receipt identity.
static func prepare_checkpoint(profile: ProfileState, receipt: RoomSettlementReceipt) -> Dictionary:
	return _prepare(profile, receipt, true)


static func _prepare(profile: ProfileState, receipt: RoomSettlementReceipt, checkpoint: bool) -> Dictionary:
	var errors := PackedStringArray()
	if receipt == null or RoomSettlementReceipt.from_dict(receipt.to_dict()) == null:
		errors.append("成长回执字段无效。")
	elif receipt.mode != profile.mode:
		errors.append("成长回执与档案模式不同。")
	elif checkpoint != (receipt.reason == &"checkpoint"):
		errors.append("房内检查点与终止结算入口不匹配。")
	if not errors.is_empty():
		return {"diagnostics": errors, "added_characters": 0}
	var key := receipt.identity()
	var rooms: Dictionary = profile.settlements.rooms
	if rooms.has(key):
		var previous := RoomSettlementReceipt.from_dict(rooms[key])
		if checkpoint or previous.signature() != receipt.signature():
			return {"diagnostics": PackedStringArray(["相同房间结算身份的内容不同。"]), "added_characters": 0}
		return {"profile": profile.copy(), "diagnostics": errors, "added_characters": 0}
	var checkpoints: Dictionary = profile.settlements.checkpoints
	var paid := int(checkpoints[key].manual_characters) if checkpoints.has(key) else 0
	if receipt.manual_characters < paid:
		return {"diagnostics": PackedStringArray(["房间字符少于已经保存的人工字符。"]), "added_characters": 0}
	var candidate := profile.copy()
	var run: Dictionary = candidate.settlements.runs.get(receipt.run_id, {"manual_characters": 0, "committed_characters": 0})
	run.manual_characters = int(run.manual_characters) + receipt.manual_characters - paid
	var added := int(run.manual_characters) - int(run.committed_characters)
	run.committed_characters = run.manual_characters
	candidate.settlements.runs[receipt.run_id] = run
	candidate.manual_characters += added
	if checkpoint:
		candidate.settlements.checkpoints[key] = receipt.to_dict()
	else:
		candidate.settlements.rooms[key] = receipt.to_dict()
		candidate.settlements.checkpoints.erase(key)
	return {"profile": candidate, "diagnostics": errors, "added_characters": added}
