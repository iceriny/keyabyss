extends SceneTree
## Registration, compilation, lifecycle and candidate-specific behavior are separate evidence.
## Missing scenarios remain not_verified even when every structural check passes.

const Q := 1024
const WORD := "abcdefghijkl"
var compiler := BuildCompiler.new()
var checks := 0
var failures := 0
var evidence: Array[Dictionary] = []
var dependency_reasons: Array = []

# Providers are the base operations in their Resource definitions, not inferred ID ranges.
const PROVIDERS := {"vault": "T01", "conduct": "T13", "copy": "T19", "guard": "T21", "transport": "T25", "letters": "T31", "cold": "T50", "dot": "T49", "summon": "T52", "miss-recover": "T12", "focus": "T58", "graze": "T39", "relay": "T14", "cold-field": "T46", "heal": "T53"}
# Each group names the runtime gate/object that must exist, with its source function.
const DEPENDENCIES := [
	{"operations": ["copy-concentrate", "copy-split", "inherit", "base-copy"], "needs": ["copy"], "source": "SpellRuntime._make_copy / assemble(copy direction)"},
	{"operations": ["guard", "echo", "fracture", "insulate", "thin-shell", "heat-open", "heat-hold", "heat-fracture", "anneal", "heat-transfer", "short-storage", "late-shape", "merge", "reserved-slot", "continuation-slot", "stagger-release", "reseal", "shell-recover"], "needs": ["vault"], "source": "SpellRuntime._store_portion / _store / _close_shell / _heat_contact"},
	{"operations": ["guard-spacing", "joint-guard", "oldest", "newest", "closest-guard", "low-health-guard"], "needs": ["guard"], "source": "SpellRuntime.guard"},
	{"operations": ["heat-open", "heat-hold", "heat-fracture", "anneal", "heat-transfer"], "needs": ["heat"], "source": "SpellRuntime._heat_contact requires effect.heat"},
	{"operations": ["transport"], "needs": ["summon", "vault"], "source": "SpellRuntime.pickup requires spirit.effect and a stored candidate"},
	{"operations": ["return", "cargo-relay"], "needs": ["transport"], "source": "SpellRuntime.return_cargo / _arc_route(transporting shell)"},
	{"operations": ["cargo-relay"], "needs": ["relay"], "source": "SpellRuntime._arc_route only visits cargo within relay branch"},
	{"operations": ["relay"], "needs": ["conduct", "vault"], "source": "SpellRuntime._continue_arc / _arc_route(shell nodes)"},
	{"operations": ["long-hop", "near-hop", "delayed-chain", "charge-mark", "charge-recover"], "needs": ["conduct"], "source": "SpellRuntime._continue_arc / contact / retire require charge"},
	{"operations": ["advance-dot", "extract", "dot-recover", "dot-transfer", "dot-selective-recover", "dot-shell"], "needs": ["dot"], "source": "SpellRuntime.contact / _extract_previous / _death / finish require ongoing"},
	{"operations": ["delay-dot"], "needs": ["dot", "cold"], "source": "SpellRuntime.contact requires ongoing and paid cold"},
	{"operations": ["cold-field", "local-slow", "brittle", "avalanche"], "needs": ["cold"], "source": "SpellRuntime._apply_paid_modifiers / observe_input require cold or frozen target"},
	{"operations": ["heat-field"], "needs": ["dot"], "source": "SpellRuntime._start_ongoing: dot supplies a field without adding unrelated heat"},
	{"operations": ["field-recover", "field-split"], "needs": ["cold-field"], "source": "SpellRuntime._field / advance require a finite field"},
	{"operations": ["field-relay"], "needs": ["conduct", "cold-field"], "source": "SpellRuntime._arc_route(field nodes) / _continue_arc"},
	{"operations": ["spirit-guard"], "needs": ["summon"], "source": "SpellRuntime.guard requires spirit_attacks"},
	{"operations": ["mark-store", "mark-spread", "letter-fixed", "letter-heavy", "letter-inherit"], "needs": ["letters"], "source": "SpellRuntime._distribute_letters / observe_input / assemble require redeemed letter marks"},
	{"operations": ["mastery"], "needs": ["focus"], "source": "SpellRuntime.assemble compares build.mode(shape)"},
	{"operations": ["graze-shield"], "needs": ["graze"], "source": "SpellRuntime.graze early capability gate"},
	{"operations": ["reserve", "meter", "short-word", "burst-reserve", "charge-priority", "archive", "clear-heal"], "needs": ["miss-recover"], "source": "SpellRuntime._apply_reserve / finish require reclaimed reserve lots"},
	{"operations": ["shared-work"], "needs": ["conduct", "cold"], "source": "SpellRuntime._continue_arc requires charge plus cold to discount its fee"},
]
# Numerical rules still need the object whose parameter they adjust. Parameters used
# directly by BattleSession (life, dodge, flight, resonance, armor, ultimate) add no talent.
const PARAMETER_DEPENDENCIES := [
	{"parameters": ["storage_retention_q", "storage_slots", "storage_wait_ms", "storage_lifetime_ms", "shell_space"], "needs": ["vault"], "source": "SpellRuntime._store_portion / _store"},
	{"parameters": ["heat_absorption_q", "heat_capacity_q", "heat_threshold_q"], "needs": ["vault", "heat"], "source": "SpellRuntime._heat_contact requires a stored shell and incoming heat"},
	{"parameters": ["heat_efficiency_q"], "needs": ["heat"], "source": "SpellRuntime.assemble(heat direction)"},
	{"parameters": ["heal_efficiency_q"], "needs": ["heal"], "source": "SpellRuntime.assemble(heal direction)"},
	{"parameters": ["guard_efficiency_q", "shell_durability_q"], "needs": ["guard"], "source": "SpellRuntime.guard"},
	{"parameters": ["copy_retention_q"], "needs": ["copy"], "source": "SpellRuntime._make_copy"},
	{"parameters": ["charge_efficiency_q", "chain_targets", "chain_retention_q", "hop_range_q"], "needs": ["conduct"], "source": "SpellRuntime.assemble / _continue_arc"},
	{"parameters": ["dot_pulses", "dot_duration_ms", "dot_retention_q"], "needs": ["dot"], "source": "SpellRuntime._start_ongoing / contact"},
	{"parameters": ["field_lifetime_ms", "field_radius_q"], "needs": ["cold-field"], "source": "SpellRuntime._field"},
	{"parameters": ["letter_positions", "letter_retention_q", "letter_store_q"], "needs": ["letters"], "source": "SpellRuntime._distribute_letters / observe_input / assemble"},
	{"parameters": ["summon_capacity", "summon_efficiency_q"], "needs": ["summon"], "source": "BattleSession._summon_spirit / SpellRuntime._fund_spirit"},
	{"parameters": ["transport_retention_q", "return_wait_ms"], "needs": ["transport"], "source": "SpellRuntime.pickup / return_cargo"},
	{"parameters": ["recovery_q", "reserve_capacity_q", "reserve_cast_cap_q", "archive_retention_q", "burst_cap_q", "burst_ratio_q"], "needs": ["miss-recover"], "source": "SpellRuntime._recover / _apply_reserve / finish"},
]


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func require_talent(id: String, selection: BuildSelection) -> void:
	if id in selection.talents: return
	selection.talents.append(id)
	var definition := compiler.catalog.get_definition(StringName(id))
	for required in definition.requires_all: require_talent(required, selection)
	if not definition.requires_any.is_empty(): require_talent(definition.requires_any[0], selection)
	_add_runtime_dependencies(definition, selection, dependency_reasons)


func _has_operation(selection: BuildSelection, operation: String) -> bool:
	var ids := selection.talents.duplicate()
	ids.append(str(selection.book_id))
	for id in selection.assets: ids.append(str(id))
	for id in ids:
		for rule in compiler.catalog.get_definition(StringName(id)).rules:
			if str(rule.operation) == operation: return true
	return operation == "heat" and (selection.book_id == &"flame" or selection.secondary_book == &"flame")


func _add_runtime_dependencies(definition: CombatContentDefinition, selection: BuildSelection, reasons: Array) -> void:
	for rule in definition.rules:
		for group in DEPENDENCIES + PARAMETER_DEPENDENCIES:
			var relevant: bool = str(rule.operation) in group.get("operations", [])
			for parameter in rule.parameters:
				relevant = relevant or str(parameter) in group.get("parameters", [])
			if not relevant: continue
			for operation: String in group.needs:
				if _has_operation(selection, operation): continue
				# Accept an already selected alternative producer; do not configure a
				# second storage/field/material path just to make the test richer.
				if operation == "vault" and _has_operation(selection, "copy"): continue
				if operation == "cold-field" and (_has_operation(selection, "heat-field") or _has_operation(selection, "trail")): continue
				if operation == "dot" and str(rule.operation) == "heat-field" and _has_operation(selection, "heat"): continue
				# A flame secondary supplies heat through the compiler's T57 contract.
				if operation == "heat":
					require_talent("T57", selection)
					selection.secondary_book = &"flame"
				else:
					var provider: String = PROVIDERS[operation]
					require_talent(provider, selection)
				reasons.append({"operation": operation, "source": group.source})


func _needs_heat(definition: CombatContentDefinition, visited: PackedStringArray = []) -> bool:
	if str(definition.id) in visited: return false
	visited.append(str(definition.id))
	for rule in definition.rules:
		for group in DEPENDENCIES + PARAMETER_DEPENDENCIES:
			if "heat" not in group.needs: continue
			if str(rule.operation) in group.get("operations", []): return true
			for parameter in rule.parameters:
				if str(parameter) in group.get("parameters", []): return true
	var required := definition.requires_all + definition.permits
	if not definition.requires_any.is_empty(): required.append(definition.requires_any[0])
	for id in required:
		if _needs_heat(compiler.catalog.get_definition(StringName(id)), visited): return true
	return false


func _run() -> void:
	for id in compiler.catalog.ordered_ids():
		dependency_reasons = []
		var definition := compiler.catalog.get_definition(StringName(id))
		var selection := BuildSelection.new()
		selection.book_id = StringName(id) if definition is BookDefinition else (&"frost" if definition.allowed_books.is_empty() else StringName(definition.allowed_books[0]))
		if not definition is BookDefinition and definition.allowed_books.is_empty() and _needs_heat(definition): selection.book_id = &"flame"
		if definition is TalentDefinition: require_talent(id, selection)
		elif definition is RelicDefinition:
			selection.assets[StringName(id)] = 1
			for permit in definition.permits: require_talent(permit, selection)
		_add_runtime_dependencies(definition, selection, dependency_reasons)
		if "T57" in selection.talents and selection.secondary_book == &"": selection.secondary_book = &"flame" if selection.book_id != &"flame" else &"frost"
		if "T58" in selection.talents: selection.focus_shape = BuildCompiler.SHAPES[selection.book_id][0]
		var compiled := compiler.compile(selection)
		check(compiled.success(), "%s compiles with explicit native dependencies: %s" % [id, compiled.diagnostics])
		var item := {"id": id, "resource": "res://game/content/build/%s.tres" % id, "stage": definition.stage, "selection": {"book": selection.book_id, "talents": Array(selection.talents), "assets": selection.assets, "secondary": selection.secondary_book, "shape": selection.focus_shape}, "dependency_reasons": dependency_reasons, "compilation": {"status": "verified" if compiled.success() else "failed", "diagnostics": Array(compiled.diagnostics)}, "rules": [], "behavior": {"status": "not_verified", "reason": "No complete candidate-specific scenario for all rules and parameters."}}
		evidence.append(item)
		if not compiled.success():
			for rule in definition.rules:
				item.rules.append({"operation": rule.operation, "registration": "verified" if CombatRuleContract.diagnose(rule).is_empty() else "failed", "behavior": {"status": "not_verified", "reason": "Candidate compilation failed; no lifecycle or effect scenario ran."}})
			continue
		item["snapshot"] = compiled.build.identity()
		var baseline := BuildSelection.new()
		baseline.book_id = selection.book_id
		baseline.talents = selection.talents.duplicate()
		if id in baseline.talents: baseline.talents.remove_at(baseline.talents.find(id))
		baseline.assets = selection.assets.duplicate()
		baseline.assets.erase(StringName(id))
		baseline.secondary_book = selection.secondary_book if "T57" in baseline.talents else &""
		baseline.focus_shape = selection.focus_shape if "T58" in baseline.talents else &""
		var control := compiler.compile(baseline)
		item["control_compilation"] = {"status": "verified" if control.success() else "not_verified", "diagnostics": Array(control.diagnostics)}
		var candidate := _probe(compiled.build, id)
		var before: Dictionary = _probe(control.build, id + ":control") if control.success() and not definition is BookDefinition else {}
		item["lifecycle"] = candidate
		for rule in definition.rules:
			check(id in compiled.build.sources(rule.operation), "%s retains its provenance in the operation index" % id)
			var parameters: Array = []
			for parameter in rule.parameters:
				var delta: int = compiled.build.value(parameter) - control.build.value(parameter) if control.success() else 0
				var parameter_ok: bool = control.success() and delta == rule.parameters[parameter]
				if control.success(): check(parameter_ok, "%s compiles parameter %s with its exact candidate delta" % [id, parameter])
				var parameter_evidence := {"parameter": parameter, "delta": delta, "expected": rule.parameters[parameter], "status": "verified" if parameter_ok else "not_verified", "scope": "compile_value_only", "behavior": {"status": "not_verified", "reason": "No parameter-specific runtime observation."}}
				if parameter == &"max_hp_bonus_q" and not before.is_empty():
					parameter_evidence.behavior = {"status": "verified" if candidate.observations.max_hp_q - before.observations.max_hp_q == 100 * delta else "not_verified", "scope": "runtime_value_only", "before": before.observations.max_hp_q, "after": candidate.observations.max_hp_q}
				parameters.append(parameter_evidence)
			item.rules.append({"operation": rule.operation, "registration": "verified" if id in compiled.build.sources(rule.operation) else "failed", "parameters": parameters, "behavior": _behavior(rule, candidate, before)})
		if evidence.size() % 40 == 0:
			print("M3 catalog: %d / 377" % evidence.size())
			await process_frame
	await process_frame
	var directory := "res://.temp/godot-m3"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open(directory.path_join("content-evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": CompiledBuild.PARAMETER_VERSION, "checks":checks, "failures":failures, "scope": "Structural checks may pass while candidate behavior remains not_verified. No aggregate damage proves any rule.", "content":evidence}, "\t"))
	file.close()
	print("M3 catalog: %d definitions, %d checks, %d failures" % [evidence.size(), checks, failures])
	quit(0 if failures == 0 else 1)


func _probe(build: CompiledBuild, label: String) -> Dictionary:
	var request := BattleStartRequest.new()
	request.build = build
	request.vocabulary = [VocabularyEntry.new(WORD, "来源检查")]
	request.encounter = BattleEncounter.new()
	request.encounter.wave_count = 1
	var session := BattleSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.start(request)
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.position = Vector2(0.65 + index * 0.07, 0.45 + index * 0.07)
		enemy.previous_position = enemy.position
		enemy.combat_locked = true
		enemy.hp_q = 10000 * Q
		enemy.max_hp_q = enemy.hp_q
		enemy.attack_clock = 100.0
	session.player_hp_q = 30 * Q
	var observations := {"max_hp_q": session.player_max_hp_q, "stored_peak": 0, "stored_power_peak_q": 0, "single_page_power_peak_q": 0, "storage_units_peak": 0, "input_shield_q": 0, "input_slow_time": 0.0, "heal_q": 0, "guard_blocked_q": 0}
	for cast in 3:
		var target := session.enemies[cast]
		session.typing.upsert_target(target.id, WORD)
		session.typing.select_target(target.id)
		for character in WORD: session.typing.feed(character)
		observations.input_shield_q = session.run_state.shield_q
		observations.input_slow_time = maxf(observations.input_slow_time, target.local_slow_time)
		# Completion is queued by TypingSession; the fixed step commits assembly.
		session.step(1.0 / 60)
		var power := 0
		var units := 0
		for shell in session.runtime.stored:
			power += shell.effect.lot.amount_q
			units += shell.space_units
			observations.single_page_power_peak_q = maxi(observations.single_page_power_peak_q, shell.effect.lot.amount_q)
		observations.stored_peak = maxi(observations.stored_peak, session.runtime.stored.size())
		observations.stored_power_peak_q = maxi(observations.stored_power_peak_q, power)
		observations.storage_units_peak = maxi(observations.storage_units_peak, units)
		observations.heal_q = session.player_hp_q - 30 * Q
		# Paid guard observation is separate from a primary-damage smoke observation.
		observations.guard_blocked_q += Q - session.runtime.guard("catalog:%s:%s" % [label, cast], Q, session.player_position)
		for tick in 35: session.step(1.0 / 60)
	for tick in 180: session.step(1.0 / 60)
	check(session.manual_characters == 36 and session.completed_words == 3, "%s executes the formal manual input lifecycle" % label)
	var transactions: PackedStringArray = []
	for transaction: String in session.ledger._transactions:
		var operation := transaction.get_slice(":", 1)
		if operation not in transactions: transactions.append(operation)
	var result := session.finish_room(&"abandon")
	var closed := session.ledger.active_lots().is_empty()
	check(closed, "%s closes its room without stranded ownership" % label)
	session.queue_free()
	return {"status": "verified" if closed and result.manual_characters == 36 else "failed", "scenario": "three manual long words, durable targets with normal motion, delayed attacks, explicit guard, abandon; no real encounter value claimed", "manual": result.manual_characters, "primary_damage_observed_q": result.actual_damage_q, "transactions": Array(transactions), "observations": observations}


func _behavior(rule: RuleDefinition, candidate: Dictionary, control: Dictionary) -> Dictionary:
	if control.is_empty(): return {"status": "not_verified", "reason": "No comparable build with the candidate removed (book or compiler contract)."}
	# These are narrow causal state observations. They do not claim all secondary
	# parameters, costs, triggers, or description clauses of the rule were validated.
	var metric: String = {"vault": "stored_peak", "copy": "stored_peak", "heal": "heal_q", "guard": "guard_blocked_q", "input-shield": "input_shield_q", "input-slow": "input_slow_time", "local-slow": "input_slow_time"}.get(str(rule.operation), "")
	if metric.is_empty(): return {"status": "not_verified", "reason": "Needs a mechanism-specific trigger, resource payment and object/state comparison; catalog lifecycle does not establish these.", "candidate_observations": candidate.observations, "control_observations": control.observations}
	var after: Variant = candidate.observations[metric]
	var before: Variant = control.observations[metric]
	return {"status": "verified" if after > before else "not_verified", "scope": "entry_state_only", "metric": metric, "before": before, "after": after, "reason": "Candidate changes the named state; complete rule semantics remain unverified." if after > before else "This minimal scenario did not observe the expected state increase; gate, budget or missing effect requires a dedicated scenario."}
