class_name CombatAssetService
extends RefCounted

var compiler: BuildCompiler


func _init(build_compiler: BuildCompiler = null) -> void:
	compiler = build_compiler if build_compiler != null else BuildCompiler.new()


func prepare(selection: BuildSelection, request: CombatAssetRequest) -> Dictionary:
	if selection == null or request == null or request.action not in CombatAssetRequest.Action.values():
		return {"diagnostics": PackedStringArray(["需要有效配置与资产请求。"])}
	var normalized := compiler.normalize_assets(selection)
	if not normalized.diagnostics.is_empty(): return {"diagnostics": normalized.diagnostics}
	var proposed := BuildSelection.new()
	proposed.book_id = selection.book_id
	proposed.talents = selection.talents.duplicate()
	proposed.instances = normalized.instances
	proposed.modes = selection.modes.duplicate()
	proposed.temporary_rules = selection.temporary_rules.duplicate()
	proposed.secondary_book = selection.secondary_book
	proposed.focus_shape = selection.focus_shape
	proposed.calibrated_materials = selection.calibrated_materials.duplicate()
	proposed.overrides = selection.overrides.duplicate()
	var definition := compiler.catalog.get_definition(request.content_id)
	if definition == null and not (request.override != null and request.action in [CombatAssetRequest.Action.OVERRIDE, CombatAssetRequest.Action.RESTORE]):
		return {"diagnostics": PackedStringArray(["内容 ID 不存在：" + str(request.content_id)])}
	match request.action:
		CombatAssetRequest.Action.ADD:
			if request.instance_id.is_empty(): return {"diagnostics": PackedStringArray(["获取请求需要稳定资产实例 ID。"])}
			if request.stacks != 1: return {"diagnostics": PackedStringArray(["正式获取每次请求一份资产。"])}
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
				return {"diagnostics": PackedStringArray(["移除请求与持有的资产实例不符。"])}
			proposed.instances.remove_at(index)
		CombatAssetRequest.Action.EVOLVE:
			var index := _find_instance(proposed, request.instance_id)
			if request.stacks != 1 or index < 0 or not definition is RelicDefinition or definition.replaces != request.parent_id or proposed.instances[index].content_id != request.parent_id:
				return {"diagnostics": PackedStringArray(["演化请求与持有的父资产实例不符。"])}
			proposed.instances[index].evolved_from = request.parent_id
			proposed.instances[index].content_id = request.content_id
		CombatAssetRequest.Action.OVERRIDE:
			if request.override != null: proposed.overrides.append(request.override)
			elif str(request.content_id) not in proposed.temporary_rules: proposed.temporary_rules.append(str(request.content_id))
		CombatAssetRequest.Action.RESTORE:
			if request.override != null:
				proposed.overrides = proposed.overrides.filter(func(overlay: CombatBuildOverride) -> bool: return overlay.id != request.override.id)
			else:
				var index := proposed.temporary_rules.find(str(request.content_id))
				if index >= 0: proposed.temporary_rules.remove_at(index)
	var result := compiler.compile(proposed)
	if not result.success(): return {"diagnostics": result.diagnostics}
	var command := BattleCommand.new()
	command.build = result.build
	return {"selection": proposed, "command": command, "diagnostics": PackedStringArray()}


func _find_instance(selection: BuildSelection, instance_id: String) -> int:
	for index in selection.instances.size():
		if selection.instances[index].instance_id == instance_id: return index
	return -1
