class_name ContentDescription
extends RefCounted

const BOOKS := {"frost": "寒墨之书", "flame": "灰烬之书", "storm": "雷鸣之书", "spirit": "纸灵之书"}

static func text(definition: CombatContentDefinition, catalog: BuildCatalog) -> String:
	var fragments: PackedStringArray = []
	for fragment in definition.description.split("；"):
		if fragment.strip_edges() != "无": fragments.append(_names(fragment, catalog))
	var lines: PackedStringArray = ["；".join(fragments)]
	if not definition.requires_all.is_empty():
		var names: PackedStringArray = []
		for id in definition.requires_all:
			names.append(catalog.get_definition(StringName(id)).title)
		lines.append("需要：" + "、".join(names))
	if not definition.requires_any.is_empty():
		var names: PackedStringArray = []
		for id in definition.requires_any:
			names.append(catalog.get_definition(StringName(id)).title)
		lines.append("任选一项前置：" + "、".join(names))
	if definition is RelicDefinition:
		lines.append("最多叠加 %d 层。" % definition.max_stacks)
	return "\n\n".join(lines)


static func diagnostics(messages: PackedStringArray, catalog: BuildCatalog) -> String:
	var lines: PackedStringArray = []
	for message in messages:
		var code := message.get_slice(":", 0)
		var argument := message.substr(code.length() + 1)
		var line := message
		match code:
			"MISSING_RELIC": line = "需要持有：" + _names(argument, catalog)
			"MAX_STACKS": line = _names(argument, catalog) + "已达叠层上限。"
			"WRONG_MAIN_BOOK": line = "当前主书无法使用" + _names(argument, catalog) + "。"
			"VOCABULARY_NEEDS_SHORT_WORD": line = "词库需要含有不超过4字母的词咒。"
			"VOCABULARY_NEEDS_LONG_WORD": line = "词库需要含有至少7字母的词咒。"
			"VOCABULARY_NEEDS_ASSISTABLE_WORD": line = "词库需要含有至少3字母的词咒。"
		line = _names(line, catalog)
		if line not in lines: lines.append(line)
	return "\n".join(lines)


static func _names(value: String, catalog: BuildCatalog) -> String:
	var pattern := RegEx.create_from_string("\\b(?:T[0-9]{2}|K[0-9]{2}|R[0-9]{3}|N[0-9]{2}-[0-9]{2}|frost|flame|storm|spirit)\\b")
	var matches := pattern.search_all(value)
	matches.reverse()
	for found in matches:
		if BOOKS.has(found.get_string()):
			value = value.substr(0, found.get_start()) + BOOKS[found.get_string()] + value.substr(found.get_end())
			continue
		var definition := catalog.get_definition(StringName(found.get_string()))
		if definition != null:
			value = value.substr(0, found.get_start()) + definition.title + value.substr(found.get_end())
	return value
