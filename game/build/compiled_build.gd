class_name CompiledBuild
extends RefCounted
## Installed snapshots are private. Readers receive values or copies.

## Included in the compiled identity; this is not a save schema version.
const PARAMETER_VERSION := "relics-3"
var _id: String
var _book: StringName
var _rules: Dictionary[StringName, bool] = {}
var _values: Dictionary[StringName, int] = {}
var _modifiers: Dictionary[StringName, int] = {}
var _relic_numbers: Dictionary[StringName, Dictionary] = {}
var _capabilities: PackedStringArray = []
var _modes: Dictionary[StringName, StringName] = {}
var _mode_operations: Dictionary[StringName, StringName] = {}
var _sources: Dictionary[StringName, PackedStringArray] = {}
var _permits: PackedStringArray = []
var _assets: Dictionary[StringName, int] = {}
var _asset_stacks: Dictionary[StringName, int] = {}
var _instances: Array[CombatAssetInstance] = []


func identity() -> String:
	return _id


func book() -> StringName:
	return _book


func has(operation: StringName) -> bool:
	return _rules.has(operation)


func value(parameter: StringName, fallback: int = 0) -> int:
	return _values.get(parameter, fallback)


func modifier(key: StringName) -> int:
	return _modifiers.get(key, 0)


func relic_number(id: StringName, key: StringName) -> float:
	return _relic_numbers.get(id, {}).get(key, 0.0)


func capabilities() -> PackedStringArray:
	return _capabilities.duplicate()


func maximum_hp_q() -> int:
	@warning_ignore("integer_division")
	return value(&"base_hp_q", 100 * 1024) * (1024 + value(&"max_hp_bonus_q")) / 1024 + value(&"max_hp_flat_q") + modifier(&"max_hp_flat") * 1024


func mode(slot: StringName) -> StringName:
	return _modes.get(slot, &"")


func mode_operation(slot: StringName) -> StringName:
	return _mode_operations.get(slot, &"")


func sources(operation: StringName) -> PackedStringArray:
	return _sources.get(operation, PackedStringArray()).duplicate()


func assets() -> Dictionary[StringName, int]:
	# Content presence view only; use asset_instances() for consumption receipts.
	return _assets.duplicate()


func asset_instances() -> Array[CombatAssetInstance]:
	var copies: Array[CombatAssetInstance] = []
	for instance in _instances:
		copies.append(instance.copy())
	return copies


func asset_stacks(id: StringName) -> int:
	return _asset_stacks.get(id, 0)


func permits() -> PackedStringArray:
	return _permits.duplicate()
