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
const WORD_CONTEXT := {"shortest": 3, "longest": 8}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	_test_qualification()
	_test_capability_topology()
	_test_modifiers()
	_test_offers()
	print("RELIC_CATALOG: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_catalog() -> void:
	var catalog := BuildCatalog.new()
	var ids := catalog.relic_ids()
	var sorted := ids.duplicate()
	sorted.sort()
	_check(ids == sorted, "Relic directory has stable ID ordering")
	for index in range(1, 59):
		_check("R%03d" % index in ids, "Baseline ID survives: R%03d" % index)
	reach_compiler = BuildCompiler.new(catalog)
	reach_service = AcquisitionService.new(reach_compiler)
	for book in BuildCompiler.BOOKS:
		var capacity := 0
		for id in ids:
			var definition := catalog.get_definition(StringName(id)) as RelicDefinition
			if not definition.allowed_books.is_empty() and str(book) not in definition.allowed_books: continue
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
			_check(capacity > 100, "%s has over 100 actually reachable relic definitions (%d)" % [book, capacity])
		var selection := BuildSelection.new()
		selection.book_id = book
		var pool := AcquisitionService.new(BuildCompiler.new(catalog)).candidates(selection, WORD_CONTEXT)
		_check(not pool.is_empty(), "%s begins with reachable rewards" % book)
		for id in pool:
			_check(id in ids, "Reward is present in the same directory: " + id)
	var second := BuildCatalog.new()
	catalog.definitions.erase(&"R001")
	_check(second.get_definition(&"R001") != null, "Catalog dictionaries do not expose the shared loading cache")


## Search only obtains relics through the public qualification API. Each target
## begins from an empty build; capability providers and exclusive branches are
## alternatives with backtracking, never preinstalled authorization fixtures.
func _follow_acquisition_plan(selection: BuildSelection, plan: Array[Dictionary]) -> BuildSelection:
	if plan.is_empty(): return selection
	var task: Dictionary = plan[0]
	var tail := plan.duplicate()
	tail.pop_front()
	if task.kind == "acquire":
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
		for id in reach_compiler.catalog.relic_ids():
			var source := reach_compiler.catalog.get_definition(StringName(id)) as RelicDefinition
			if str(task.capability) not in source.grants_capabilities: continue
			var branch: Array[Dictionary] = [{"kind": "relic", "id": source.id, "wanted": 1, "ancestors": task.ancestors}]
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
	for capability in definition.requires_capabilities:
		prerequisites.append({"kind": "capability", "capability": capability, "ancestors": ancestors})
	prerequisites.append({"kind": "acquire", "id": id, "wanted": task.wanted})
	prerequisites.append_array(tail)
	return _follow_acquisition_plan(selection, prerequisites)


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


func _fixture_catalog() -> BuildCatalog:
	var catalog := BuildCatalog.new()
	for id in catalog.relic_ids(): catalog.definitions.erase(StringName(id))
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
