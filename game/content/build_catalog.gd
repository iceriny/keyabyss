class_name BuildCatalog
extends RefCounted

var definitions: Dictionary[StringName, CombatContentDefinition] = {}


func _init() -> void:
	var directory := DirAccess.open("res://game/content/build")
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.ends_with(".tres"):
			var definition := load("res://game/content/build/" + filename) as CombatContentDefinition
			assert(definition != null and not definitions.has(definition.id))
			definitions[definition.id] = definition


func get_definition(id: StringName) -> CombatContentDefinition:
	return definitions.get(id)


func ordered_ids() -> PackedStringArray:
	var ids := PackedStringArray(definitions.keys())
	ids.sort()
	return ids
