class_name RoomCombatResult
extends RefCounted

var room_id: int
var reason: StringName
var manual_characters: int
var manual_words: int
var elapsed: float
var raw_spent_q: int
var actual_damage_q: int
var overkill_damage_q: int
var unused_power_q: int
var healed_q: int
var guarded_damage_q: int
var guarded_hits: int
var freezes: int
var damage_by_source: Dictionary[StringName, int] = {}
var kills_by_source: Dictionary[StringName, int] = {}
var reserve: Array[SpellLot] = []
var asset_claims: Dictionary[String, bool] = {}
var progression_requests: Array[Dictionary] = []
