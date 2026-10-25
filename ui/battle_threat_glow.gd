class_name BattleThreatGlow
extends Control
## Emissive flight lives in the HDR world; the overlay owns crisp danger shapes.

const ORB = preload("res://ui/effects/threat_orb.tres")
const CPU_PHASES: Array[StringName] = [&"battle.ribbon_numeric", &"battle.ribbon_merge", &"battle.ribbon_indices", &"battle.ribbon_upload"]
var session: BattleSession
var quality := 2
var reduced_motion := false
var low_ribbons: MeshInstance2D
@onready var ribbons: MeshInstance2D = $Ribbons
var _geometry: RefCounted = preload("res://ui/effects/ThreatRibbonGeometry.cs").new()
var _samples := PackedVector2Array()
var _offsets := PackedInt32Array()
var _physics_heads := PackedVector2Array()
var _render_heads := PackedVector2Array()
var _radii := PackedFloat64Array()
var _limits := PackedFloat64Array()
var _tints := PackedColorArray()
var index_uploaded := false


func _ready() -> void:
	_geometry.call("SetProfiling", DebugLog.enabled)


func _process(_delta: float) -> void:
	var started := DebugLog.begin()
	queue_redraw()
	_update_ribbons()
	DebugLog.end(&"battle.ribbons", started)


func _draw() -> void:
	if quality == 0: return
	var started := DebugLog.begin()
	var fraction := Engine.get_physics_interpolation_fraction()
	var scale_factor := size.x / BattleSession.ARENA_SIZE.x
	for threat in session.threats:
		var at := threat.previous_position.lerp(threat.position, fraction) * size
		var radius := threat.radius * scale_factor
		var tint := BattleThreatOverlay.threat_color(threat)
		# Two smooth falloffs leave the opaque identifying shape to the overlay.
		draw_texture_rect(ORB, Rect2(at - Vector2.ONE * radius * 4.5, Vector2.ONE * radius * 9.0), false, Color(tint * 1.5, 0.16))
		draw_texture_rect(ORB, Rect2(at - Vector2.ONE * radius * 2.1, Vector2.ONE * radius * 4.2), false, Color(tint * 1.65, 0.68))
	DebugLog.end(&"battle.threat_glow_draw", started)


func _update_ribbons() -> void:
	if session.threats.is_empty():
		index_uploaded = false
		ribbons.mesh = null
		if low_ribbons != null: low_ribbons.mesh = null
		return
	var packed_at := DebugLog.begin()
	_samples.clear()
	var count := session.threats.size()
	_offsets.resize(count + 1)
	_physics_heads.resize(count)
	_render_heads.resize(count)
	_radii.resize(count)
	_limits.resize(count)
	_tints.resize(count)
	var fraction := Engine.get_physics_interpolation_fraction()
	var scale_factor := size.x / BattleSession.ARENA_SIZE.x
	for index in count:
		var threat := session.threats[index]
		_offsets[index] = _samples.size()
		_samples.append_array(threat.trail)
		_physics_heads[index] = threat.position * size
		_render_heads[index] = threat.previous_position.lerp(threat.position, fraction) * size
		_radii[index] = threat.radius * scale_factor
		_limits[index] = (180.0 if threat.curvature != 0.0 else (64.0 if quality == 0 else 120.0)) * scale_factor * (0.45 if reduced_motion else 1.0)
		_tints[index] = BattleThreatOverlay.threat_color(threat)
	_offsets[count] = _samples.size()
	DebugLog.end(&"battle.ribbon_pack", packed_at)
	var built_at := DebugLog.begin()
	var mesh: ArrayMesh = _geometry.call("Build", _samples, _offsets, _physics_heads, _render_heads, _radii, _limits, _tints, size, quality == 2 and not reduced_motion)
	if low_ribbons != null:
		low_ribbons.mesh = mesh if quality == 0 else null
	ribbons.mesh = mesh if quality > 0 or low_ribbons == null else null
	DebugLog.end(&"battle.ribbon_build_upload", built_at)
	if DebugLog.enabled:
		var timings: PackedFloat64Array = _geometry.call("GetTimings")
		index_uploaded = timings[5] > 0.0
		for index in 4:
			DebugLog.add_cpu_duration(CPU_PHASES[index], timings[index])
