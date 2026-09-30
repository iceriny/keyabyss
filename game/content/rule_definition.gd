class_name RuleDefinition
extends Resource
## Closed operations. Parameters have named units; no expression interpreter.

@export var id: StringName
@export var operation: StringName
@export var phase: StringName
@export var parameters: Dictionary[StringName, int] = {}
