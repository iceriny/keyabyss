class_name OngoingSpell
extends RefCounted

var id: int
var effect: BattleEffect
var target_id: StringName
var remaining_pulses: int
var interval: float
var next_at: float
var advanced: bool = false
var delayed: bool = false
