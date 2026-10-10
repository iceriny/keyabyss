class_name RunStateCodec
extends RefCounted
## Pure checkpoint data. Ownership transfers only when the next room imports it.

const MAX_Q := 1 << 30


static func encode(state: RunCombatState) -> Dictionary:
	if state == null:
		push_error("战斗交接快照需要有效状态。")
		return {}
	var lots: Array = []
	for lot in state.reserve:
		if lot == null:
			push_error("战斗交接储备不能包含空份额。")
			return {}
		var claims: Dictionary = {}
		for claim in lot.claims: claims[str(claim)] = lot.claims[claim]
		var lineage: Array = []
		for entry in lot.lineage:
			if not _is_json_data(entry):
				push_error("储备来源记录包含不可保存的对象。")
				return {}
			lineage.append(_json_copy(entry))
		var packet: Variant = null
		if lot.packet != null:
			packet = Array(lot.packet.components())
		lots.append({"id": str(lot.id), "root_id": lot.root_id, "source_id": str(lot.source_id), "room_id": str(lot.room_id), "snapshot_id": lot.snapshot_id, "owner": str(lot.owner), "material": lot.material, "amount_q": lot.amount_q, "packet": packet, "claims": claims, "lineage": lineage})
	return {"hp_q": state.hp_q, "shield_q": state.shield_q, "resonance_q": state.resonance_q, "reserve": lots, "reserve_cooldown_words": state.reserve_cooldown_words, "asset_claims": state.asset_claims.duplicate(), "relic_counters": state.relic_counters.duplicate(), "room_serial": str(state.room_serial)}


static func decode(data: Dictionary) -> RunCombatState:
	var diagnostic := _diagnose(data)
	if not diagnostic.is_empty():
		push_error("战斗交接快照无效：" + diagnostic)
		return null
	var state := RunCombatState.new()
	state.hp_q = int(data.hp_q)
	state.shield_q = int(data.shield_q)
	state.resonance_q = int(data.resonance_q)
	state.reserve_cooldown_words = int(data.reserve_cooldown_words)
	state.room_serial = int(data.room_serial)
	for key in data.get("relic_counters", {}): state.relic_counters[key] = int(data.relic_counters[key])
	for claim in data.asset_claims: state.asset_claims[claim] = data.asset_claims[claim]
	for record in data.reserve:
		var lot := SpellLot.new()
		lot.id = int(record.id)
		lot.root_id = record.root_id
		lot.source_id = StringName(record.source_id)
		lot.room_id = int(record.room_id)
		lot.snapshot_id = record.snapshot_id
		lot.owner = StringName(record.owner)
		lot.material = int(record.material) as SpellLot.Kind
		lot.amount_q = int(record.amount_q)
		if record.packet != null:
			lot.packet = DamagePacket.new()
			lot.packet._parts = PackedInt64Array(record.packet)
		for claim in record.claims: lot.claims[StringName(claim)] = record.claims[claim]
		for entry in record.lineage: lot.lineage.append(_json_copy(entry))
		state.reserve.append(lot)
	return state


static func _diagnose(data: Dictionary) -> String:
	for field in ["hp_q", "shield_q", "resonance_q", "reserve_cooldown_words"]:
		if not _bounded_integer(data.get(field), MAX_Q): return field + " 超出固定点资源范围。"
	if not _identity_integer(data.get("room_serial")): return "room_serial 需要十进制非负整数字符串。"
	if not _claims_valid(data.get("asset_claims")): return "asset_claims 需要具名布尔回执。"
	if not data.get("relic_counters", {}) is Dictionary: return "遗物周期需要字典。"
	for key in data.get("relic_counters", {}):
		if not key is String or not _bounded_integer(data.relic_counters[key], MAX_Q): return "遗物周期无效。"
	if not data.get("reserve") is Array: return "reserve 需要数组。"
	var identities: Dictionary[String, bool] = {}
	for record in data.reserve:
		if not record is Dictionary: return "储备份额需要字典。"
		for field in ["id", "room_id"]:
			if not _identity_integer(record.get(field)): return "储备 " + field + " 需要十进制非负整数字符串。"
		var identity: String = record.room_id + ":" + record.id
		if identities.has(identity): return "储备稳定交接身份重复：" + identity
		identities[identity] = true
		for field in ["root_id", "source_id", "snapshot_id", "owner"]:
			if not record.get(field) is String or record[field].is_empty(): return "储备 " + field + " 需要有效字符串。"
		if not _bounded_integer(record.get("material"), SpellLot.Kind.OPPORTUNITY): return "储备材料类别无效。"
		if not _bounded_integer(record.get("amount_q"), MAX_Q): return "储备 amount_q 超出固定点资源范围。"
		if not _claims_valid(record.get("claims")): return "储备 claims 需要具名布尔回执。"
		if not record.get("lineage") is Array: return "储备 lineage 需要数组。"
		for entry in record.lineage:
			if not entry is Dictionary or not _is_json_data(entry): return "储备来源记录需要纯数据字典。"
		if not record.has("packet"): return "储备缺少伤害组成字段。"
		if record.material != SpellLot.Kind.POWER:
			if record.packet != null: return "非力量储备不能携带伤害组成。"
		elif not record.packet is Array or record.packet.size() != DamagePacket.Element.size():
			return "力量储备需要完整伤害组成。"
		else:
			var total: int = 0
			for part in record.packet:
				if not _bounded_integer(part, MAX_Q): return "伤害组成超出固定点资源范围。"
				total += int(part)
			if total != int(record.amount_q): return "伤害组成与力量储备额度不一致。"
	return ""


static func _bounded_integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= maximum


static func _identity_integer(value: Variant) -> bool:
	# Canonical decimal strings retain the full int64 identity through JSON.
	return value is String and value.is_valid_int() and int(value) >= 0 and str(int(value)) == value


static func _claims_valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for claim in value:
		if not claim is String or claim.is_empty() or not value[claim] is bool: return false
	return true


static func _is_json_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME: return true
		TYPE_INT: return value >= -9007199254740991 and value <= 9007199254740991
		TYPE_FLOAT: return is_finite(value)
		TYPE_ARRAY:
			for child in value:
				if not _is_json_data(child): return false
		TYPE_DICTIONARY:
			for key in value:
				if not (key is String or key is StringName) or not _is_json_data(value[key]): return false
		_: return false
	return true


static func _json_copy(value: Variant) -> Variant:
	if value is StringName: return str(value)
	# JSON parses numbers as floats; integral lineage values retain their semantics.
	if value is float and value == floor(value) and absf(value) <= 9007199254740991:
		return int(value)
	if value is Array:
		var result: Array = []
		for child in value: result.append(_json_copy(child))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[str(key)] = _json_copy(value[key])
		return result
	return value
