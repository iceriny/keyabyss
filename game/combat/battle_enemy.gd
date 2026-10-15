class_name BattleEnemy
extends RefCounted

const SIZE_SCALE := 0.85
const MELEE_REACH := 106.0
const MELEE_HALF_ANGLE := 0.82
const MELEE_STRIKE_TIME := 0.16
const MELEE_RECOVERY := 0.46
const REFRAIN_DELAY := 0.75
const WARD_DURATION := 2.5
const WARD_RANGE := 330.0
const WARD_DAMAGE_SCALE := 0.75

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
var freeze_cooldown: float = 0.0
var stagger_time: float = 0.0
var vulnerability: int = 0
var burn: int = 0
var cold: int = 0
var cold_grace: float = 0.0
var shock: int = 0
var cold_remainder: float = 0.0
var cold_gain_remainder: float = 0.0
var vulnerability_remainder: float = 0.0
var shock_remainder: float = 0.0
var burn_remainder: float = 0.0
var burn_clock: float = 0.0
var mark_grace: float = 0.0
var shock_grace: float = 0.0
var burn_root: String
var burn_depth: int = 0
var control_resistance: int = 0
var control_protection: float = 0.0
var boss: bool = false
var resistances: PackedInt64Array = [0, 0, 0, 0, 0]
var resistance_label: String
var burn_time: float = 0.0 # Presentation projection of burn points.
var local_slow_time: float = 0.0
var marked_time: float = 0.0
var last_seen_position := Vector2(0.5, 0.5)
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
var behavior: StringName = &"ranged"
var speed: float = 35.0
var phase: int = 1
var phase_lock: float = 0.0
var charge_time: float = 0.0
var charge_direction := Vector2.ZERO
var long_word: bool = false
var stationary: bool = false
var weave: bool = false
var charge_speed: float = 697.5
var aura: StringName
var aura_radius: float = 0.0
var mirror_ready: bool = false
var mirror_clock: float = 5.0
var spawn_count: int = 0
var small: bool = false
var shielded: bool = false
var front_armor_ready: bool = false
var delayed_attacks: Array[Dictionary] = []
var followup_time: float = 0.0
var volley_origin := Vector2.ZERO
var ward_remaining: float = 0.0
var ward_target_id: StringName
var ward_source_id: StringName


func alive() -> bool:
	return hp_q > 0


func cold_move_scale() -> float:
	if frozen_time > 0.0:
		return 0.0
	return lerpf(1.0, 0.5, clampf(cold / 90.0, 0.0, 1.0))


func cold_attack_scale() -> float:
	if frozen_time > 0.0:
		return 0.0
	return lerpf(1.0, 0.65, clampf(cold / 90.0, 0.0, 1.0))
