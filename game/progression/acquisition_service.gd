class_name AcquisitionService
extends RefCounted
const ACTIVE_RELICS = BuildCompiler.RESTORED_RELICS

var compiler: BuildCompiler


func _init(build_compiler: BuildCompiler = null) -> void:
	compiler = build_compiler if build_compiler != null else BuildCompiler.new()


func evaluate(selection: BuildSelection, content_id: StringName, context: Dictionary = {}) -> Dictionary:
	var definition := compiler.catalog.get_definition(content_id) as RelicDefinition
	var diagnostics: PackedStringArray = []
	if selection == null or definition == null or content_id not in BuildCompiler.RESTORED_RELICS:
		return _result(definition, PackedStringArray(["CONTENT_NOT_RESTORED"]))
	var active := compiler.compile(selection)
	if not active.success(): return _result(definition, active.diagnostics)
	if active.build.asset_stacks(content_id) >= definition.max_stacks:
		diagnostics.append("MAX_STACKS:" + str(content_id))
	if not definition.allowed_books.is_empty() and str(selection.book_id) not in definition.allowed_books:
		diagnostics.append("WRONG_MAIN_BOOK:" + str(content_id))
	for required in definition.requires_all:
		if active.build.asset_stacks(StringName(required)) == 0:
			diagnostics.append("MISSING_RELIC:" + required)
	if content_id == &"R017" and int(context.get("longest", 0)) < 3:
		diagnostics.append("VOCABULARY_NEEDS_ASSISTABLE_WORD")
	if content_id == &"R014" and (int(context.get("shortest", 0)) < 1 or int(context.get("shortest", 0)) > 4):
		diagnostics.append("VOCABULARY_NEEDS_SHORT_WORD")
	if content_id == &"R015" and int(context.get("longest", 0)) < 7:
		diagnostics.append("VOCABULARY_NEEDS_LONG_WORD")
	return _result(definition, diagnostics)

func candidates(selection: BuildSelection, context: Dictionary = {}) -> PackedStringArray:
	var ids: PackedStringArray = []
	for id in compiler.catalog.ordered_ids():
		if compiler.catalog.get_definition(StringName(id)) is RelicDefinition and evaluate(selection, StringName(id), context).eligible:
			ids.append(id)
	return ids




func _result(definition: RelicDefinition, diagnostics: PackedStringArray) -> Dictionary:
	return {"eligible": diagnostics.is_empty(), "diagnostics": diagnostics, "definition": definition}
