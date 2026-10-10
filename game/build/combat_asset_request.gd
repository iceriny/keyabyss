class_name CombatAssetRequest
extends RefCounted
## A combat configuration request. M4 owns pricing, acquisitions and deadlines.

enum Action { ADD, REMOVE, EVOLVE, OVERRIDE, RESTORE }
var action: Action
var content_id: StringName
var instance_id: String
var parent_id: StringName
var stacks: int = 1
var source_id: StringName
var expiry_scope: StringName = &"run"
var expiry_index: int = -1
var parent_instance_id: String
var override: CombatBuildOverride
