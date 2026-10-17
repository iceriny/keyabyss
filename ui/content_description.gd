class_name ContentDescription
extends RefCounted

const BOOKS := {"frost": "寒墨之书", "flame": "灰烬之书", "storm": "雷鸣之书", "spirit": "纸灵之书"}
const RARITIES := {"common": "常见", "uncommon": "珍本", "rare": "秘藏", "awakening": "觉醒"}
const COLORS := {"common": Color("a8bfc0"), "uncommon": Color("78c9af"), "rare": Color("b59be5"), "awakening": Color("e3be71")}
static var _names_pattern := RegEx.create_from_string("\\b(?:[RGTAPF][0-9]{3}|frost|flame|storm|spirit)\\b")


static func values(definition: RelicDefinition, stacks: int) -> Dictionary:
	var result: Dictionary = {}
	for key in definition.number_keys(): result[key] = definition.number(key, stacks)
	for key in definition.modifiers:
		result[key] = clampi(definition.modifiers[key] * stacks, -RelicParameters.CAPS[key], RelicParameters.CAPS[key])
	return result


static func summary(definition: CombatContentDefinition, stacks: int = 1) -> String:
	if definition is RelicDefinition:
		return GameText.render(definition.description, values(definition, maxi(1, stacks)))
	return definition.description


static func text(definition: CombatContentDefinition, catalog: BuildCatalog, build: CompiledBuild = null, compare: bool = false) -> String:
	if not definition is RelicDefinition: return definition.description
	var relic := definition as RelicDefinition
	var owned := build.asset_stacks(relic.id) if build != null else 0
	var count := mini(relic.max_stacks, owned + 1) if compare else maxi(1, owned)
	var lines: PackedStringArray = []
	if compare and owned > 0:
		lines.append("当前 · %d层\n%s" % [owned, summary(relic, owned)])
		lines.append("取得后 · %d层\n%s" % [count, summary(relic, count)])
	else:
		lines.append(summary(relic, count))
	if build != null and not relic.modifiers.is_empty():
		var totals := values(relic, count)
		var shared := false
		var limited := false
		for key in relic.modifiers:
			var raw := 0
			for id in build.assets():
				var other := catalog.get_definition(id) as RelicDefinition
				raw += other.modifiers.get(key, 0) * build.asset_stacks(id)
				if id != relic.id and other.modifiers.has(key): shared = true
			if compare: raw += relic.modifiers[key]
			var bounded := clampi(raw, -RelicParameters.CAPS[key], RelicParameters.CAPS[key])
			totals[key] = bounded
			limited = limited or bounded != raw
		if shared: lines.append("同类合计" + (" · 取得后" if compare else "") + "\n" + GameText.render(relic.description, totals))
		if limited: lines.append("同类增益已按上限计算。")
	var requirements := requirements_text(relic, catalog)
	if not requirements.is_empty(): lines.append(requirements)
	if relic.exclusive_group != &"":
		var alternatives: PackedStringArray = []
		for id in catalog.relic_ids():
			var other := catalog.get_definition(StringName(id)) as RelicDefinition
			if other.id != relic.id and other.exclusive_group == relic.exclusive_group: alternatives.append(other.title)
		lines.append("不可同时持有：" + "、".join(alternatives))
	lines.append("最多%d层" % relic.max_stacks)
	return "\n\n".join(lines)


static func requirements_text(relic: RelicDefinition, catalog: BuildCatalog) -> String:
	var required: PackedStringArray = []
	for id in relic.requires_all:
		if not relic.required_stacks.has(StringName(id)): required.append(_names(id, catalog))
	for id in relic.required_stacks:
		required.append("%s%d层" % [_names(str(id), catalog), relic.required_stacks[id]])
	for capability in relic.required_capabilities():
		required.append(GameTerms.CAPABILITIES.get(capability, capability) + "来源")
	var lines: PackedStringArray = []
	if not required.is_empty(): lines.append("需要：" + "、".join(required))
	if not relic.requires_any.is_empty():
		var any_names: PackedStringArray = []
		for id in relic.requires_any: any_names.append(_names(id, catalog))
		lines.append("需要其中一件：" + "、".join(any_names))
	for group in relic.required_capability_groups():
		var options: PackedStringArray = []
		for capability: String in group.options: options.append(GameTerms.CAPABILITIES.get(capability, capability))
		lines.append("需要至少%d种来源：%s" % [group.minimum, "、".join(options)])
	return "\n".join(lines)


static func diagnostics(messages: PackedStringArray, catalog: BuildCatalog) -> String:
	var lines: PackedStringArray = []
	for message in messages:
		var code := message.get_slice(":", 0)
		var argument := message.substr(code.length() + 1)
		var line := message
		match code:
			"MISSING_RELIC": line = "需要持有：" + _names(argument, catalog)
			"MISSING_RELIC_STACKS": line = "需要%s%s层。" % [_names(argument.get_slice(":", 0), catalog), argument.get_slice(":", 1)]
			"MISSING_CAPABILITY": line = "需要先取得" + GameTerms.CAPABILITIES.get(argument, argument) + "来源。"
			"MISSING_ANY_RELIC":
				line = requirements_text(catalog.get_definition(StringName(argument)) as RelicDefinition, catalog)
			"MISSING_CAPABILITY_OPTIONS":
				line = requirements_text(catalog.get_definition(StringName(argument)) as RelicDefinition, catalog)
			"EXCLUSIVE_RELIC": line = "不能与" + _names(argument, catalog) + "同时持有。"
			"MAX_STACKS": line = _names(argument, catalog) + "已达层数上限。"
			"WRONG_MAIN_BOOK": line = "其他法书的专属遗物。"
			"VOCABULARY_NEEDS_SHORT_WORD": line = "词库需要含有不超过4字母的词咒。"
			"VOCABULARY_NEEDS_LONG_WORD": line = "词库需要含有至少7字母的词咒。"
			"VOCABULARY_NEEDS_ASSISTABLE_WORD": line = "词库需要含有至少3字母的词咒。"
		line = _names(line, catalog)
		if line not in lines: lines.append(line)
	return "\n".join(lines)


static func _names(value: String, catalog: BuildCatalog) -> String:
	var matches := _names_pattern.search_all(value)
	matches.reverse()
	for found in matches:
		var name_value := found.get_string()
		if BOOKS.has(name_value): name_value = BOOKS[name_value]
		else:
			var definition := catalog.get_definition(StringName(name_value))
			if definition != null: name_value = definition.title
		value = value.substr(0, found.get_start()) + name_value + value.substr(found.get_end())
	return value
