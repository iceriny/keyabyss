class_name LightningArc
extends MeshInstance2D
## Sparse, branching discharge geometry. Only the narrow luminous strips shade.

var reach := 300.0
var burst_radius := 0.0
var reduced := false
var quality := 2
var random_seed := 1
var illumination: FluidEmitter2D
var _phase := -1
var _rng := RandomNumberGenerator.new()
var _vertices := PackedVector2Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()


func _ready() -> void:
	var surface := preload("res://ui/materials/lightning_arc.tres").duplicate() as ShaderMaterial
	material = surface
	advance(0.0)


func advance(progress: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("progress", progress)
	(material as ShaderMaterial).set_shader_parameter("reduced_motion", reduced)
	if is_instance_valid(illumination):
		var age := progress * .24
		illumination.modulate.a = 0.0 if reduced else exp(-age*24.0) + .8*exp(-pow((age-.065)/.02,2.0)) + .4*exp(-pow((age-.13)/.018,2.0))
	var phase := 0 if reduced else mini(2, int(progress * 4.0))
	if phase == _phase: return
	_phase = phase
	_rng.seed = random_seed + phase * 7919
	_vertices.clear()
	_uvs.clear()
	_colors.clear()
	if burst_radius > 0.0:
		var tips := PackedVector2Array()
		var rotation_offset := _rng.randf_range(0.0, TAU)
		for index in 7:
			var angle := rotation_offset + index * TAU / 7.0
			var tip := Vector2.from_angle(angle) * burst_radius * _rng.randf_range(.78, 1.0)
			tips.append(tip)
			_append_path(_path(Vector2.ZERO, tip, burst_radius * .16), .8)
		if quality > 0:
			for index in 7:
				_append_path(_path(tips[index], tips[(index + 1) % 7], burst_radius * .1), .28)
		_publish_mesh()
		return
	var trunk := _path(Vector2(-reach * .5, 0), Vector2(reach * .5, 0), reach * .085)
	_append_path(trunk, 1.0)
	var branches := 0 if quality == 0 else ceili(clampi(int(reach / 95.0), 3, 9) * (0.5 if quality == 1 else 1.0))
	for index in branches:
		var root_index := _rng.randi_range(2, trunk.size() - 3)
		var origin := trunk[root_index]
		var direction := (trunk[root_index + 1] - trunk[root_index - 1]).normalized()
		var side := -1.0 if _rng.randf() < .5 else 1.0
		var branch_length := minf(reach * .3, 130)
		var tip := origin + direction.rotated(side * _rng.randf_range(.55, 1.4)) * _rng.randf_range(branch_length * .4, branch_length)
		var branch := _path(origin, tip, origin.distance_to(tip) * .18)
		_append_path(branch, _rng.randf_range(.18, .42))
		if quality == 2 and index % 2 == 0:
			var fork := branch[floori(branch.size() * .5)]
			_append_path(_path(fork, fork + direction.rotated(-side * .9) * _rng.randf_range(15, 40), 5.0), .12)
	_publish_mesh()


func _publish_mesh() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _colors
	var geometry := ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = geometry


func _path(start: Vector2, end: Vector2, displacement: float) -> PackedVector2Array:
	var points := PackedVector2Array([start, end])
	for level in clampi(ceili(log(start.distance_to(end) / 9.0) / log(2.0)), 2, 6):
		var divided := PackedVector2Array([points[0]])
		for index in points.size() - 1:
			var a := points[index]
			var b := points[index + 1]
			var normal := (b - a).normalized().orthogonal()
			var middle := a.lerp(b, _rng.randf_range(.35, .65)) + normal * _rng.randf_range(-displacement, displacement)
			divided.append(middle)
			divided.append(b)
		points = divided
		displacement *= .48
	return points


func _append_path(points: PackedVector2Array, power: float) -> void:
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		var axis := (b - a).normalized()
		var side := axis.orthogonal()
		var half := a.distance_to(b) * .5
		var center := (a + b) * .5
		var pad := 13.0 if power > .5 else 7.0
		var corners := PackedVector2Array([Vector2(-half-pad,-pad),Vector2(half+pad,-pad),Vector2(half+pad,pad),Vector2(-half-pad,pad)])
		for corner in [0, 1, 2, 0, 2, 3]:
			var local := corners[corner]
			_vertices.append(center + axis * local.x + side * local.y)
			_uvs.append(local)
			# Alpha is linear geometry data; RGB passes through Godot's sRGB decode.
			_colors.append(Color(power, float(index) / (points.size()-1), 0.0, half / 64.0).linear_to_srgb())
