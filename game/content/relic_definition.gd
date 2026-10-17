class_name RelicDefinition
extends CombatContentDefinition

# Requirements follow the effect being modified, including cross-book consumers.
# Adding a modifier cannot silently turn its enhancement into an effect source.
const SOURCE_REQUIREMENTS := {
	&"copy_pct": ["copy"], &"shielded_pct": ["shield"], &"shield_cap": ["shield"],
	&"cold_pct": ["cold"], &"cold_decay_pct": ["cold"],
	&"ice_direct_pct": ["frost_projectile"], &"frost_pierce": ["frost_projectile"], &"frost_flight_pct": ["frost_projectile"],
	&"freeze_ms": ["freeze"], &"frozen_pct": ["freeze"], &"freeze_shield": ["freeze"], &"freeze_resonance": ["freeze"],
	&"shatter_pct": ["frost_shatter"], &"shatter_radius": ["frost_shatter"],
	&"mist_ms": ["ice_mist"], &"mist_radius": ["ice_mist"], &"frost_domain_pct": ["frost_ultimate"], &"ultimate_cold": ["frost_ultimate"],
	&"cold_chain_pct": ["cold", "chain"], &"cold_burn_pct": ["cold", "burn"], &"cold_spirit_pct": ["cold", "spirit"],
	&"shock_pct": ["shock"], &"shock_decay_pct": ["shock"], &"shock_grace_ms": ["shock"], &"shocked_pct": ["shock"],
	&"storm_direct_pct": ["storm_arc"], &"chain_tail_pct": ["storm_arc"], &"chain_range": ["chain"], &"chain_hits": ["storm_arc"],
	&"charge_pct": ["storm_arc", "shock"], &"charged_shield": ["storm_arc", "shock"],
	&"storm_burst_pct": ["storm_burst"], &"storm_burst_radius": ["storm_burst"],
	&"dodge_storm_pct": ["dodge_storm"], &"dodge_shock": ["dodge_storm"], &"storm_domain_shock": ["storm_ultimate"],
	&"overload_pct": ["overload"], &"overload_radius": ["overload"], &"burn_chain_pct": ["burn", "chain"],
	&"spirit_shock_hit": ["spirit"], &"spirit_pct": ["spirit"], &"spirit_ms": ["spirit"],
	&"spirit_capacity": ["spirit"], &"spirit_speed_pct": ["spirit"], &"spirit_cooldown_pct": ["spirit"], &"full_spirit_pct": ["spirit"],
	&"cross_pct": ["spirit_cross"], &"crane_pct": ["paper_crane"], &"crane_ms": ["paper_crane"], &"crane_radius": ["paper_crane"],
	&"mark_pct": ["mark"], &"mark_grace_ms": ["mark"], &"mark_decay_pct": ["mark"], &"mark_kill_resonance": ["mark"],
	&"mark_shield": ["spirit_mark"], &"mark_fresh_points": ["spirit_mark"], &"ultimate_spirit_pct": ["spirit", "spirit_ultimate"],
	&"shielded_spirit_pct": ["shield", "spirit"], &"burn_spirit_pct": ["burn", "spirit"],
	&"flame_direct_pct": ["flame_spell"], &"burn_pct": ["burn"], &"burn_points_pct": ["burn"], &"burn_weak_pct": ["burn"],
	&"fire_field_rate_pct": ["fire_field"], &"fire_field_ms": ["fire_field", "flame_seal"], &"fire_field_radius": ["fire_field", "flame_seal"],
	&"dodge_flame_ms": ["dodge_flame"], &"dodge_flame_radius": ["dodge_flame"],
	&"burn_spread_radius": ["burn_spread"], &"burn_spread_targets": ["burn_spread"],
	&"flame_wave_pct": ["flame_ultimate"], &"flame_domain_pct": ["flame_ultimate"],
	&"burn_kill_resonance": ["burn"], &"burn_kill_shield": ["burn"], &"burning_pct": ["burn"],
}

# These parameters actually create an effect when their trigger is available.
const SOURCE_GRANTS := {
	&"word_shield": ["shield"], &"parry_shield": ["shield"], &"kill_shield": ["shield"], &"ultimate_shield": ["shield"],
	&"freeze_shield": ["shield"], &"charged_shield": ["shield"], &"mark_shield": ["shield"], &"burn_kill_shield": ["shield"],
	&"cold_hit": ["cold", "freeze"], &"dodge_cold": ["cold", "freeze"], &"parry_cold": ["cold", "freeze"], &"empowered_cold": ["cold", "freeze"],
	&"burn_hit": ["burn"], &"parry_burn": ["burn"],
	&"shock_hit": ["shock"], &"parry_shock": ["shock"], &"spirit_shock_hit": ["shock"],
	&"mark_hit": ["mark"], &"cross_mark_hit": ["mark"], &"parry_mark": ["mark"],
}

const SOURCE_GROUPS := {
	&"mixed_pct": {"options": ["cold", "burn", "shock", "mark"], "minimum": 2},
}
const SOURCE_INDEPENDENT: PackedStringArray = [
	"power_pct", "perfect_pct", "short_pct", "long_pct", "empowered_pct", "manual_pct", "imperfect_pct", "fresh_pct", "wounded_pct", "boss_pct", "combo_pct", "low_health_pct",
	"max_hp_flat", "defense_pct", "word_heal", "dodge_resonance", "resonance_pct", "pickup_heal", "kill_resonance", "parry_resonance", "ultimate_ms",
]

@export var opportunity_cost: int = 1
@export var rarity: StringName = &"common"
@export var choice_role: StringName = &"power"
@export var tags: PackedStringArray
@export var preferred_books: PackedStringArray
@export var requires_capabilities: PackedStringArray
@export var requires_any_capabilities: PackedStringArray
@export var minimum_capabilities: int = 1
@export var grants_capabilities: PackedStringArray
@export var required_stacks: Dictionary[StringName, int] = {}
@export var exclusive_group: StringName
@export var modifiers: Dictionary[StringName, int] = {}
@export var numbers: Dictionary[StringName, float] = {}
@export var rule_numbers: Dictionary[StringName, StringName] = {}
@export var stack_values: PackedStringArray
@export var compound_values: PackedStringArray


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


func required_capabilities() -> PackedStringArray:
	var result := requires_capabilities.duplicate()
	for key in modifiers:
		if modifiers[key] == 0: continue
		for capability: String in SOURCE_REQUIREMENTS.get(key, []):
			if capability not in result: result.append(capability)
	return result


func provided_capabilities() -> PackedStringArray:
	var result := grants_capabilities.duplicate()
	for key in modifiers:
		if modifiers[key] <= 0: continue
		for capability: String in SOURCE_GRANTS.get(key, []):
			if capability not in result: result.append(capability)
	return result


func required_capability_groups() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not requires_any_capabilities.is_empty():
		result.append({"options": requires_any_capabilities, "minimum": minimum_capabilities})
	for key in modifiers:
		if modifiers[key] != 0 and SOURCE_GROUPS.has(key): result.append(SOURCE_GROUPS[key])
	return result


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
	for capability in required_capabilities():
		if capability not in capabilities:
			diagnostics.append("MISSING_CAPABILITY:" + capability)
	for group in required_capability_groups():
		var available: Dictionary[String, bool] = {}
		for capability: String in group.options:
			if capability in capabilities: available[capability] = true
		if available.size() < int(group.minimum):
			diagnostics.append("MISSING_CAPABILITY_OPTIONS:" + str(id))
	if exclusive_group != &"":
		for other: StringName in exclusive_groups.get(exclusive_group, []):
			if other != id: diagnostics.append("EXCLUSIVE_RELIC:" + str(other))
	return diagnostics
