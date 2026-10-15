class_name BuildCatalog
extends RefCounted

## Retired definitions remain loaded for saved assets and already-issued offers.
const ACTIVE_RELIC_IDS: PackedStringArray = [
	"R001", "R002", "R003", "R004", "R005", "R006", "R007", "R008", "R009", "R010", "R011", "R012", "R013", "R014", "R015", "R016", "R017",
	"R019", "R020", "R021", "R022", "R024", "R025", "R026", "R027", "R028", "R029", "R030", "R031", "R032", "R033", "R034", "R035", "R036", "R037", "R038", "R039", "R040", "R041", "R042", "R043", "R044", "R045", "R046", "R047", "R048", "R049", "R050", "R051", "R052", "R054", "R056", "R057", "R058",
	"G006", "G013", "G016", "G024", "G025", "G026", "G027", "F006", "F009", "A004", "A009", "T003", "T009", "P004", "P010",
	"G008", "G020", "F001", "F021", "A007", "A008", "A011", "T007", "T008", "P008", "P009", "P012",
	"G017", "G021", "G023", "G031", "F014", "T014", "P013", "P025",
	"F003", "F017", "A006", "A017", "T004", "T016", "P007", "P011",
]

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


func relic_ids(include_retired: bool = false) -> PackedStringArray:
	var ids: PackedStringArray = []
	for id in ordered_ids():
		var definition := definitions[StringName(id)] as RelicDefinition
		if definition == null: continue
		# In-memory catalogs can supply their own resources without adopting the
		# official directory's retirement policy.
		if not include_retired and definition.resource_path.begins_with("res://game/content/") and id not in ACTIVE_RELIC_IDS: continue
		ids.append(id)
	return ids
