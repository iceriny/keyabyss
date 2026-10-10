class_name CombatBuildOverride
extends RefCounted
## The expedition controller owns expiry; this contract does not grant permits.

enum Boundary { ROOM, CHAPTER, RUN }
var id: String
var source_id: StringName
var expires_at: Boundary = Boundary.ROOM
var capabilities: PackedStringArray = []
var disabled_capabilities: PackedStringArray = []
var parameter_deltas: Dictionary[StringName, int] = {}
var modes: Dictionary[StringName, StringName] = {}


func copy() -> CombatBuildOverride:
	var result := CombatBuildOverride.new()
	result.id = id
	result.source_id = source_id
	result.expires_at = expires_at
	result.capabilities = capabilities.duplicate()
	result.disabled_capabilities = disabled_capabilities.duplicate()
	result.parameter_deltas = parameter_deltas.duplicate()
	result.modes = modes.duplicate()
	return result


func to_dict() -> Dictionary:
	var parameters: Dictionary = {}
	for parameter in parameter_deltas: parameters[str(parameter)] = parameter_deltas[parameter]
	var mode_data: Dictionary = {}
	for slot in modes: mode_data[str(slot)] = str(modes[slot])
	return {"id": id, "source_id": str(source_id), "expires_at": expires_at, "capabilities": Array(capabilities), "disabled_capabilities": Array(disabled_capabilities), "parameter_deltas": parameters, "modes": mode_data}


static func from_dict(data: Dictionary) -> CombatBuildOverride:
	if not data.get("id") is String or not data.get("source_id") is String or data.id.is_empty() or data.source_id.is_empty():
		push_error("覆盖快照需要独立 ID 与来源。")
		return null
	var expiry: Variant = data.get("expires_at")
	if (not expiry is int and not expiry is float) or not is_finite(float(expiry)) or float(expiry) != floor(float(expiry)) or int(expiry) not in Boundary.values():
		push_error("覆盖快照期限类别无效。")
		return null
	for field in ["capabilities", "disabled_capabilities"]:
		if not data.get(field) is Array:
			push_error("覆盖快照能力列表无效：" + field)
			return null
		for operation in data[field]:
			if not operation is String or operation not in CombatRuleContract.OPERATIONS:
				push_error("覆盖快照包含未登记能力：" + str(operation))
				return null
	if not data.get("parameter_deltas") is Dictionary or not data.get("modes") is Dictionary:
		push_error("覆盖快照参数或模式需要字典。")
		return null
	for parameter in data.parameter_deltas:
		var value: Variant = data.parameter_deltas[parameter]
		if not parameter is String or not CombatRuleContract.UNITS.has(StringName(parameter)) or (not value is int and not value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or absf(float(value)) > 1 << 30:
			push_error("覆盖快照参数无效：" + str(parameter))
			return null
	for slot in data.modes:
		if not slot is String or slot not in BuildCompiler.MODE_SLOTS or not data.modes[slot] is String:
			push_error("覆盖快照包含未登记模式槽：" + str(slot))
			return null
	var result := CombatBuildOverride.new()
	result.id = data.id
	result.source_id = StringName(data.source_id)
	result.expires_at = int(expiry) as Boundary
	result.capabilities = PackedStringArray(data.capabilities)
	result.disabled_capabilities = PackedStringArray(data.disabled_capabilities)
	for parameter in data.parameter_deltas: result.parameter_deltas[StringName(parameter)] = int(data.parameter_deltas[parameter])
	for slot in data.modes: result.modes[StringName(slot)] = StringName(data.modes[slot])
	return result
