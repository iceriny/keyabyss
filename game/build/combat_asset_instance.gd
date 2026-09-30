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
	return result


func signature() -> String:
	return str([instance_id, content_id, source_id, expiry_scope, expiry_index, parent_instance_id, evolved_from])
