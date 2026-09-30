class_name BattleEncounter
extends Resource
## Read-only room composition; BattleSession owns every spawned entity and timer.

@export var wave_count: int = 3
@export var wave_interval: float = 1.6
@export var health_multiplier: float = 1.0
@export var enemies: Array[EnemyCombatDefinition] = [preload("res://game/content/enemies/nib.tres"), preload("res://game/content/enemies/quill.tres"), preload("res://game/content/enemies/guard.tres")]
@export var element_traits: Array[ElementTrait] = []
## Off-axis arrivals share the same entry, grace and compass pipeline.
## Disabled for the current single-room composition; content can opt in later.
@export_range(0.0, 1.0) var ambush_chance: float = 0.0
const DIRECTIONS := ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]


func approach_direction(main_direction: String, rng: RandomNumberGenerator) -> String:
	if ambush_chance > 0.0 and rng.randf() < ambush_chance:
		return DIRECTIONS[(DIRECTIONS.find(main_direction) + rng.randi_range(1, 7)) % 8]
	return main_direction


static func entry_position(direction: String, index: int, count: int, arena_size: Vector2) -> Vector2:
	# Cast formation rays onto the rectangular cold boundary. Pixel-space angles
	# remain consistent at every aspect ratio and diagonals cover adjacent edges.
	var lane := (float(index) + 0.5) / float(count) - 0.5
	var angle := DIRECTIONS.find(direction) * PI / 4.0 - PI / 2.0 + lane * deg_to_rad(90.0)
	var ray := Vector2.from_angle(angle)
	var half := arena_size * 0.5 - Vector2.ONE * 64.0
	var reach_x := INF if is_zero_approx(ray.x) else half.x / absf(ray.x)
	var reach_y := INF if is_zero_approx(ray.y) else half.y / absf(ray.y)
	return (arena_size * 0.5 + ray * minf(reach_x, reach_y)) / arena_size
