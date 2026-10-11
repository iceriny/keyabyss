extends MeshInstance2D
## Stationary folded membranes. UV.x is baked arc length in UI pixels;
## vertex RGB carries each triangle's geometric normal, alpha its coverage.

var _panel := Rect2()
var _vertices := PackedVector3Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()


func _ready() -> void:
	material = material.duplicate()


func arrange(panel: Rect2) -> void:
	if panel == _panel:
		return
	_panel = panel
	_vertices.clear()
	_uvs.clear()
	_colors.clear()
	# Separate, unequal leaves; their overlap never closes around the page.
	_append_sheet(-1.0, 0.01, 0.62, 62.0, 0.3)
	_append_sheet(-1.0, 0.36, 0.94, 31.0, 2.2)
	_append_sheet(-1.0, 0.16, 0.46, 23.0, 4.7)
	_append_sheet(1.0, 0.28, 0.99, 54.0, 1.4)
	_append_sheet(1.0, 0.03, 0.45, 28.0, 3.6)
	_append_sheet(1.0, 0.61, 0.91, 25.0, 5.3)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _colors
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = surface


func _append_sheet(side: float, start: float, end: float, width: float, phase: float) -> void:
	var edge := _panel.position.x if side < 0.0 else _panel.end.x
	var height := _panel.size.y * (end - start)
	var margin_scale := minf(1.0, (_panel.position.x - 12.0) / 130.0)
	var bend := minf(100.0, height * 0.22) * margin_scale
	var origin := Vector2(edge + side * (24.0 + 13.0 * sin(phase)) * margin_scale, _panel.position.y + _panel.size.y * start)
	var curve := Curve2D.new()
	curve.bake_interval = 2.0
	curve.add_point(origin, Vector2.ZERO, Vector2(side * bend, height * 0.32))
	curve.add_point(origin + Vector2(side * 22.0 * margin_scale, height), Vector2(side * bend * 0.76, -height * 0.28))
	var length := curve.get_baked_length()
	var steps := maxi(12, ceili(length / 24.0))
	var points := PackedVector3Array()
	var coords := PackedVector2Array()
	var coverages := PackedFloat32Array()
	for step in steps + 1:
		var t := float(step) / float(steps)
		var distance := length * t
		var center := curve.sample_baked(distance, true)
		var tangent := (curve.sample_baked(minf(length, distance + 1.0), true) - curve.sample_baked(maxf(0.0, distance - 1.0), true)).normalized()
		var cross_axis := Vector2(-tangent.y, tangent.x)
		var taper := pow(maxf(sin(PI * t), 0.001), 1.25)
		var span := width * margin_scale * taper * (0.78 + 0.22 * sin(t * 8.0 + phase))
		var ridge := 0.4 + 0.14 * sin(t * 5.0 + phase)
		for lane in 3:
			var across := ridge if lane == 1 else float(lane) * 0.5
			var point := center + cross_axis * (across - 0.5) * span
			# Height is used only to derive face normals, never to move the silhouette.
			var relief := span * (0.28 + 0.09 * sin(t * 13.0 + phase)) if lane == 1 else span * 0.08 * sin(t * 9.0 + phase + float(lane))
			points.append(Vector3(point.x, point.y, relief))
			coords.append(Vector2(distance + phase * 113.0, float(lane) * 0.5))
			coverages.append(smoothstep(0.0, 0.13, t) * (1.0 - smoothstep(0.77, 1.0, t)))
	for step in steps:
		for lane in 2:
			var a := step * 3 + lane
			_append_face(points, coords, coverages, Vector3i(a, a + 1, a + 3))
			_append_face(points, coords, coverages, Vector3i(a + 1, a + 4, a + 3))


func _append_face(points: PackedVector3Array, coords: PackedVector2Array, coverages: PackedFloat32Array, indices: Vector3i) -> void:
	var normal := (points[indices.y] - points[indices.x]).cross(points[indices.z] - points[indices.x]).normalized()
	if normal.z < 0.0:
		normal = -normal
	for index: int in [indices.x, indices.y, indices.z]:
		_vertices.append(Vector3(points[index].x, points[index].y, 0.0))
		_uvs.append(coords[index])
		_colors.append(Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5, coverages[index]))
