class_name CombatBuildOverride
extends RefCounted
## The expedition controller owns expiry; this contract does not grant permits.

enum Boundary { ROOM, CHAPTER, RUN }
var id: String
var source_id: StringName
var expires_at: Boundary = Boundary.ROOM
var capabilities: PackedStringArray = []
var disabled_capabilities: PackedStringArray = []
var parameter_deltas: Dictionary[StringName, int] = {}
var modes: Dictionary[StringName, StringName] = {}
