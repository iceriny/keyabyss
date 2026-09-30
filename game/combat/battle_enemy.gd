class_name BattleEnemy
extends RefCounted

const MELEE_REACH := 106.0
const MELEE_HALF_ANGLE := 0.82
const MELEE_STRIKE_TIME := 0.16
const MELEE_RECOVERY := 0.46

var id: StringName
var kind: StringName = &"nib"
var word: String
var word_pending: bool = false
var word_age: float = 0.0
var combat_locked: bool = false
var approach_direction: String = ""
var ambush: bool = false
var age: float = 0.0
var max_hp_q: int
var hp_q: int
var attack_damage_q: int
var attack_interval: float
var attack_clock: float
var warning_time: float = 0.9
var aimed_position := Vector2(0.5, 0.5)
var aiming: bool = false
var melee_origin := Vector2.ZERO
var melee_direction := Vector2.RIGHT
var melee_strike: float = 0.0
var melee_recovery: float = 0.0
var melee_hit: bool = false
var frozen_time: float = 0.0
var stagger_time: float = 0.0
var cold_q: int = 0
var control_resistance: int = 0
var control_protection: float = 0.0
var boss: bool = false
var resistances: PackedInt64Array = [0, 0, 0, 0, 0]
var resistance_label: String
var burn_time: float = 0.0 # Presentation projection of independent ongoing lots.
var local_slow_time: float = 0.0
var marked_time: float = 0.0
var position := Vector2.ZERO
var previous_position := Vector2.ZERO
var velocity := Vector2.ZERO
var impulse := Vector2.ZERO
var hit_flash: float = 0.0
var radius: float = 22.0
var mass: float = 1.0
var squash: float = 0.0
var counter_push_time: float = 0.0
var attack_serial: int = 0


func alive() -> bool:
	return hp_q > 0
