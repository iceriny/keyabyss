class_name BuildCompileResult
extends RefCounted

var build: CompiledBuild
var diagnostics: PackedStringArray = []


func success() -> bool:
	return build != null and diagnostics.is_empty()
