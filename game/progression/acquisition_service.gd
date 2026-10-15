class_name AcquisitionService
extends RefCounted
## Baseline identity checks only; formal reward candidates use BuildCatalog.
const ACTIVE_RELICS = BuildCompiler.RESTORED_RELICS
const RARITY_WEIGHTS := {&"common": 100.0, &"uncommon": 65.0, &"rare": 30.0, &"awakening": 10.0}

var compiler: BuildCompiler


func _init(build_compiler: BuildCompiler = null) -> void:
	compiler = build_compiler if build_compiler != null else BuildCompiler.new()


func evaluate(selection: BuildSelection, content_id: StringName, context: Dictionary = {}) -> Dictionary:
	var definition := compiler.catalog.get_definition(content_id) as RelicDefinition
	var diagnostics: PackedStringArray = []
	if selection == null or definition == null:
		return _result(definition, PackedStringArray(["UNKNOWN_RELIC"]))
	var active := compiler.compile(selection)
	if not active.success(): return _result(definition, active.diagnostics)
	diagnostics = _diagnose(definition, _qualification(active.build), context)
	return _result(definition, diagnostics)


func _diagnose(definition: RelicDefinition, qualification: Dictionary, context: Dictionary) -> PackedStringArray:
	var stacks: Dictionary[StringName, int] = qualification.stacks
	var diagnostics := definition.eligibility(qualification.book, stacks, stacks, qualification.capabilities, qualification.groups, true)
	var content_id := definition.id
	if content_id == &"R017" and int(context.get("longest", 0)) < 3:
		diagnostics.append("VOCABULARY_NEEDS_ASSISTABLE_WORD")
	if content_id == &"R014" and (int(context.get("shortest", 0)) < 1 or int(context.get("shortest", 0)) > 4):
		diagnostics.append("VOCABULARY_NEEDS_SHORT_WORD")
	if content_id in [&"R015", &"P007"] and int(context.get("longest", 0)) < 7:
		diagnostics.append("VOCABULARY_NEEDS_LONG_WORD")
	if content_id == &"G006":
		if int(context.get("shortest", 0)) < 1 or int(context.get("shortest", 0)) > 4: diagnostics.append("VOCABULARY_NEEDS_SHORT_WORD")
		if int(context.get("longest", 0)) < 7: diagnostics.append("VOCABULARY_NEEDS_LONG_WORD")
	if content_id == &"G027":
		var state_sources := 0
		for capability in ["cold", "burn", "shock", "mark"]:
			if capability in qualification.capabilities: state_sources += 1
		if state_sources < 2: diagnostics.append("MISSING_CAPABILITY:第二种元素状态")
	return diagnostics

func candidates(selection: BuildSelection, context: Dictionary = {}) -> PackedStringArray:
	return _candidate_state(selection, context).ids


func _candidate_state(selection: BuildSelection, context: Dictionary) -> Dictionary:
	var ids: PackedStringArray = []
	var active := compiler.compile(selection)
	if not active.success(): return {"ids": ids, "build": null}
	var qualification := _qualification(active.build)
	for id in compiler.catalog.relic_ids():
		var definition := compiler.catalog.get_definition(StringName(id)) as RelicDefinition
		if _diagnose(definition, qualification, context).is_empty():
			ids.append(id)
	return {"ids": ids, "build": active.build}


func _qualification(build: CompiledBuild) -> Dictionary:
	var groups: Dictionary = {}
	var stacks := build.assets()
	for id in stacks:
		var definition := compiler.catalog.get_definition(id) as RelicDefinition
		if definition.exclusive_group == &"": continue
		var members: Array[StringName] = []
		if groups.has(definition.exclusive_group): members = groups[definition.exclusive_group]
		members.append(id)
		groups[definition.exclusive_group] = members
	return {"book": build.book(), "stacks": stacks, "capabilities": build.capabilities(), "groups": groups}


func offered(selection: BuildSelection, context: Dictionary, rng: RandomNumberGenerator, count: int = 3) -> Array[String]:
	var state := _candidate_state(selection, context)
	var ids: PackedStringArray = state.ids
	var offers: Array[String] = []
	if ids.is_empty() or count <= 0: return offers
	var build: CompiledBuild = state.build
	var owned_tags: PackedStringArray = []
	for id in build.assets():
		var definition := compiler.catalog.get_definition(id) as RelicDefinition
		for tag in definition.tags:
			if tag not in owned_tags: owned_tags.append(tag)
	var weights: Array[float] = []
	var roles: Array[StringName] = []
	var first_tags: PackedStringArray = []
	var unowned: Array[bool] = []
	for id in ids:
		var definition := compiler.catalog.get_definition(StringName(id)) as RelicDefinition
		var weight: float = RARITY_WEIGHTS.get(definition.rarity, 100.0)
		if definition.allowed_books.size() == 1 or str(build.book()) in definition.preferred_books: weight *= 1.4
		for tag in definition.tags:
			if tag in owned_tags:
				weight *= 1.25
				break
		if build.asset_stacks(definition.id) > 0: weight *= 0.85
		weights.append(weight)
		roles.append(definition.choice_role)
		first_tags.append(definition.tags[0] if not definition.tags.is_empty() else "")
		unowned.append(build.asset_stacks(definition.id) == 0)
	var selected_roles: Array[StringName] = []
	var selected_tags: PackedStringArray = []
	var selected_new := false
	while not ids.is_empty() and offers.size() < count:
		var choices: Array[int] = []
		for position in ids.size(): choices.append(position)
		if offers.is_empty():
			var mechanisms: Array[int] = []
			for position in choices:
				if roles[position] == &"mechanism": mechanisms.append(position)
			if not mechanisms.is_empty(): choices = mechanisms
		if not selected_new:
			var newcomers: Array[int] = []
			for position in choices:
				if unowned[position]: newcomers.append(position)
			if not newcomers.is_empty(): choices = newcomers
		var other_roles: Array[int] = []
		for position in choices:
			if roles[position] not in selected_roles: other_roles.append(position)
		if not other_roles.is_empty(): choices = other_roles
		var other_tags: Array[int] = []
		for position in choices:
			if first_tags[position] not in selected_tags: other_tags.append(position)
		if not other_tags.is_empty(): choices = other_tags
		var total := 0.0
		for position in choices: total += weights[position]
		var draw := rng.randf() * total
		var index := choices[-1]
		for position in choices:
			draw -= weights[position]
			if draw < 0.0:
				index = position
				break
		offers.append(ids[index])
		selected_roles.append(roles[index])
		selected_tags.append(first_tags[index])
		selected_new = selected_new or unowned[index]
		ids.remove_at(index)
		weights.remove_at(index)
		roles.remove_at(index)
		first_tags.remove_at(index)
		unowned.remove_at(index)
	# Choice roles constrain supply without fixing a role to one screen position.
	for position in range(offers.size() - 1, 0, -1):
		var swap := rng.randi_range(0, position)
		var held := offers[position]
		offers[position] = offers[swap]
		offers[swap] = held
	return offers




func _result(definition: RelicDefinition, diagnostics: PackedStringArray) -> Dictionary:
	return {"eligible": diagnostics.is_empty(), "diagnostics": diagnostics, "definition": definition}
