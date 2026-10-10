class_name RunCombatState
extends RefCounted
## Future expedition controller owns this object. Never holds room entities.

var hp_q: int = 100 * 1024
var shield_q: int = 0
var resonance_q: int = 0
var reserve: Array[SpellLot] = []
var reserve_cooldown_words: int = 0
var asset_claims: Dictionary[String, bool] = {}
var relic_counters: Dictionary = {}
var room_serial: int = 0


func claim_asset(instance: String, effect: StringName) -> bool:
	var key := "%s:%s" % [instance, effect]
	if asset_claims.has(key):
		return false
	asset_claims[key] = true
	return true
