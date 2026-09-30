class_name BuildSelection
extends RefCounted

var book_id: StringName = &"frost"
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
