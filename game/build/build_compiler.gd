class_name BuildCompiler
extends RefCounted

const BOOKS := [&"frost", &"flame", &"storm", &"spirit"]
const Q := 1024
const SHAPES := {&"frost": [&"ice_lance", &"crystal_ring"], &"flame": [&"flame_column", &"embers"], &"storm": [&"lightning_beam", &"radial_lightning"], &"spirit": [&"lone_blade", &"patrol_blade"]}
const MODE_SLOTS: PackedStringArray = ["storage-mode", "shape-mode", "shell-heat-mode", "reserve-mode", "chain-mode", "guard-mode", "transport-mode", "mark-reward-use", "mark-target-spread", "parry-mode", "low-life-allocation", "clear-surplus-use", "study-mode", "guard-order", "shape"]
var catalog: BuildCatalog


func _init(content: BuildCatalog = null) -> void:
	catalog = content if content != null else BuildCatalog.new()


func compile(selection: BuildSelection) -> BuildCompileResult:
	var result := BuildCompileResult.new()
	if selection == null or selection.book_id not in BOOKS:
		result.diagnostics.append("主书：需要有效的法书 ID。")
		return result
	var normalized := normalize_assets(selection)
	if not normalized.diagnostics.is_empty():
		result.diagnostics.append_array(normalized.diagnostics)
		return result
	var instances: Array[CombatAssetInstance] = normalized.instances
	var asset_stacks: Dictionary[StringName, int] = {}
	for instance in instances:
		asset_stacks[instance.content_id] = asset_stacks.get(instance.content_id, 0) + 1
	var ids := selection.talents.duplicate()
	for id in asset_stacks:
		ids.append(str(id))
	if str(selection.book_id) not in ids: ids.append(str(selection.book_id))
	ids.sort()
	var seen: Dictionary[String, bool] = {}
	var build := CompiledBuild.new()
	build._book = selection.book_id
	for id in selection.talents:
		build._permits.append("permit:talent:" + id)
	for id in ids:
		if seen.has(id):
			result.diagnostics.append("%s：重复选择。" % id)
			continue
		seen[id] = true
		var definition := catalog.get_definition(StringName(id))
		if definition == null:
			result.diagnostics.append("%s：目录中不存在。" % id)
			continue
		if id in selection.talents and not (definition is TalentDefinition or definition is BookDefinition):
			result.diagnostics.append("%s：不是可分配天赋。" % id)
		if asset_stacks.has(StringName(id)) and not definition is RelicDefinition:
			result.diagnostics.append("%s：不是遗物资产。" % id)
		if not definition.supported and definition.stage == &"M3":
			result.diagnostics.append("%s %s：%s" % [id, definition.title, definition.unsupported_reason])
			continue
		if not definition.allowed_books.is_empty() and str(selection.book_id) not in definition.allowed_books:
			result.diagnostics.append("%s：仅适用于 %s 主书。" % [id, " / ".join(definition.allowed_books)])
		for required in definition.requires_all:
			if required not in selection.talents:
				result.diagnostics.append("%s：需要实际分配 %s。" % [id, required])
		if not definition.requires_any.is_empty():
			var found := false
			for required in definition.requires_any:
				found = found or required in selection.talents
			if not found:
				result.diagnostics.append("%s：需要 %s 中至少一项。" % [id, " / ".join(definition.requires_any)])
		for permit in definition.permits:
			if "permit:talent:" + permit not in build._permits:
				result.diagnostics.append("%s：缺少许可 permit:talent:%s。" % [id, permit])
		var stacks: int = asset_stacks.get(StringName(id), 1)
		if stacks < 1 or stacks > definition.max_stacks:
			result.diagnostics.append("%s：层数应为 1…%d。" % [id, definition.max_stacks])
		if definition.mode_slot != &"":
			var occupied := build.mode(definition.mode_slot)
			var mode_operation: StringName = definition.rules[0].operation
			if occupied != &"" and occupied != definition.id and build.mode_operation(definition.mode_slot) != mode_operation:
				result.diagnostics.append("%s 与 %s：争用 %s。" % [id, occupied, definition.mode_slot])
			build._modes[definition.mode_slot] = definition.id
			build._mode_operations[definition.mode_slot] = mode_operation
		for rule in definition.rules:
			var diagnostic := CombatRuleContract.diagnose(rule)
			if not diagnostic.is_empty(): result.diagnostics.append("%s：%s" % [id, diagnostic])
			else: _install(build, rule, id, stacks)
		if definition is BookDefinition:
			if definition.id == &"flame":
				build._rules[&"heat"] = true
				build._sources[&"heat"] = PackedStringArray([id])
			if definition.id == selection.book_id:
				build._values[&"base_power_q"] = definition.power_per_character_q
				build._values[&"cadence"] = definition.cadence
		if asset_stacks.has(StringName(id)):
			build._assets[StringName(id)] = stacks
			build._asset_stacks[StringName(id)] = stacks
	build._instances = instances
	if "T57" in selection.talents:
		if selection.secondary_book not in BOOKS or selection.secondary_book == selection.book_id:
			result.diagnostics.append("T57：选择一本非主书作为副书。")
		else:
			build._modes[&"secondary"] = selection.secondary_book
	elif selection.secondary_book != &"":
		result.diagnostics.append("副书：需要实际分配 T57。")
	if "T58" in selection.talents:
		if selection.focus_shape not in SHAPES[selection.book_id]:
			result.diagnostics.append("T58：请选择当前主书的一个形状。")
		else:
			build._modes[&"shape"] = selection.focus_shape
	if "T57" in selection.talents and "T58" in selection.talents:
		result.diagnostics.append("T57 与 T58：合订和独卷互斥。")
	if selection.focus_shape != &"" and "T58" not in selection.talents:
		result.diagnostics.append("独卷形状：需要实际分配 T58。")
	for slot in selection.modes:
		var provider := catalog.get_definition(selection.modes[slot])
		if str(selection.modes[slot]) not in ids or provider == null or provider.mode_slot != slot:
			result.diagnostics.append("%s：模式来源 %s 未分配。" % [slot, selection.modes[slot]])
		else:
			build._modes[slot] = provider.id
			build._mode_operations[slot] = provider.rules[0].operation
	var temporary_ids := selection.temporary_rules.duplicate()
	temporary_ids.sort()
	var temporary_modes: Dictionary[StringName, StringName] = {}
	for index in temporary_ids.size():
		var id := temporary_ids[index]
		if index > 0 and id == temporary_ids[index - 1]:
			result.diagnostics.append("临时覆盖 %s：重复来源。" % id)
			continue
		var definition := catalog.get_definition(StringName(id))
		if definition == null or not definition.supported:
			result.diagnostics.append("临时覆盖 %s：没有可执行定义。" % id)
		else:
			if definition.mode_slot != &"":
				if temporary_modes.has(definition.mode_slot) and temporary_modes[definition.mode_slot] != definition.rules[0].operation:
					result.diagnostics.append("临时覆盖 %s：争用 %s。" % [id, definition.mode_slot])
				temporary_modes[definition.mode_slot] = definition.rules[0].operation
				build._modes[definition.mode_slot] = definition.id
				build._mode_operations[definition.mode_slot] = definition.rules[0].operation
			for rule in definition.rules:
				var diagnostic := CombatRuleContract.diagnose(rule)
				if not diagnostic.is_empty(): result.diagnostics.append("%s：%s" % [id, diagnostic])
				else: _install(build, rule, "temporary:" + id, 1)
	var override_ids: Dictionary[String, bool] = {}
	var override_modes: Dictionary[StringName, StringName] = {}
	for overlay in selection.overrides:
		if overlay.id.is_empty() or overlay.source_id == &"" or override_ids.has(overlay.id):
			result.diagnostics.append("临时覆盖需要独立 ID 与来源，不能重复。")
			continue
		override_ids[overlay.id] = true
		for operation in overlay.capabilities:
			if operation not in CombatRuleContract.OPERATIONS:
				result.diagnostics.append("%s：未登记能力 %s。" % [overlay.id, operation])
			else:
				var temporary_rule := RuleDefinition.new()
				temporary_rule.operation = StringName(operation)
				_install(build, temporary_rule, "override:" + overlay.id, 1)
		for operation in overlay.disabled_capabilities:
			if operation not in CombatRuleContract.OPERATIONS: result.diagnostics.append("%s：未登记停用能力 %s。" % [overlay.id, operation])
		for parameter in overlay.parameter_deltas:
			if not CombatRuleContract.UNITS.has(parameter) or absi(overlay.parameter_deltas[parameter]) > 1 << 30:
				result.diagnostics.append("%s：未登记参数 %s。" % [overlay.id, parameter])
			else: build._values[parameter] = build.value(parameter) + overlay.parameter_deltas[parameter]
		for slot in overlay.modes:
			if override_modes.has(slot) and override_modes[slot] != overlay.modes[slot]:
				result.diagnostics.append("%s：多个临时覆盖争用 %s。" % [overlay.id, slot])
				continue
			override_modes[slot] = overlay.modes[slot]
			var provider := catalog.get_definition(overlay.modes[slot])
			if str(slot) in MODE_SLOTS and overlay.modes[slot] == &"":
				build._modes.erase(slot)
				build._mode_operations.erase(slot)
			elif slot == &"shape" and overlay.modes[slot] in SHAPES[build.book()]:
				build._modes[slot] = overlay.modes[slot]
			elif provider != null and provider.mode_slot == slot:
				build._modes[slot] = provider.id
				build._mode_operations[slot] = provider.rules[0].operation
			else: result.diagnostics.append("%s：未登记模式 %s / %s。" % [overlay.id, slot, overlay.modes[slot]])
	# Suppression is independent of installation order. Expiry recompiles the
	# permanent selection; permits and asset-use receipts are unaffected.
	for overlay in selection.overrides:
		for operation in overlay.disabled_capabilities: build._rules.erase(StringName(operation))
	var available: PackedStringArray = []
	for material in ["cold", "heat", "charge", "summon"]:
		var operation: StringName = &"conduct" if material == "charge" else StringName(material)
		if build.has(operation): available.append(material)
	var secondary_material: String = {&"frost": "cold", &"flame": "heat", &"storm": "charge", &"spirit": "summon"}.get(selection.secondary_book, "")
	if not secondary_material.is_empty() and secondary_material not in available: available.append(secondary_material)
	build._values[&"material_count"] = available.size()
	if build.mode(&"study-mode") == &"K19":
		var materials := selection.calibrated_materials.duplicate()
		if materials.is_empty():
			materials = PackedStringArray([{&"frost": "cold", &"flame": "heat", &"storm": "charge", &"spirit": "summon"}[selection.book_id], secondary_material])
		if materials.size() != 2 or materials[0] == materials[1]:
			result.diagnostics.append("K19：选择两种不同的现有材料。")
		for material in materials:
			if material not in available: result.diagnostics.append("K19：%s 材料没有合法供给。" % material)
		if materials.size() == 2:
			materials.sort()
			build._modes[&"material-1"] = StringName(materials[0])
			build._modes[&"material-2"] = StringName(materials[1])
	# Stable snapshots are independent of acquisition / array order.
	var signature := str(selection.book_id) + str(ids) + str(selection.secondary_book) + str(selection.focus_shape)
	var mode_slots := PackedStringArray(build._modes.keys())
	mode_slots.sort()
	for slot in mode_slots:
		signature += "mode:%s:%s;" % [slot, build.mode(StringName(slot))]
	for instance in instances:
		signature += instance.signature()
	var temporary := selection.temporary_rules.duplicate()
	temporary.sort()
	signature += str(temporary)
	signature += str(build.mode(&"material-1")) + str(build.mode(&"material-2"))
	var overlay_signatures: PackedStringArray = []
	for overlay in selection.overrides:
		var parts: PackedStringArray = [overlay.id, str(overlay.source_id), str(overlay.expires_at)]
		var abilities := overlay.capabilities.duplicate()
		abilities.sort()
		parts.append(str(abilities))
		var disabled := overlay.disabled_capabilities.duplicate()
		disabled.sort()
		parts.append("disabled:" + str(disabled))
		for parameter in overlay.parameter_deltas: parts.append("%s:%s" % [parameter, overlay.parameter_deltas[parameter]])
		for slot in overlay.modes: parts.append("%s:%s" % [slot, overlay.modes[slot]])
		parts.sort()
		overlay_signatures.append(";".join(parts))
	overlay_signatures.sort()
	signature += str(overlay_signatures)
	build._id = (CompiledBuild.PARAMETER_VERSION + ":" + signature).sha256_text()
	if Q + build.value(&"max_hp_bonus_q") <= 0: result.diagnostics.append("生命上限必须保持为正。")
	if Q + build.value(&"guard_efficiency_q") + build.value(&"shell_durability_q") <= 0: result.diagnostics.append("护页折算必须保持为正。")
	if Q + build.value(&"secondary_weight_q") <= 0 or Q + build.value(&"reserve_capacity_q") <= 0: result.diagnostics.append("分配权重和储备容量必须保持为正。")
	if 8 + build.value(&"dot_pulses") <= 0: result.diagnostics.append("持续作用次数必须保持为正。")
	if Q + build.value(&"power_bonus_q") + mini(0, build.value(&"perfect_bonus_q")) <= 0: result.diagnostics.append("主术收入必须保持为正。")
	if 1 + build.value(&"shell_space") <= 0 or 4 + build.value(&"storage_slots") <= 0: result.diagnostics.append("保存空间与外壳占位必须保持为正。")
	for parameter in [&"storage_retention_q", &"split_retention_q", &"chain_retention_q", &"pierce_retention_q", &"transport_retention_q", &"charge_efficiency_q", &"heat_efficiency_q", &"summon_efficiency_q", &"secondary_retention_q", &"dot_retention_q"]:
		if 900 + build.value(parameter) < 0: result.diagnostics.append("%s：加工保留不能为负。" % parameter)
	if 358 + build.value(&"copy_retention_q") < 0: result.diagnostics.append("复制折算不能为负。")
	if result.diagnostics.is_empty():
		result.build = build
	return result


func normalize_assets(selection: BuildSelection) -> Dictionary:
	var diagnostics: PackedStringArray = []
	var instances: Array[CombatAssetInstance] = []
	if not selection.instances.is_empty() and (not selection.assets.is_empty() or not selection.asset_instances.is_empty()):
		diagnostics.append("正式资产实例与开发层数选择不能混用。")
	for id in selection.asset_instances:
		if not selection.assets.has(id): diagnostics.append("%s：开发实例 ID 缺少对应层数。" % id)
	if selection.instances.is_empty():
		for id in selection.assets:
			var definition := catalog.get_definition(id)
			if not definition is RelicDefinition or selection.assets[id] < 1 or selection.assets[id] > definition.max_stacks:
				diagnostics.append("%s：开发资产种类或层数无效。" % id)
				continue
			var base: String = selection.asset_instances.get(id, "lab:" + str(id))
			if base.is_empty():
				diagnostics.append("%s：开发实例 ID 不能为空。" % id)
				continue
			for layer in selection.assets[id]:
				var instance := CombatAssetInstance.new()
				instance.instance_id = "%s:layer:%d" % [base, layer]
				instance.content_id = id
				instance.source_id = &"development"
				instances.append(instance)
	else:
		for instance in selection.instances:
			if instance == null:
				diagnostics.append("资产实例不能为空。")
			else: instances.append(instance.copy())
	var seen: Dictionary[String, bool] = {}
	for instance in instances:
		if instance.instance_id.is_empty() or seen.has(instance.instance_id): diagnostics.append("资产实例 ID 不能为空或重复。")
		seen[instance.instance_id] = true
		if instance.source_id == &"" or instance.expiry_scope not in [&"room", &"chapter", &"run"] or instance.expiry_index < -1:
			diagnostics.append("%s：资产来源或期限声明无效。" % instance.instance_id)
	instances.sort_custom(func(a: CombatAssetInstance, b: CombatAssetInstance) -> bool: return a.instance_id < b.instance_id)
	return {"instances": instances, "diagnostics": diagnostics}


func _install(build: CompiledBuild, rule: RuleDefinition, source: String, stacks: int) -> void:
	if rule.operation != &"":
		build._rules[rule.operation] = true
		var sources := build.sources(rule.operation)
		if source not in sources:
			sources.append(source)
		build._sources[rule.operation] = sources
		if rule.operation == &"charge-clear":
			build._rules[&"conduct"] = true
			var conduct_sources := build.sources(&"conduct")
			if source not in conduct_sources: conduct_sources.append(source)
			build._sources[&"conduct"] = conduct_sources
	for parameter in rule.parameters:
		build._values[parameter] = build.value(parameter) + rule.parameters[parameter] * stacks
