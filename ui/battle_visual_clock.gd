class_name BattleVisualClock
extends Node
## One battle clock for native particle simulation, tweens and scripted effects.

var session: BattleSession
var _particles: Array[GPUParticles2D] = []
var _base_speeds: Array[float] = []
var _tweens: Array[Tween] = []


static func find(node: Node) -> BattleVisualClock:
	var parent := node
	while parent != null:
		if parent.has_meta(&"battle_visual_clock"):
			return parent.get_meta(&"battle_visual_clock") as BattleVisualClock
		parent = parent.get_parent()
	return null


static func delta_for(node: Node, real_delta: float) -> float:
	var clock := find(node)
	return clock.session.world_delta(real_delta) if clock != null else real_delta


static func tween_for(node: Node) -> Tween:
	var tween := node.create_tween()
	var clock := find(node)
	if clock != null:
		tween.set_speed_scale(clock.session.world_time_scale)
		clock._tweens.append(tween)
	return tween


func _ready() -> void:
	process_priority = -100
	get_parent().set_meta(&"battle_visual_clock", self)
	_watch(get_parent())


func _watch(node: Node) -> void:
	if node == self: return
	# Packed-scene entry can notify after the initial descendant walk.
	if node.child_entered_tree.is_connected(_watch): return
	if node is GPUParticles2D:
		_particles.append(node)
		_base_speeds.append(node.speed_scale)
		node.speed_scale *= session.world_time_scale
		node.tree_exiting.connect(func() -> void:
			var index := _particles.find(node)
			_particles.remove_at(index)
			_base_speeds.remove_at(index)
		)
	# Follow only this visual subtree; no global SceneTree node scan per frame.
	node.child_entered_tree.connect(_watch)
	for child in node.get_children(): _watch(child)


func _process(_delta: float) -> void:
	var speed := session.world_time_scale
	for index in _particles.size():
		_particles[index].speed_scale = _base_speeds[index] * speed
	for index in range(_tweens.size() - 1, -1, -1):
		if not _tweens[index].is_valid():
			_tweens.remove_at(index)
		else:
			_tweens[index].set_speed_scale(speed)
