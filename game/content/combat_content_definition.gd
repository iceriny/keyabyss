class_name CombatContentDefinition
extends Resource

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var rules: Array[RuleDefinition] = []
@export var requires_any: PackedStringArray = []
@export var requires_all: PackedStringArray = []
@export var permits: PackedStringArray = []
@export var mode_slot: StringName
@export var max_stacks: int = 1
@export var replaces: StringName
@export var stage: StringName = &"M3"
@export var allowed_books: PackedStringArray = []
@export var supported: bool = false
@export var unsupported_reason: String
