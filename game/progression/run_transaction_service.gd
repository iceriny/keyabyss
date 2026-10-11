class_name RunTransactionService
extends RefCounted
## Pure preflight. RunSession saves and publishes this result as one transaction.

const Q := 1024
var compiler: BuildCompiler
var acquisition: AcquisitionService
var assets: CombatAssetService


func _init(build_compiler: BuildCompiler = null) -> void:
	compiler = build_compiler if build_compiler != null else BuildCompiler.new()
	acquisition = AcquisitionService.new(compiler)
	assets = CombatAssetService.new(compiler)


func prepare_acquisition(selection: BuildSelection, state: RunCombatState, content_id: StringName, instance_id: String, parent_instance_id: String = "", context: Dictionary = {}) -> Dictionary:
	var definition := compiler.catalog.get_definition(content_id) as RelicDefinition
	if definition == null:
		return _failure(PackedStringArray(["INVALID_ACQUISITION_CONTENT"]))
	var request := CombatAssetRequest.new()
	request.content_id = content_id
	request.instance_id = instance_id
	request.source_id = StringName(context.get("source_id", "reward"))
	request.expiry_scope = StringName(context.get("expiry_scope", "run"))
	request.expiry_index = int(context.get("expiry_index", -1))
	if not parent_instance_id.is_empty():
		return _failure(PackedStringArray(["UNEXPECTED_EVOLUTION_PARENT"]))
	request.action = CombatAssetRequest.Action.ADD
	var requests: Array[CombatAssetRequest] = [request]
	return prepare_actions(selection, state, requests, context)


func prepare_actions(selection: BuildSelection, state: RunCombatState, requests: Array[CombatAssetRequest], context: Dictionary = {}) -> Dictionary:
	if selection == null or state == null or requests.is_empty():
		return _failure(PackedStringArray(["INVALID_RUN_TRANSACTION"]))
	for request in requests:
		if request == null:
			return _failure(PackedStringArray(["INVALID_ASSET_REQUEST"]))
		if request.action == CombatAssetRequest.Action.ADD:
			var definition := compiler.catalog.get_definition(request.content_id) as RelicDefinition
			if definition == null:
				return _failure(PackedStringArray(["INVALID_ACQUISITION_CONTENT"]))
	# Apply every asset action to one candidate and compile the final set once.
	var prepared := assets.prepare_batch(selection, requests)
	if not prepared.diagnostics.is_empty(): return _failure(prepared.diagnostics)
	var proposed: BuildSelection = prepared.selection
	var build: CompiledBuild = prepared.command.build
	var acquired: Dictionary[String, bool] = {}
	for request in requests:
		if request.action != CombatAssetRequest.Action.ADD: continue
		var candidate_index := _find_instance(proposed.instances, request.instance_id)
		if candidate_index < 0 or proposed.instances[candidate_index].content_id != request.content_id:
			return _failure(PackedStringArray(["ACQUISITION_MISSING_FROM_FINAL_ASSETS"]))
		var qualification := proposed.copy()
		qualification.instances.remove_at(candidate_index)
		var acquisition_context := context.duplicate(true)
		var eligibility := acquisition.evaluate(qualification, request.content_id, acquisition_context)
		if not eligibility.eligible: return _failure(eligibility.diagnostics)
		acquired[request.instance_id] = true
	var data := RunStateCodec.encode(state)
	if data.is_empty(): return _failure(PackedStringArray(["INVALID_RUN_COMBAT_STATE"]))
	var candidate_state := RunStateCodec.decode(data)
	if candidate_state == null: return _failure(PackedStringArray(["INVALID_RUN_COMBAT_STATE"]))
	var maximum_hp := build.maximum_hp_q()
	candidate_state.hp_q = mini(candidate_state.hp_q, maximum_hp)
	var dodge_delta := 0
	for instance in proposed.instances:
		if not acquired.has(instance.instance_id): continue
		if instance.content_id == &"R012" and candidate_state.claim_asset(instance.usage_key(), &"heal"):
			candidate_state.hp_q = mini(maximum_hp, candidate_state.hp_q + roundi(build.relic_number(&"R012", &"heal") * Q))
		if instance.content_id == &"R009" and candidate_state.claim_asset(instance.usage_key(), &"dodge-charge"):
			dodge_delta += 1
		if instance.content_id == &"R042" and candidate_state.claim_asset("room:%d" % state.room_serial, &"price"):
			candidate_state.hp_q = maxi(Q, candidate_state.hp_q - roundi(build.relic_number(&"R042", &"cost") * Q))
	return {"selection": proposed, "state": candidate_state, "build": build, "dodge_delta": dodge_delta, "diagnostics": PackedStringArray()}


func _find_instance(instances: Array[CombatAssetInstance], id: String) -> int:
	for index in instances.size():
		if instances[index].instance_id == id: return index
	return -1


func _failure(diagnostics: PackedStringArray) -> Dictionary:
	return {"selection": null, "state": null, "build": null, "dodge_delta": 0, "diagnostics": diagnostics}
