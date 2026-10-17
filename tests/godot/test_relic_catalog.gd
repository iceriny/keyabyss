extends SceneTree

class CountingCompiler extends BuildCompiler:
	var compile_calls: int = 0

	func compile(selection: BuildSelection) -> BuildCompileResult:
		compile_calls += 1
		return super.compile(selection)

var checks: int = 0
var failures: int = 0
var reach_compiler: BuildCompiler
var reach_service: AcquisitionService
var include_retired_sources: bool = false
const WORD_CONTEXT := {"shortest": 3, "longest": 8}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	_test_retired_compatibility()
	_test_current_qualification()
	_test_effect_source_contract()
	_test_qualification()
	_test_capability_topology()
	_test_modifiers()
	_test_offers()
	_test_offer_roles()
	_test_expansion_supply()
	print("RELIC_CATALOG: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_catalog() -> void:
	var catalog := BuildCatalog.new()
	var ids := catalog.relic_ids()
	var all_ids := catalog.relic_ids(true)
	_check(ids.size() == 97 and all_ids.size() == 196, "Active rewards contain 97 identities while all 196 definitions remain readable")
	var expected := BuildCatalog.ACTIVE_RELIC_IDS.duplicate()
	expected.sort()
	_check(ids == expected, "Official rewards match the single active ID policy")
	var sorted := ids.duplicate()
	sorted.sort()
	_check(ids == sorted, "Relic directory has stable ID ordering")
	var awakening := catalog.get_definition(&"R048") as RelicDefinition
	_check(awakening.allowed_books == PackedStringArray(["spirit"]), "Packed resources retain the awakening's book restriction")
	_check(awakening.requires_all == PackedStringArray(["R005", "R035"]), "Packed resources retain the awakening's required relic identities")
	_check((catalog.get_definition(&"R039") as RelicDefinition).grants_capabilities == PackedStringArray(["shield"]), "Packed resources retain the acquired shield source")
	for index in range(1, 59):
		_check("R%03d" % index in all_ids, "Baseline definition survives: R%03d" % index)
	reach_compiler = BuildCompiler.new(catalog)
	reach_service = AcquisitionService.new(reach_compiler)
	for book in BuildCompiler.BOOKS:
		var capacity := 0
		var expected_capacity := 0
		for id in ids:
			var definition := catalog.get_definition(StringName(id)) as RelicDefinition
			if not definition.allowed_books.is_empty() and str(book) not in definition.allowed_books: continue
			expected_capacity += 1
			if "--expanded" not in OS.get_cmdline_user_args(): continue
			var initial := BuildSelection.new()
			initial.book_id = book
			var plan: Array[Dictionary] = [{"kind": "relic", "id": definition.id, "wanted": 1, "ancestors": PackedStringArray()}]
			var reached := _follow_acquisition_plan(initial, plan)
			_check(reached != null, "%s can acquire %s from real prerequisite and capability sources" % [book, id])
			if reached != null:
				capacity += 1
				_check(reach_compiler.compile(reached).success(), "%s/%s reachable selection passes the same compiler" % [book, id])
		if "--expanded" in OS.get_cmdline_user_args():
			print("RELIC_CAPACITY ", book, ": ", capacity)
			_check(capacity == expected_capacity, "%s can reach every active definition allowed for its book (%d/%d)" % [book, capacity, expected_capacity])
		var selection := BuildSelection.new()
		selection.book_id = book
		var pool := AcquisitionService.new(BuildCompiler.new(catalog)).candidates(selection, WORD_CONTEXT)
		_check(not pool.is_empty(), "%s begins with reachable rewards" % book)
		for id in pool:
			_check(id in ids, "Reward is present in the same directory: " + id)
	var second := BuildCatalog.new()
	catalog.definitions.erase(&"R001")
	_check(second.get_definition(&"R001") != null, "Catalog dictionaries do not expose the shared loading cache")


func _test_retired_compatibility() -> void:
	var catalog := BuildCatalog.new()
	reach_compiler = BuildCompiler.new(catalog)
	reach_service = AcquisitionService.new(reach_compiler)
	include_retired_sources = true
	var active_ids := catalog.relic_ids()
	for id in catalog.relic_ids(true):
		if id in active_ids: continue
		var definition := catalog.get_definition(StringName(id)) as RelicDefinition
		var selection := BuildSelection.new()
		if not definition.allowed_books.is_empty(): selection.book_id = StringName(definition.allowed_books[0])
		var plan: Array[Dictionary] = [{"kind": "relic", "id": definition.id, "wanted": 1, "ancestors": PackedStringArray()}]
		var reached := _follow_acquisition_plan(selection, plan)
		_check(reached != null, "Retired definition retains compatible prerequisites and issued-offer qualification: " + id)
		if reached == null: continue
		var compiled := reach_compiler.compile(reached)
		_check(compiled.success(), "Retired assets continue to compile: " + id)
		if not compiled.success(): continue
		var formal := BuildSelection.new()
		formal.book_id = reached.book_id
		formal.instances = compiled.build.asset_instances()
		var restored := BuildSelection.from_dict(formal.to_dict())
		_check(restored != null and reach_compiler.compile(restored).success(), "Saved retired instances round-trip with their original IDs: " + id)
		var prior := reached.copy()
		prior.assets.erase(definition.id)
		_check(reach_service.evaluate(prior, definition.id, WORD_CONTEXT).eligible, "A previously issued retired offer can still be accepted: " + id)
		_check(id not in reach_service.candidates(prior, WORD_CONTEXT), "Retired IDs stay out of new candidate pools: " + id)
	include_retired_sources = false


func _test_current_qualification() -> void:
	var catalog := BuildCatalog.new()
	var service := AcquisitionService.new(BuildCompiler.new(catalog))
	for book in BuildCompiler.BOOKS:
		var empty := BuildSelection.new()
		empty.book_id = book
		_check(service.evaluate(empty, &"R005", WORD_CONTEXT).eligible == (book == &"spirit"), "paper enhancement requires a real spirit source: " + str(book))
		_check(service.evaluate(empty, &"R035", WORD_CONTEXT).eligible, "explicit cross-book spirit source remains reachable: " + str(book))
		empty.assets[&"R035"] = 1
		_check(service.evaluate(empty, &"R005", WORD_CONTEXT).eligible, "cross-book summoning unlocks its enhancement: " + str(book))
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261015
		for draw in 128:
			for id in service.offered(empty, WORD_CONTEXT, rng):
				var item := catalog.get_definition(StringName(id)) as RelicDefinition
				_check(item.allowed_books.is_empty() or str(book) in item.allowed_books, "actual offer respects its main-book restriction: " + id)
	var invalid := BuildSelection.new()
	invalid.assets[&"R005"] = 1
	_check(not service.compiler.compile(invalid).success(), "direct selection cannot bypass the summoning prerequisite")
	for id in [&"R053", &"R054", &"A007", &"A021"]:
		_check(not service.evaluate(BuildSelection.new(), id, WORD_CONTEXT).eligible, "frost cannot acquire flame-seal-only effects: " + str(id))
	var selection := BuildSelection.new()
	_check(service.evaluate(selection, &"G006", WORD_CONTEXT).eligible, "Mixed-length relic accepts a vocabulary containing short and long words")
	var short_only := service.evaluate(selection, &"G006", {"shortest": 3, "longest": 5})
	_check(not short_only.eligible and "VOCABULARY_NEEDS_LONG_WORD" in short_only.diagnostics, "Mixed-length relic reports the existing long-word diagnostic")
	var long_only := service.evaluate(selection, &"G006", {"shortest": 5, "longest": 9})
	_check(not long_only.eligible and "VOCABULARY_NEEDS_SHORT_WORD" in long_only.diagnostics, "Mixed-length relic reports the existing short-word diagnostic")
	selection.assets[&"G006"] = 1
	_check(service.compiler.compile(selection).success(), "An owned mixed-length relic is not invalidated by acquisition-only vocabulary restrictions")
	selection = BuildSelection.new()
	_check(not service.evaluate(selection, &"G027", WORD_CONTEXT).eligible, "A single native elemental state cannot unlock a mixed-state reaction")
	selection.assets[&"G024"] = 1
	_check(service.evaluate(selection, &"G027", WORD_CONTEXT).eligible, "Two elemental state sources unlock the mixed-state reaction")
	selection = BuildSelection.new()
	selection.book_id = &"spirit"
	_check("P007" not in service.candidates(selection, {"shortest": 3, "longest": 6}), "Long-word paper command stays out of vocabularies ending at six letters")
	_check("P007" in service.candidates(selection, {"shortest": 3, "longest": 7}), "Long-word paper command appears when a seven-letter word is available")
	for id in [&"R044", &"R045", &"R046", &"R047", &"R048", &"R049", &"R056"]:
		var definition := catalog.get_definition(id) as RelicDefinition
		_check(definition.required_stacks.size() == 2, "Awakening keeps its two identity prerequisites: " + str(id))
		for required in definition.required_stacks:
			_check(definition.required_stacks[required] == 1, "Awakening no longer requires duplicate prerequisite layers: " + str(id))


## Search only obtains relics through the public qualification API. Each target
## begins from an empty build; capability providers and exclusive branches are
## alternatives with backtracking, never preinstalled authorization fixtures.
func _follow_acquisition_plan(selection: BuildSelection, plan: Array[Dictionary]) -> BuildSelection:
	if plan.is_empty(): return selection
	var task: Dictionary = plan[0]
	var tail := plan.duplicate()
	tail.pop_front()
	if task.kind == "acquire":
		if not include_retired_sources and str(task.id) not in reach_compiler.catalog.relic_ids(): return null
		var candidate := selection.copy()
		while int(candidate.assets.get(task.id, 0)) < int(task.wanted):
			if not reach_service.evaluate(candidate, task.id, WORD_CONTEXT).eligible: return null
			candidate.assets[task.id] = int(candidate.assets.get(task.id, 0)) + 1
		return _follow_acquisition_plan(candidate, tail)
	if task.kind == "any":
		for id: String in task.ids:
			if int(selection.assets.get(StringName(id), 0)) > 0:
				return _follow_acquisition_plan(selection, tail)
		for id: String in task.ids:
			var branch: Array[Dictionary] = [{"kind": "relic", "id": StringName(id), "wanted": 1, "ancestors": task.ancestors}]
			branch.append_array(tail)
			var reached := _follow_acquisition_plan(selection, branch)
			if reached != null: return reached
		return null
	if task.kind == "capability":
		var compiled := reach_compiler.compile(selection)
		if str(task.capability) in compiled.build.capabilities(): return _follow_acquisition_plan(selection, tail)
		for id in reach_compiler.catalog.relic_ids(include_retired_sources):
			var source := reach_compiler.catalog.get_definition(StringName(id)) as RelicDefinition
			if str(task.capability) not in source.provided_capabilities(): continue
			var branch: Array[Dictionary] = [{"kind": "relic", "id": source.id, "wanted": 1, "ancestors": task.ancestors}]
			branch.append_array(tail)
			var reached := _follow_acquisition_plan(selection, branch)
			if reached != null: return reached
		return null
	if task.kind == "capability_count":
		var compiled := reach_compiler.compile(selection)
		var sources := 0
		for capability: String in task.options:
			if capability in compiled.build.capabilities(): sources += 1
		if sources >= int(task.minimum): return _follow_acquisition_plan(selection, tail)
		for capability: String in task.options:
			if capability in compiled.build.capabilities(): continue
			var branch: Array[Dictionary] = [{"kind": "capability", "capability": capability, "ancestors": task.ancestors}, task]
			branch.append_array(tail)
			var reached := _follow_acquisition_plan(selection, branch)
			if reached != null: return reached
		return null
	var id: StringName = task.id
	if int(selection.assets.get(id, 0)) >= int(task.wanted): return _follow_acquisition_plan(selection, tail)
	var ancestors: PackedStringArray = task.ancestors
	if str(id) in ancestors: return null
	var definition := reach_compiler.catalog.get_definition(id) as RelicDefinition
	if definition == null or int(task.wanted) > definition.max_stacks: return null
	if not definition.allowed_books.is_empty() and str(selection.book_id) not in definition.allowed_books: return null
	if definition.exclusive_group != &"":
		for owned in selection.assets:
			var other := reach_compiler.catalog.get_definition(owned) as RelicDefinition
			if other.id != id and other.exclusive_group == definition.exclusive_group: return null
	ancestors = ancestors.duplicate()
	ancestors.append(str(id))
	var prerequisites: Array[Dictionary] = []
	for required in definition.requires_all:
		prerequisites.append({"kind": "relic", "id": StringName(required), "wanted": 1, "ancestors": ancestors})
	for required in definition.required_stacks:
		prerequisites.append({"kind": "relic", "id": required, "wanted": definition.required_stacks[required], "ancestors": ancestors})
	if not definition.requires_any.is_empty():
		prerequisites.append({"kind": "any", "ids": definition.requires_any, "ancestors": ancestors})
	for capability in definition.required_capabilities():
		prerequisites.append({"kind": "capability", "capability": capability, "ancestors": ancestors})
	for group in definition.required_capability_groups():
		prerequisites.append({"kind": "capability_count", "options": group.options, "minimum": group.minimum, "ancestors": ancestors})
	prerequisites.append({"kind": "acquire", "id": id, "wanted": task.wanted})
	prerequisites.append_array(tail)
	return _follow_acquisition_plan(selection, prerequisites)


func _test_effect_source_contract() -> void:
	var catalog := BuildCatalog.new()
	var service := AcquisitionService.new(BuildCompiler.new(catalog))
	var empty_stacks: Dictionary[StringName, int] = {}
	var audit: Array[Dictionary] = []
	for key in RelicParameters.CAPS:
		_check(RelicDefinition.SOURCE_REQUIREMENTS.has(key) or RelicDefinition.SOURCE_GRANTS.has(key) or RelicDefinition.SOURCE_GROUPS.has(key) or str(key) in RelicDefinition.SOURCE_INDEPENDENT, "Every supported effect parameter explicitly classifies its source contract: " + str(key))
	# Ignore book restrictions here on purpose: effect requirements must stand on
	# their own instead of depending on a matching book ID or a cosmetic tag.
	for id in catalog.relic_ids():
		var relic := catalog.get_definition(StringName(id)) as RelicDefinition
		var requirements := relic.required_capabilities()
		var sources := relic.provided_capabilities()
		for key in relic.modifiers:
			for required: String in RelicDefinition.SOURCE_REQUIREMENTS.get(key, []):
				_check(required in requirements, "%s/%s inherits its effect source requirement" % [id, key])
		for required in requirements:
			var available := requirements.duplicate()
			for option in relic.requires_any_capabilities:
				if option != required and option not in available: available.append(option)
			available.remove_at(available.find(required))
			var messages := relic.eligibility(&"frost", empty_stacks, empty_stacks, available, {}, true)
			_check("MISSING_CAPABILITY:" + required in messages, "%s cannot bypass a missing %s effect source" % [id, required])
			var only_self := sources.duplicate()
			if required not in only_self:
				messages = relic.eligibility(&"frost", empty_stacks, empty_stacks, only_self, {}, true)
				_check("MISSING_CAPABILITY:" + required in messages, "%s output cannot manufacture its unrelated %s input" % [id, required])
		audit.append({"id": id, "title": relic.title, "requires": requirements, "groups": relic.required_capability_groups(), "provides": sources})
	for key in RelicDefinition.SOURCE_REQUIREMENTS:
		var relic := RelicDefinition.new()
		relic.id = &"FIXTURE_MODIFIER"
		relic.modifiers[key] = 1
		var messages := relic.eligibility(&"flame", empty_stacks, empty_stacks, PackedStringArray(), {}, true)
		for required: String in RelicDefinition.SOURCE_REQUIREMENTS[key]:
			_check("MISSING_CAPABILITY:" + required in messages, "A new untagged %s modifier still needs %s" % [key, required])
	# Produce a source through normal acquisition; ownership labels alone do not count.
	var selection := BuildSelection.new()
	selection.book_id = &"flame"
	_check(not service.evaluate(selection, &"G008", WORD_CONTEXT).eligible, "Flame starts without a shield source")
	var acquired := RunTransactionService.new(service.compiler).prepare_acquisition(selection, RunCombatState.new(), &"G006", "source-test:shield", "", WORD_CONTEXT)
	_check(acquired.diagnostics.is_empty(), "A real self-contained word trigger can be acquired first")
	_check(service.evaluate(acquired.selection, &"G008", WORD_CONTEXT).eligible, "The acquired word shield unlocks shield enhancements")
	selection = BuildSelection.new()
	selection.book_id = &"spirit"
	acquired = RunTransactionService.new(service.compiler).prepare_acquisition(selection, RunCombatState.new(), &"P025", "source-test:shock", "", WORD_CONTEXT)
	_check(acquired.diagnostics.is_empty() and "shock" in acquired.build.capabilities(), "Spirit-triggered shock is a source after actual acquisition")
	_check(service.evaluate(acquired.selection, &"G027", WORD_CONTEXT).eligible, "Spirit mark plus acquired shock unlock a two-state consumer")
	var invalid := BuildSelection.new()
	invalid.assets[&"G027"] = 1
	_check(not service.compiler.compile(invalid).success(), "Direct compilation cannot bypass a two-source consumer")
	var mixed := RelicDefinition.new()
	mixed.id = &"FIXTURE_MIXED"
	mixed.modifiers[&"mixed_pct"] = 10
	_check(not mixed.eligibility(&"frost", empty_stacks, empty_stacks, PackedStringArray(["cold"]), {}, true).is_empty(), "A new untagged mixed-state modifier still requires two different sources")
	_check(mixed.eligibility(&"frost", empty_stacks, empty_stacks, PackedStringArray(["cold", "mark"]), {}, true).is_empty(), "Two real sources unlock a mixed-state modifier")
	mixed.modifiers.clear()
	mixed.requires_any_capabilities = ["mark", "mark"]
	mixed.minimum_capabilities = 2
	_check(not mixed.eligibility(&"spirit", empty_stacks, empty_stacks, PackedStringArray(["mark"]), {}, true).is_empty(), "Repeated capability names cannot pay a two-source prerequisite twice")
	var source_catalog := _fixture_catalog()
	var upgrade := _relic(source_catalog, &"XUPGRADE")
	upgrade.modifiers[&"fire_field_rate_pct"] = 10
	upgrade.tags = ["fire_field"]
	var producer := _relic(source_catalog, &"ZSOURCE")
	producer.grants_capabilities = ["fire_field"]
	var source_service := AcquisitionService.new(BuildCompiler.new(source_catalog))
	selection = BuildSelection.new()
	selection.book_id = &"storm"
	_check(not source_service.evaluate(selection, upgrade.id, WORD_CONTEXT).eligible and "XUPGRADE" not in source_service.candidates(selection, WORD_CONTEXT), "A fire-fog tag does not grant a fire-fog source")
	var offer_rng := RandomNumberGenerator.new()
	offer_rng.seed = 17
	_check("XUPGRADE" not in source_service.offered(selection, WORD_CONTEXT, offer_rng), "An unowned source offered alongside cannot qualify its enhancement")
	selection.assets[producer.id] = 1
	_check(source_service.evaluate(selection, upgrade.id, WORD_CONTEXT).eligible, "A declared provider unlocks a later-sorted enhancement")
	selection.assets[upgrade.id] = 1
	producer.requires_capabilities = ["fixture-cycle"]
	upgrade.grants_capabilities = ["fixture-cycle"]
	_check(not source_service.compiler.compile(selection).success(), "Implicit modifier requirements also reject source cycles")
	for book in BuildCompiler.BOOKS:
		selection = BuildSelection.new()
		selection.book_id = book
		for step in 12:
			var rng := RandomNumberGenerator.new()
			rng.seed = (str(book) + ":sources:" + str(step)).hash()
			var offered := service.offered(selection, WORD_CONTEXT, rng)
			for id in offered:
				_check(service.evaluate(selection, StringName(id), WORD_CONTEXT).eligible, "Real %s offer %d obeys all effect-source prerequisites: %s" % [book, step, id])
			if offered.is_empty(): break
			acquired = RunTransactionService.new(service.compiler).prepare_acquisition(selection, RunCombatState.new(), StringName(offered[0]), "%s:%d" % [book, step], "", WORD_CONTEXT)
			_check(acquired.diagnostics.is_empty(), "Sequential %s acquisition %d uses the same prerequisite contract" % [book, step])
			selection = acquired.selection
	var output_path := "res://.temp/relic-sources-%d.json" % OS.get_process_id()
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(audit, "\t"))
	print("RELIC_SOURCE_AUDIT ", output_path)


func _test_qualification() -> void:
	var catalog := _fixture_catalog()
	var base := _relic(catalog, &"XBASE", 3)
	var consumer := _relic(catalog, &"XCONSUMER")
	consumer.required_stacks = {&"XBASE": 2}
	consumer.requires_any = ["XBASE", "XALTERNATE"]
	consumer.requires_all = ["XBASE"]
	consumer.allowed_books = ["frost"]
	var compiler := BuildCompiler.new(catalog)
	var service := AcquisitionService.new(compiler)
	var selection := BuildSelection.new()
	selection.assets[base.id] = 1
	_check(not service.evaluate(selection, consumer.id).eligible, "One prerequisite layer cannot satisfy two required layers")
	selection.assets[base.id] = 2
	_check(service.evaluate(selection, consumer.id).eligible, "Required stacks use the whole current build")
	selection.assets[consumer.id] = 1
	var compiled := compiler.compile(selection)
	_check(compiled.success(), "A qualified owned relic compiles at its maximum")
	_check(not service.evaluate(selection, consumer.id).eligible, "Acquisition rejects one additional layer beyond maximum")
	var formal := BuildSelection.new()
	formal.instances = compiled.build.asset_instances()
	var extra := formal.instances[0].copy()
	for instance in formal.instances:
		if instance.content_id == consumer.id: extra = instance.copy()
	extra.instance_id += ":extra"
	formal.instances.append(extra)
	_check(not compiler.compile(formal).success(), "Formal saved instances cannot bypass the maximum stack limit")
	selection.assets[base.id] = 1
	_check(not compiler.compile(selection).success(), "Compilation rejects the same missing prerequisite layers")
	selection.assets[base.id] = 2
	selection.book_id = &"flame"
	_check(not compiler.compile(selection).success(), "Compilation enforces the main book")
	var left := _relic(catalog, &"XLEFT", 2)
	var right := _relic(catalog, &"XRIGHT")
	left.exclusive_group = &"fixture-branch"
	right.exclusive_group = left.exclusive_group
	selection = BuildSelection.new()
	selection.assets[left.id] = 1
	_check(service.evaluate(selection, left.id).eligible, "An exclusive choice can stack itself")
	_check(not service.evaluate(selection, right.id).eligible, "An exclusive sibling cannot enter rewards")
	selection.assets[right.id] = 1
	_check(not compiler.compile(selection).success(), "A direct selection cannot bypass mutually exclusive choices")


func _test_capability_topology() -> void:
	var catalog := _fixture_catalog()
	var producer := _relic(catalog, &"ZPRODUCER")
	producer.grants_capabilities = ["fixture-source"]
	var consumer := _relic(catalog, &"ACONSUMER")
	consumer.requires_capabilities = ["fixture-source"]
	consumer.grants_capabilities = ["fixture-result"]
	var compiler := BuildCompiler.new(catalog)
	var service := AcquisitionService.new(compiler)
	var selection := BuildSelection.new()
	_check(not service.evaluate(selection, consumer.id).eligible, "Unavailable capabilities keep a reward out of the pool")
	selection.assets[consumer.id] = 1
	_check(not compiler.compile(selection).success(), "A selected consumer cannot manufacture its source")
	selection.assets[producer.id] = 1
	var compiled := compiler.compile(selection)
	_check(compiled.success() and "fixture-result" in compiled.build.capabilities(), "Topology finds a later-sorted source before activating its consumer")
	var copy := compiled.build.capabilities()
	copy.append("foreign")
	_check("foreign" not in compiled.build.capabilities(), "Capability readers receive detached copies")
	producer.requires_capabilities = ["fixture-result"]
	_check(not compiler.compile(selection).success(), "Capabilities with no base source cannot form a circular authorization")
	producer.requires_capabilities.clear()
	producer.requires_all = [str(consumer.id)]
	consumer.requires_all = [str(producer.id)]
	consumer.requires_capabilities.clear()
	_check(not compiler.compile(selection).success(), "Relic ID prerequisite cycles are rejected")
	var self_source := _relic(catalog, &"XSELF")
	self_source.requires_capabilities = ["self-source"]
	self_source.grants_capabilities = ["self-source"]
	selection = BuildSelection.new()
	selection.assets[self_source.id] = 1
	_check(not compiler.compile(selection).success(), "A relic cannot satisfy its own capability prerequisite")
	for book in BuildCompiler.BOOKS:
		selection = BuildSelection.new()
		selection.book_id = book
		var result := compiler.compile(selection)
		var expected := PackedStringArray(BuildCompiler.BOOK_CAPABILITIES[book])
		expected.sort()
		_check(result.success() and result.build.capabilities() == expected, "%s supplies its base capabilities" % book)


func _test_modifiers() -> void:
	var catalog := _fixture_catalog()
	var bonus := _relic(catalog, &"XBONUS", 2)
	bonus.modifiers = {&"power_pct": 50, &"perfect_pct": -50}
	bonus.numbers = {&"compound_pct": 25.0, &"flat": 4.0, &"fixed_ms": 600.0}
	bonus.compound_values = ["compound_pct"]
	bonus.stack_values = ["flat"]
	var selection := BuildSelection.new()
	selection.assets[bonus.id] = 2
	var compiler := BuildCompiler.new(catalog)
	var compiled := compiler.compile(selection)
	_check(compiled.success() and compiled.build.modifier(&"power_pct") == RelicParameters.CAPS[&"power_pct"], "Modifiers aggregate layers before their positive cap")
	_check(compiled.build.modifier(&"perfect_pct") == -RelicParameters.CAPS[&"perfect_pct"], "Explicit costs respect their negative cap")
	_check(compiled.build.modifier(&"absent_pct") == 0, "An absent modifier is neutral")
	_check(is_equal_approx(compiled.build.relic_number(bonus.id, &"compound_pct"), 56.25), "Compounded relic percentages are precomputed from their resource")
	_check(compiled.build.relic_number(bonus.id, &"flat") == 8.0 and compiled.build.relic_number(bonus.id, &"fixed_ms") == 600.0, "Linear and fixed relic numbers keep their distinct stacking semantics")
	_check(compiled.build.relic_number(&"unowned", &"flat") == 0.0, "Unowned relics have neutral runtime numbers")
	bonus.modifiers[&"max_hp_flat"] = 4
	_check(compiler.compile(selection).build.maximum_hp_q() == 108 * 1024, "Flat health modifiers are consumed by maximum health")
	bonus.modifiers[&"unregistered_pct"] = 1
	_check(not compiler.compile(selection).success(), "Unregistered relic parameters fail compilation")


func _test_offers() -> void:
	var catalog := _fixture_catalog()
	for index in 8:
		var definition := _relic(catalog, StringName("O%02d" % index), 2)
		definition.rarity = &"awakening" if index == 7 else &"common"
		definition.tags = ["fixture-tag"]
		definition.preferred_books = ["frost"]
	var compiler := CountingCompiler.new(catalog)
	var service := AcquisitionService.new(compiler)
	var selection := BuildSelection.new()
	selection.assets[&"O00"] = 1
	var pool := service.candidates(selection)
	_check(compiler.compile_calls == 1, "Candidates compile the current build exactly once")
	compiler.compile_calls = 0
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 20261011
	second.seed = first.seed
	var a := service.offered(selection, {}, first)
	var b := service.offered(selection, {}, second)
	_check(a == b and first.state == second.state, "Identical RNG states produce identical offers and subsequent state")
	_check(compiler.compile_calls == 2, "Each weighted offer compiles only once")
	var unique: Dictionary = {}
	for id in a: unique[id] = true
	_check(a.size() == 3 and unique.size() == 3, "Default offers select three IDs without replacement")
	var all := service.offered(selection, {}, first, 99)
	all.sort()
	_check(PackedStringArray(all) == pool and "O07" in all, "Every nonzero rarity remains reachable and a large count stops at pool size")


func _test_offer_roles() -> void:
	var catalog := _fixture_catalog()
	var specs := [
		[&"OMECHANISM", &"mechanism", "chain"],
		[&"OPOWER", &"power", "damage"],
		[&"ODEFENSE", &"defense", "chain"],
		[&"ORECOVERY", &"recovery", "healing"],
		[&"ONEWPOWER", &"power", "damage"],
	]
	for spec: Array in specs:
		var definition := _relic(catalog, spec[0], 2)
		definition.choice_role = spec[1]
		definition.tags = [spec[2]]
	var compiler := CountingCompiler.new(catalog)
	var service := AcquisitionService.new(compiler)
	var selection := BuildSelection.new()
	selection.assets[&"OMECHANISM"] = 1
	selection.assets[&"OPOWER"] = 1
	var mechanism_positions: Dictionary[int, bool] = {}
	for seed_value in range(32):
		var offer_rng := RandomNumberGenerator.new()
		offer_rng.seed = seed_value
		compiler.compile_calls = 0
		var offers := service.offered(selection, {}, offer_rng)
		_check(compiler.compile_calls == 1, "Role-aware offers still compile once")
		var roles: Dictionary[StringName, bool] = {}
		var tags: Dictionary[String, bool] = {}
		var has_new := false
		for id in offers:
			var definition := catalog.get_definition(StringName(id)) as RelicDefinition
			roles[definition.choice_role] = true
			tags[definition.tags[0]] = true
			has_new = has_new or not selection.assets.has(definition.id)
			if definition.choice_role == &"mechanism": mechanism_positions[offers.find(id)] = true
		_check(offers.size() == 3 and roles.has(&"mechanism") and has_new, "Every feasible offer includes a mechanism and an unowned identity")
		_check(roles.size() == 3 and tags.size() == 3, "Available role and first-tag diversity wins before weighted preference")
	_check(mechanism_positions.size() > 1, "Mechanisms do not always occupy the same choice position")
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var single := service.offered(selection, {}, rng, 1)
	_check(single == ["OMECHANISM"], "A single slot prioritizes a mechanism when a new identity cannot also fit")
	_check(service.offered(selection, {}, rng, 0).is_empty(), "A zero-count offer remains empty")
	var invalid := selection.copy()
	invalid.book_id = &"missing"
	_check(service.offered(invalid, {}, rng).is_empty(), "Invalid builds cannot produce role-aware offers")
	for id in [&"OPOWER", &"ODEFENSE", &"ORECOVERY", &"ONEWPOWER"]: catalog.definitions.erase(id)
	selection.assets.erase(&"OPOWER")
	var all := service.offered(selection, {}, rng, 99)
	_check(all == ["OMECHANISM"], "A pool with one owned role/tag falls back without excluding its only reward")


func _test_expansion_supply() -> void:
	var catalog := BuildCatalog.new()
	var service := AcquisitionService.new(BuildCompiler.new(catalog))
	var numerical: Dictionary[StringName, Dictionary] = {
		&"G008": {&"shield_cap": 15}, &"G020": {&"ultimate_ms": 1000},
		&"F001": {&"cold_pct": 20}, &"F021": {&"frost_flight_pct": 12},
		&"A007": {&"fire_field_radius": 15}, &"A008": {&"dodge_flame_ms": 750, &"dodge_flame_radius": 12}, &"A011": {&"flame_wave_pct": 20},
		&"T007": {&"storm_burst_pct": 20}, &"T008": {&"storm_burst_radius": 16},
		&"P008": {&"spirit_speed_pct": 12}, &"P009": {&"spirit_cooldown_pct": 12}, &"P012": {&"crane_radius": 6},
	}
	for id in numerical:
		var definition := catalog.get_definition(id) as RelicDefinition
		_check(str(id) in catalog.relic_ids() and definition.max_stacks == 2, "Expanded numerical identity remains an active two-layer reward: " + str(id))
		_check(definition.choice_role != &"mechanism", "A larger value or radius is not labeled as a behavior mechanism: " + str(id))
		for key: StringName in numerical[id]:
			_check(definition.modifiers.get(key) == numerical[id][key], "Numerical resource has its selected per-layer value: " + str(id) + "/" + str(key))
			_check(int(definition.modifiers[key]) * definition.max_stacks <= int(RelicParameters.CAPS[key]), "Both numerical layers remain useful below their shared cap: " + str(id) + "/" + str(key))
	var roles: Dictionary[StringName, StringName] = {
		&"G017": &"defense", &"G021": &"recovery", &"G023": &"recovery", &"G031": &"defense",
		&"F014": &"defense", &"T014": &"defense", &"P013": &"defense", &"P025": &"mechanism",
		&"F003": &"mechanism", &"F017": &"mechanism", &"A006": &"mechanism", &"A017": &"mechanism",
		&"T004": &"mechanism", &"T016": &"mechanism", &"P007": &"mechanism", &"P011": &"mechanism",
	}
	for id in roles:
		var definition := catalog.get_definition(id) as RelicDefinition
		_check(str(id) in catalog.relic_ids() and definition.choice_role == roles[id], "Expanded reward keeps its actual supply role: " + str(id))
	var selection := BuildSelection.new()
	_check(service.evaluate(selection, &"G008", WORD_CONTEXT).eligible, "Native frost ultimate is an actual shield source")
	selection.book_id = &"flame"
	_check(not service.evaluate(selection, &"G008", WORD_CONTEXT).eligible, "Shield capacity still needs an actual shield source on other books")
	selection.assets[&"R039"] = 1
	_check(service.evaluate(selection, &"G008", WORD_CONTEXT).eligible, "An existing formal shield identity supplies the capacity prerequisite")
	selection = BuildSelection.new()
	_check(service.evaluate(selection, &"G031", WORD_CONTEXT).eligible, "Ultimate shield no longer depends on a retired double-stack prerequisite")
	_check(service.evaluate(selection, &"F014", WORD_CONTEXT).eligible, "Native freezing can obtain freeze shield/resonance without retired frost pages")
	selection.book_id = &"storm"
	_check(service.evaluate(selection, &"T014", WORD_CONTEXT).eligible, "Native charging can obtain charged shield without retired charge prerequisites")
	selection.book_id = &"spirit"
	_check(service.evaluate(selection, &"P025", WORD_CONTEXT).eligible, "Paper shock creates its own shock and only requires actual spirits")
	selection.assets[&"G025"] = 1
	_check(service.evaluate(selection, &"P025", WORD_CONTEXT).eligible, "Formal shock annotation unlocks the paper shock synergy")
	selection.assets[&"P013"] = 2
	var compiled := service.compiler.compile(selection)
	_check(compiled.success() and compiled.build.modifier(&"mark_shield") == 3, "The second mark-shield layer respects its intentional three-point aggregate cap")
	for book in BuildCompiler.BOOKS:
		selection = BuildSelection.new()
		selection.book_id = book
		for seed_value in 16:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261013 + seed_value
			var offers := service.offered(selection, WORD_CONTEXT, rng)
			var offer_roles: Dictionary[StringName, bool] = {}
			var offer_ids: Dictionary[String, bool] = {}
			for id in offers:
				var definition := catalog.get_definition(StringName(id)) as RelicDefinition
				offer_roles[definition.choice_role] = true
				offer_ids[id] = true
			_check(offers.size() == 3 and offer_ids.size() == 3, "%s expanded offers keep three distinct identities" % book)
			_check(offer_roles.has(&"mechanism") and offer_roles.size() == 3, "%s expanded offers retain a mechanism and varied numerical/resource roles" % book)


func _fixture_catalog() -> BuildCatalog:
	var catalog := BuildCatalog.new()
	for id in catalog.relic_ids(true): catalog.definitions.erase(StringName(id))
	return catalog


func _relic(catalog: BuildCatalog, id: StringName, limit: int = 1) -> RelicDefinition:
	var definition := RelicDefinition.new()
	definition.id = id
	definition.max_stacks = limit
	catalog.definitions[id] = definition
	return definition


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
