class_name BattleVisualBudget
extends Node
## One battle-wide admission budget. Existing particles finish without eviction.

var quality := 2
var particles := 0
var enabled_lights := 0
var _frame := -1
var _admitted := 0
var _lights: Array[PointLight2D] = []


func _ready() -> void:
	# Apply after producers update their positions, energy and intended visibility.
	process_priority = 100


func grant_particles(requested: int) -> int:
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_admitted = 0
	var amount := maxi(0, mini(requested, mini(VisualQuality.PARTICLES[quality] - particles, VisualQuality.PARTICLES_PER_FRAME[quality] - _admitted)))
	particles += amount
	_admitted += amount
	return amount


func track_particles(node: GPUParticles2D, amount: int) -> void:
	node.tree_exited.connect(func() -> void: particles -= amount, CONNECT_ONE_SHOT)


func register_light(light: PointLight2D, priority: int) -> void:
	light.set_meta(&"visual_priority", priority)
	_lights.append(light)
	# Only membership changes reorder lights; same-priority identities stay stable.
	_lights.sort_custom(func(a: PointLight2D, b: PointLight2D) -> bool:
		var pa: int = a.get_meta(&"visual_priority")
		var pb: int = b.get_meta(&"visual_priority")
		return pa < pb if pa != pb else a.get_instance_id() < b.get_instance_id())
	light.tree_exited.connect(func() -> void: _lights.erase(light), CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	var remaining: int = VisualQuality.LIGHTS[quality]
	for light in _lights:
		light.enabled = remaining > 0 and light.is_visible_in_tree() and light.energy > 0.001
		if light.enabled: remaining -= 1
	enabled_lights = VisualQuality.LIGHTS[quality] - remaining
