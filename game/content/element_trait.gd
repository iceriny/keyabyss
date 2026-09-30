class_name ElementTrait
extends Resource
## Fixed enemy characteristic; independent of the player's selected book.

@export var enemy_kind: StringName
@export_enum("Neutral", "Ice", "Fire", "Lightning", "Paper") var resistance: int = 1
@export_enum("Neutral", "Ice", "Fire", "Lightning", "Paper") var weakness: int = 2
@export_range(0, 512) var magnitude_q: int = 256


func apply(enemy: BattleEnemy) -> void:
	enemy.resistances[resistance] = magnitude_q
	enemy.resistances[weakness] = -magnitude_q
	enemy.resistance_label = "%s抗性 %d%% · %s弱点 %d%%" % [DamagePacket.ELEMENT_NAMES[resistance], roundi(magnitude_q * 100.0 / 1024), DamagePacket.ELEMENT_NAMES[weakness], roundi(magnitude_q * 100.0 / 1024)]
