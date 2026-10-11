class_name RelicDefinition
extends CombatContentDefinition

@export var opportunity_cost: int = 1
@export var rarity: StringName = &"common"
@export var tags: PackedStringArray = []
@export var preferred_books: PackedStringArray = []
@export var requires_capabilities: PackedStringArray = []
@export var grants_capabilities: PackedStringArray = []
@export var required_stacks: Dictionary[StringName, int] = {}
@export var exclusive_group: StringName
@export var modifiers: Dictionary[StringName, int] = {}
@export var numbers: Dictionary[StringName, float] = {}
@export var rule_numbers: Dictionary[StringName, StringName] = {}
@export var stack_values: PackedStringArray = []
@export var compound_values: PackedStringArray = []


func number(key: StringName, stacks: int = 1) -> float:
	var base: float = numbers.get(key, 0.0)
	if rule_numbers.has(key):
		var parameter: StringName = rule_numbers[key]
		for rule in rules: base += float(rule.parameters.get(parameter, 0))
		if str(parameter).ends_with("_q"): base /= 1024.0
	if str(key) in compound_values: return (pow(1.0 + base / 100.0, stacks) - 1.0) * 100.0
	if str(key) in stack_values: return base * stacks
	return base


func number_keys() -> Array[StringName]:
	var keys: Array[StringName] = numbers.keys()
	keys.append_array(rule_numbers.keys())
	return keys


## Compilation passes activated prerequisite stacks; acquisition passes the current
## build. Full stacks keep duplicate limits and mutually exclusive choices exact.
func eligibility(book: StringName, stacks: Dictionary[StringName, int], active_stacks: Dictionary[StringName, int], capabilities: PackedStringArray, exclusive_groups: Dictionary, acquiring: bool = false) -> PackedStringArray:
	var diagnostics: PackedStringArray = []
	if int(stacks.get(id, 0)) + (1 if acquiring else 0) > max_stacks:
		diagnostics.append("MAX_STACKS:" + str(id))
	if not allowed_books.is_empty() and str(book) not in allowed_books:
		diagnostics.append("WRONG_MAIN_BOOK:" + str(id))
	for required in requires_all:
		if int(active_stacks.get(StringName(required), 0)) < 1:
			diagnostics.append("MISSING_RELIC:" + required)
	if not requires_any.is_empty():
		var has_any := false
		for required in requires_any:
			has_any = has_any or int(active_stacks.get(StringName(required), 0)) > 0
		if not has_any: diagnostics.append("MISSING_ANY_RELIC:" + str(id))
	for required in required_stacks:
		if int(active_stacks.get(required, 0)) < required_stacks[required]:
			diagnostics.append("MISSING_RELIC_STACKS:%s:%d" % [required, required_stacks[required]])
	for capability in requires_capabilities:
		if capability not in capabilities:
			diagnostics.append("MISSING_CAPABILITY:" + capability)
	if exclusive_group != &"":
		for other: StringName in exclusive_groups.get(exclusive_group, []):
			if other != id: diagnostics.append("EXCLUSIVE_RELIC:" + str(other))
	return diagnostics
