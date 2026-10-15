class_name BattleThreatGlow
extends Control
## Emissive flight lives in the HDR world; the overlay owns crisp danger shapes.

const ORB = preload("res://ui/effects/threat_orb.tres")
var session: BattleSession
var quality := 2
var reduced_motion := false
@onready var ribbons: MeshInstance2D = $Ribbons
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


func _process(_delta: float) -> void:
	queue_redraw()
	_update_ribbons()


func _draw() -> void:
	if quality == 0: return
	var fraction := Engine.get_physics_interpolation_fraction()
	var scale_factor := size.x / BattleSession.ARENA_SIZE.x
	for threat in session.threats:
		var at := threat.previous_position.lerp(threat.position, fraction) * size
		var radius := threat.radius * scale_factor
		var tint := BattleThreatOverlay.threat_color(threat)
		# Two smooth falloffs leave the opaque identifying shape to the overlay.
		draw_texture_rect(ORB, Rect2(at - Vector2.ONE * radius * 4.5, Vector2.ONE * radius * 9.0), false, Color(tint * 1.5, 0.16))
		draw_texture_rect(ORB, Rect2(at - Vector2.ONE * radius * 2.1, Vector2.ONE * radius * 4.2), false, Color(tint * 1.65, 0.68))


func _update_ribbons() -> void:
	_vertices.clear()
	_colors.clear()
	_uvs.clear()
	_indices.clear()
	if quality == 0:
		ribbons.mesh = null
		return
	var fraction := Engine.get_physics_interpolation_fraction()
	var scale_factor := size.x / BattleSession.ARENA_SIZE.x
	for threat in session.threats:
		var samples := PackedVector2Array()
		for sample in threat.trail: samples.append(sample * size)
		var head := threat.previous_position.lerp(threat.position, fraction) * size
		var length_limit := (180.0 if threat.curvature != 0.0 else 120.0) * scale_factor
		if reduced_motion: length_limit *= 0.45
		var tail := MotionTrail.build(samples, threat.position * size, head, length_limit, true, 48)
		if tail.size() < 2: continue
		var tint := BattleThreatOverlay.threat_color(threat)
		_append_ribbon(tail, threat.radius * scale_factor * 2.6, Color(tint * 1.75, 0.7))
		if quality == 2:
			_append_ribbon(tail, threat.radius * scale_factor * 7.0, Color(tint * 1.3, 0.13))
	if _indices.is_empty():
		ribbons.mesh = null
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var geometry := ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ribbons.mesh = geometry


func _append_ribbon(tail: PackedVector2Array, width: float, tint: Color) -> void:
	var distances := PackedFloat32Array([0.0])
	for index in range(1, tail.size()):
		distances.append(distances[-1] + tail[index - 1].distance_to(tail[index]))
	var count := tail.size()
	var base := _vertices.size()
	for index in count:
		var progress := distances[index] / distances[-1]
		var before := tail[maxi(0, index - 1)]
		var after := tail[mini(count - 1, index + 1)]
		var side := (after - before).normalized().orthogonal() * width * lerpf(0.08, 1.0, progress)
		_vertices.append(tail[index] + side)
		_vertices.append(tail[index] - side)
		var fade := Color(tint, tint.a * pow(progress, 1.35))
		_colors.append(fade)
		_colors.append(fade)
		_uvs.append(Vector2(progress, 0))
		_uvs.append(Vector2(progress, 1))
		# Explicit adjacent quads keep UVs across each strip, even on tiny bends.
		if index < count - 1:
			var at := base + index * 2
			_indices.append_array(PackedInt32Array([at, at + 1, at + 2, at + 1, at + 3, at + 2]))
