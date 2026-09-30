class_name BattleEffect
extends RefCounted
## Paid effects hold value and source identity, never a target Node reference.

var source: StringName
var kind: StringName
var target_id: StringName
var word_owner: StringName = &""
var damage_q: int
var delay: float
var empowered: bool = false
var applications: int = 1
var jumps: int = 0
var retention_q: int = 1024
var origin := Vector2.ZERO
var visited: PackedStringArray = []
var lot: SpellLot
var cold: SpellLot
var charge: SpellLot
var heat: SpellLot
var build: CompiledBuild
var primary_share_q: int = 0
var dispatched: bool = false
var expires_at: float = INF
var shaped: bool = false
var optional_shape: bool = true
var shape: StringName
var shape_plan_ready: bool = false
var shape_targets: PackedStringArray = []
var shape_spread: bool = false
