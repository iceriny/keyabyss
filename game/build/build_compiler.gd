class_name BuildCompiler
extends RefCounted

const BOOKS := [&"frost", &"flame", &"storm", &"spirit"]
const Q := 1024
const RESTORED_RELICS: Array[StringName] = [&"R001", &"R002", &"R003", &"R004", &"R005", &"R006", &"R007", &"R008", &"R009", &"R010", &"R011", &"R012", &"R013", &"R014", &"R015", &"R016", &"R017", &"R018", &"R019", &"R020", &"R021", &"R022", &"R023", &"R024", &"R025", &"R026", &"R027", &"R028", &"R029", &"R030", &"R031", &"R032", &"R033", &"R034", &"R035", &"R036", &"R037", &"R038", &"R039", &"R040", &"R041", &"R042", &"R043", &"R044", &"R045", &"R046", &"R047", &"R048", &"R049", &"R050", &"R051", &"R052", &"R053", &"R054", &"R055", &"R056", &"R057", &"R058"]
# Legacy snapshot readers still name these tokens; compilation does not use them.
const SHAPES := {&"frost": [&"ice_lance", &"crystal_ring"], &"flame": [&"flame_column", &"embers"], &"storm": [&"lightning_beam", &"radial_lightning"], &"spirit": [&"lone_blade", &"patrol_blade"]}
const MODE_SLOTS: PackedStringArray = ["storage-mode", "shape-mode", "shell-heat-mode", "reserve-mode", "chain-mode", "guard-mode", "transport-mode", "mark-reward-use", "mark-target-spread", "parry-mode", "low-life-allocation", "clear-surplus-use", "study-mode", "guard-order", "shape", "material-1", "material-2"]
var catalog: BuildCatalog


func _init(content: BuildCatalog = null) -> void:
	catalog = content if content != null else BuildCatalog.new()


func compile(selection: BuildSelection) -> BuildCompileResult:
	var result := BuildCompileResult.new()
	if selection == null or selection.book_id not in BOOKS:
		result.diagnostics.append("主书：需要有效的法书 ID。")
		return result
	if selection.growth_hp < 0 or selection.growth_hp > 20:
		result.diagnostics.append("成长生命需要0…20。")
		return result
	if selection.base_hp < 1 or selection.base_hp > 200:
		result.diagnostics.append("基础生命需要1…200。")
		return result
	var normalized := normalize_assets(selection)
	if not normalized.diagnostics.is_empty():
		result.diagnostics.append_array(normalized.diagnostics)
		return result
	var build := CompiledBuild.new()
	build._book = selection.book_id
	var book := catalog.get_definition(selection.book_id) as BookDefinition
	build._values[&"base_power_q"] = book.power_per_character_q
	build._values[&"cadence"] = book.cadence
	build._values[&"max_hp_flat_q"] = selection.growth_hp * Q
	build._values[&"base_hp_q"] = selection.base_hp * Q
	for rule in book.rules: _install(build, rule, str(book.id), 1)
	if book.id == &"flame":
		build._rules[&"heat"] = true
		build._rules[&"dot"] = true
	var instances: Array[CombatAssetInstance] = normalized.instances
	for instance in instances:
		var definition := catalog.get_definition(instance.content_id) as RelicDefinition
		if definition == null or instance.content_id not in RESTORED_RELICS:
			result.diagnostics.append("%s：遗物尚未恢复。" % instance.content_id)
			continue
		if not definition.allowed_books.is_empty() and str(selection.book_id) not in definition.allowed_books:
			result.diagnostics.append("%s：不适用于当前主书。" % instance.content_id)
		for required in definition.requires_all:
			var owned := false
			for asset in instances: owned = owned or str(asset.content_id) == required
			if not owned: result.diagnostics.append("%s：需要局内遗物%s。" % [instance.content_id, required])
		var stacks: int = build._asset_stacks.get(instance.content_id, 0) + 1
		if stacks > definition.max_stacks: result.diagnostics.append("%s：超过叠层上限。" % instance.content_id)
		build._assets[instance.content_id] = stacks
		build._asset_stacks[instance.content_id] = stacks
		for rule in definition.rules:
			var diagnostic := CombatRuleContract.diagnose(rule)
			if not diagnostic.is_empty(): result.diagnostics.append(diagnostic)
			else: _install(build, rule, str(definition.id), 1)
	build._instances = instances
	var signatures: PackedStringArray = []
	for instance in instances: signatures.append(instance.signature())
	signatures.sort()
	build._id = (CompiledBuild.PARAMETER_VERSION + ":" + str(selection.book_id) + ":" + str(selection.growth_hp) + ":" + str(selection.base_hp) + str(signatures)).sha256_text()
	if build.maximum_hp_q() <= 0: result.diagnostics.append("生命上限必须保持为正。")
	if result.diagnostics.is_empty(): result.build = build
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
		if instance.variant_id != &"":
			diagnostics.append("UNKNOWN_ASSET_VARIANT:" + str(instance.variant_id))
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
