class_name CombatAssetService
extends RefCounted

var compiler: BuildCompiler


func _init(build_compiler: BuildCompiler = null) -> void:
	compiler = build_compiler if build_compiler != null else BuildCompiler.new()


func prepare(selection: BuildSelection, request: CombatAssetRequest) -> Dictionary:
	var requests: Array[CombatAssetRequest] = [request]
	return prepare_batch(selection, requests)


func prepare_batch(selection: BuildSelection, requests: Array[CombatAssetRequest]) -> Dictionary:
	if selection == null:
		return {"diagnostics": PackedStringArray(["需要有效配置与资产请求。"])}
	for request in requests:
		if request == null or request.action not in [CombatAssetRequest.Action.ADD, CombatAssetRequest.Action.REMOVE]:
			return {"diagnostics": PackedStringArray(["需要有效配置与资产请求。"])}
	var normalized: Dictionary = {}
	if not selection.assets.is_empty() or not selection.asset_instances.is_empty():
		normalized = compiler.normalize_assets(selection)
		if not normalized.diagnostics.is_empty(): return {"diagnostics": normalized.diagnostics}
	var proposed := selection.copy()
	if not normalized.is_empty(): proposed.instances = normalized.instances
	proposed.assets.clear()
	proposed.asset_instances.clear()
	for request in requests:
		var diagnostic := _apply_request(proposed, request)
		if not diagnostic.is_empty(): return {"diagnostics": PackedStringArray([diagnostic])}
	var result := compiler.compile(proposed)
	if not result.success(): return {"diagnostics": result.diagnostics}
	var command := BattleCommand.new()
	command.build = result.build
	return {"selection": proposed, "command": command, "diagnostics": PackedStringArray()}


func _apply_request(proposed: BuildSelection, request: CombatAssetRequest) -> String:
	var definition := compiler.catalog.get_definition(request.content_id)
	if definition == null:
		return "内容 ID 不存在：" + str(request.content_id)
	match request.action:
		CombatAssetRequest.Action.ADD:
			if request.instance_id.is_empty(): return "获取请求需要稳定资产实例 ID。"
			if request.stacks != 1: return "正式获取每次请求一份资产。"
			var instance := CombatAssetInstance.new()
			instance.instance_id = request.instance_id
			instance.content_id = request.content_id
			instance.source_id = request.source_id
			instance.expiry_scope = request.expiry_scope
			instance.expiry_index = request.expiry_index
			instance.parent_instance_id = request.parent_instance_id
			proposed.instances.append(instance)
		CombatAssetRequest.Action.REMOVE:
			var index := _find_instance(proposed, request.instance_id)
			if index < 0 or proposed.instances[index].content_id != request.content_id:
				return "移除请求与持有的资产实例不符。"
			proposed.instances.remove_at(index)
	return ""


func _find_instance(selection: BuildSelection, instance_id: String) -> int:
	for index in selection.instances.size():
		if selection.instances[index] != null and selection.instances[index].instance_id == instance_id: return index
	return -1
