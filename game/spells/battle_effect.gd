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
var depth: int = 0
var manual_count: int = 5
var base_power_q: int = 0
var arc_base_hits: int = 3
var arc_index: int = 0
var arc_charge: float = 1.0
var manual_cast: bool = false
var mist_cast: bool = false
var bonus_shock: int = 0
var split_released: bool = false
var arc_anchor: StringName
var retargetable: bool = true
