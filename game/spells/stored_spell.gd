class_name StoredSpell
extends RefCounted

var id: int
var effect: BattleEffect
var position: Vector2
var born_at: float
var ready_at: float
var expires_at: float
var closed: bool = false
var transporting: bool = false
var returned: bool = false
var resealed: bool = false
var heat_q: int = 0
var guard_after: float = 0.0
var space_units: int = 1
var merged_sources: int = 1
