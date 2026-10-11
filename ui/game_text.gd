class_name GameText
extends RefCounted
## Shared numeric interpolation. Text contains keys, never duplicated arithmetic.

static var _tokens := RegEx.create_from_string("\\{([a-zA-Z0-9_]+)\\}")


static func number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


static func render(template: String, values: Dictionary) -> String:
	var matches := _tokens.search_all(template)
	matches.reverse()
	for token in matches:
		var key := token.get_string(1)
		var absolute := key.ends_with("_abs")
		var seconds := key.ends_with("_ms_s")
		if absolute: key = key.trim_suffix("_abs")
		if seconds: key = key.trim_suffix("_s")
		assert(values.has(StringName(key)), "Missing text value: " + key)
		var value := float(values[StringName(key)])
		if absolute: value = absf(value)
		if seconds: value /= 1000.0
		template = template.substr(0, token.get_start()) + number(value) + template.substr(token.get_end())
	return template
