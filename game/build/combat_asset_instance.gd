class_name CombatAssetInstance
extends RefCounted
## One owned or borrowed copy. Deadlines are declarations; M4 advances them.

var instance_id: String
var content_id: StringName
var source_id: StringName
var expiry_scope: StringName = &"run"
var expiry_index: int = -1
var parent_instance_id: String
var evolved_from: StringName
var variant_id: StringName


func usage_key() -> String:
	return instance_id


func copy() -> CombatAssetInstance:
	var result := CombatAssetInstance.new()
	result.instance_id = instance_id
	result.content_id = content_id
	result.source_id = source_id
	result.expiry_scope = expiry_scope
	result.expiry_index = expiry_index
	result.parent_instance_id = parent_instance_id
	result.evolved_from = evolved_from
	result.variant_id = variant_id
	return result


func signature() -> String:
	return str([instance_id, content_id, source_id, expiry_scope, expiry_index, parent_instance_id, evolved_from, variant_id])


func to_dict() -> Dictionary:
	return {"instance_id": instance_id, "content_id": str(content_id), "source_id": str(source_id), "expiry_scope": str(expiry_scope), "expiry_index": expiry_index, "parent_instance_id": parent_instance_id, "evolved_from": str(evolved_from), "variant_id": str(variant_id)}


static func from_dict(data: Dictionary) -> CombatAssetInstance:
	for field in ["instance_id", "content_id", "source_id", "expiry_scope", "parent_instance_id", "evolved_from"]:
		if not data.get(field) is String:
			push_error("资产快照字段需要字符串：" + field)
			return null
	var deadline: Variant = data.get("expiry_index")
	var variant: Variant = data.get("variant_id", "")
	if not variant is String:
		push_error("资产快照变体需要字符串。")
		return null
	if (not deadline is int and not deadline is float) or not is_finite(float(deadline)) or float(deadline) != floor(float(deadline)) or deadline < -1 or deadline > 1 << 30:
		push_error("资产快照期限需要有效整数。")
		return null
	if data.instance_id.is_empty() or data.content_id.is_empty() or data.source_id.is_empty() or data.expiry_scope not in ["room", "chapter", "run"]:
		push_error("资产快照身份、来源或期限声明无效。")
		return null
	var result := CombatAssetInstance.new()
	result.instance_id = data.instance_id
	result.content_id = StringName(data.content_id)
	result.source_id = StringName(data.source_id)
	result.expiry_scope = StringName(data.expiry_scope)
	result.expiry_index = int(deadline)
	result.parent_instance_id = data.parent_instance_id
	result.evolved_from = StringName(data.evolved_from)
	result.variant_id = StringName(variant)
	return result
