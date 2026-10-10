class_name BuildCatalog
extends RefCounted

var definitions: Dictionary[StringName, CombatContentDefinition] = {}


func _init() -> void:
	var ids: PackedStringArray = ["frost", "flame", "storm", "spirit"]
	for index in range(1, 59): ids.append("R%03d" % index)
	for id in ids:
		var definition := load("res://game/content/build/" + id + ".tres") as CombatContentDefinition
		assert(definition != null and definition.id == StringName(id))
		definitions[definition.id] = definition


func get_definition(id: StringName) -> CombatContentDefinition:
	return definitions.get(id)


func ordered_ids() -> PackedStringArray:
	var ids := PackedStringArray(definitions.keys())
	ids.sort()
	return ids
