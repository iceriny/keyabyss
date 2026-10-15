class_name EnemyCombatDefinition
extends Resource

@export var kind: StringName = &"nib"
@export var radius: float = 28.0
@export var mass: float = 1.0
@export var health: int = 22
@export var attack_damage: int = 9
@export var attack_interval: float = 5.4
@export var warning_time: float = 0.9
@export var encounter_role: StringName
@export var experience: int = 0
@export var behavior: StringName = &"ranged"
@export var speed: float = 35.0
@export var boss: bool = false
# An Array literal default loses this packed property in binary export.
@export var boss_health: PackedInt32Array
@export var long_word: bool = false
@export var stationary: bool = false
@export var weave: bool = false
@export var charge_speed: float = 697.5
@export var aura: StringName
@export var aura_radius: float = 0.0
@export var mirror: bool = false
@export var death_spawn_kind: StringName
@export var death_pull: bool = false
@export var front_armor: bool = false
@export var spawn_limit: int = 99
