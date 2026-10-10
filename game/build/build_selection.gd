class_name BuildSelection
extends RefCounted

var book_id: StringName = &"frost"
var growth_hp: int = 0
var base_hp: int = 100
var talents: PackedStringArray = []
var modes: Dictionary[StringName, StringName] = {}
var assets: Dictionary[StringName, int] = {}
var asset_instances: Dictionary[StringName, String] = {}
## Formal selections use instances exclusively. assets / asset_instances are
## a development shortcut, normalized by BuildCompiler without mutating this selection.
var instances: Array[CombatAssetInstance] = []
var temporary_rules: PackedStringArray = []
var secondary_book: StringName
var focus_shape: StringName
var calibrated_materials: PackedStringArray = []
var overrides: Array[CombatBuildOverride] = []


func copy() -> BuildSelection:
	var result := BuildSelection.new()
	result.book_id = book_id
	result.growth_hp = growth_hp
	result.base_hp = base_hp
	result.talents = talents.duplicate()
	result.modes = modes.duplicate()
	result.assets = assets.duplicate()
	result.asset_instances = asset_instances.duplicate()
	for instance in instances: result.instances.append(instance.copy() if instance != null else null)
	result.temporary_rules = temporary_rules.duplicate()
	result.secondary_book = secondary_book
	result.focus_shape = focus_shape
	result.calibrated_materials = calibrated_materials.duplicate()
	for overlay in overrides: result.overrides.append(overlay.copy())
	return result


func to_dict() -> Dictionary:
	var mode_data: Dictionary = {}
	for slot in modes: mode_data[str(slot)] = str(modes[slot])
	var asset_data: Dictionary = {}
	for content in assets: asset_data[str(content)] = assets[content]
	var asset_ids: Dictionary = {}
	for content in asset_instances: asset_ids[str(content)] = asset_instances[content]
	var instance_data: Array = []
	for instance in instances: instance_data.append(instance.to_dict())
	var override_data: Array = []
	for overlay in overrides: override_data.append(overlay.to_dict())
	return {"book_id": str(book_id), "growth_hp": growth_hp, "base_hp": base_hp, "talents": Array(talents), "modes": mode_data, "assets": asset_data, "asset_instances": asset_ids, "instances": instance_data, "temporary_rules": Array(temporary_rules), "secondary_book": str(secondary_book), "focus_shape": str(focus_shape), "calibrated_materials": Array(calibrated_materials), "overrides": override_data}


static func from_dict(data: Dictionary) -> BuildSelection:
	var growth: Variant = data.get("growth_hp", 0)
	if (not growth is int and not growth is float) or not is_finite(float(growth)) or float(growth) != floor(float(growth)) or growth < 0 or growth > 20:
		push_error("成长生命需要0…20的整数。")
		return null
	var base_health: Variant = data.get("base_hp", 100)
	if (not base_health is int and not base_health is float) or not is_finite(float(base_health)) or float(base_health) != floor(float(base_health)) or base_health < 1 or base_health > 200:
		push_error("基础生命需要1…200的整数。")
		return null
	for field in ["book_id", "secondary_book", "focus_shape"]:
		if not data.get(field) is String:
			push_error("配置快照字段需要字符串：" + field)
			return null
	for field in ["talents", "temporary_rules", "calibrated_materials"]:
		if not data.get(field) is Array:
			push_error("配置快照字段需要数组：" + field)
			return null
		for value in data[field]:
			if not value is String:
				push_error("配置快照列表需要字符串：" + field)
				return null
	for field in ["modes", "asset_instances", "assets"]:
		if not data.get(field) is Dictionary:
			push_error("配置快照字段需要字典：" + field)
			return null
		for key in data[field]:
			var value: Variant = data[field][key]
			if not key is String or (field != "assets" and not value is String):
				push_error("配置快照字典需要字符串身份：" + field)
				return null
			if field == "assets" and ((not value is int and not value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or value < 1 or value > 1 << 30):
				push_error("配置快照开发层数需要正整数。")
				return null
	for field in ["instances", "overrides"]:
		if not data.get(field) is Array:
			push_error("配置快照字段需要数组：" + field)
			return null
		for value in data[field]:
			if not value is Dictionary:
				push_error("配置快照对象需要字典：" + field)
				return null
	var result := BuildSelection.new()
	result.book_id = StringName(data.book_id)
	result.growth_hp = int(growth)
	result.base_hp = int(base_health)
	result.talents = PackedStringArray(data.talents)
	result.temporary_rules = PackedStringArray(data.temporary_rules)
	result.secondary_book = StringName(data.secondary_book)
	result.focus_shape = StringName(data.focus_shape)
	result.calibrated_materials = PackedStringArray(data.calibrated_materials)
	for slot in data.modes: result.modes[StringName(slot)] = StringName(data.modes[slot])
	for content in data.assets: result.assets[StringName(content)] = int(data.assets[content])
	for content in data.asset_instances: result.asset_instances[StringName(content)] = data.asset_instances[content]
	for value in data.instances:
		var instance := CombatAssetInstance.from_dict(value)
		if instance == null: return null
		result.instances.append(instance)
	for value in data.overrides:
		var overlay := CombatBuildOverride.from_dict(value)
		if overlay == null: return null
		result.overrides.append(overlay)
	return result
