class_name BuildCatalog
extends RefCounted

var definitions: Dictionary[StringName, CombatContentDefinition] = {}
static var _loaded: Dictionary[StringName, CombatContentDefinition] = {}


func _init() -> void:
	if not _loaded.is_empty():
		definitions = _loaded.duplicate()
		return
	var ids: PackedStringArray = ["frost", "flame", "storm", "spirit"]
	for index in range(1, 59): ids.append("R%03d" % index)
	for id in ids:
		var definition := load("res://game/content/build/" + id + ".tres") as CombatContentDefinition
		assert(definition != null and definition.id == StringName(id))
		definitions[definition.id] = definition
	_load_relic_directory("res://game/content/relics/")
	_loaded = definitions.duplicate()


func _load_relic_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var entries := ResourceLoader.list_directory(path)
	entries.sort()
	for entry in entries:
		if entry.ends_with("/"):
			_load_relic_directory(path + entry)
		elif entry.ends_with(".tres"):
			var definition := load(path + entry) as RelicDefinition
			assert(definition != null and definition.id != &"" and not definitions.has(definition.id), "Invalid or duplicate relic: " + path + entry)
			definitions[definition.id] = definition


func get_definition(id: StringName) -> CombatContentDefinition:
	return definitions.get(id)


func ordered_ids() -> PackedStringArray:
	var ids := PackedStringArray(definitions.keys())
	ids.sort()
	return ids


func relic_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for id in ordered_ids():
		if definitions[StringName(id)] is RelicDefinition: ids.append(id)
	return ids
