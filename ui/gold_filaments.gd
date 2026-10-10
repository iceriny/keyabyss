@tool
class_name GoldFilaments
extends MeshInstance2D
## Sparse botanical curves. UV.x is distance travelled from the shared root;
## UV.y is transverse distance in design pixels, for a filtered metal/glow core.

var spine_heights := Vector4.ZERO
var vertices := PackedVector3Array()
var coords := PackedVector2Array()
var weights := PackedColorArray()
var indices := PackedInt32Array()
var ribbon: ShaderMaterial
var _configured_size := Vector2(-1.0, -1.0)
var _configured_seed: int = 0


func _ready() -> void:
	ribbon = preload("res://ui/materials/gold_filament.tres").duplicate() as ShaderMaterial
	ribbon.set_shader_parameter("clock", 0.0)
	material = ribbon


func trigger_flow() -> void:
	ribbon.set_shader_parameter("trigger_time", float(ribbon.get_shader_parameter("clock")))


func configure(canvas_size: Vector2, motif_seed: int) -> void:
	if canvas_size == _configured_size and motif_seed == _configured_seed:
		return
	_configured_size = canvas_size
	_configured_seed = motif_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = motif_seed
	var base := canvas_size.y - 15.0
	var span := canvas_size.x - 24.0
	var p0 := Vector2(12.0, base + rng.randf_range(-3.0, 3.0))
	var p1 := Vector2(12.0 + span/3.0, base + rng.randf_range(-10.0, 3.0))
	var p2 := Vector2(12.0 + span*2.0/3.0, base + rng.randf_range(-3.0, 9.0))
	var p3 := Vector2(canvas_size.x - 12.0, base + rng.randf_range(-3.0, 3.0))
	spine_heights = Vector4(p0.y, p1.y, p2.y, p3.y)
	vertices.clear()
	coords.clear()
	weights.clear()
	indices.clear()
	var spine := _sample(p0, p1, p2, p3, maxi(20, ceili(span / 7.0)))
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, spine.size()):
		lengths.append(lengths[i-1] + spine[i].distance_to(spine[i-1]))
	_append_ribbon(spine, 0.0, 1.0, true)
	var branches := rng.randi_range(1, 2) if span < 140.0 else (2 if span < 260.0 else 3)
	for branch in branches:
		var fraction := (float(branch) + rng.randf_range(0.45, 0.85)) / float(branches + 1)
		var root_index := clampi(roundi(fraction * (spine.size()-1)), 1, spine.size()-2)
		var root := spine[root_index]
		var tangent := (spine[root_index+1] - spine[root_index-1]).normalized()
		var length := minf(span * rng.randf_range(0.10, 0.17), 36.0)
		var rise := rng.randf_range(4.0, 7.0) * (-1.0 if branch % 2 == 0 else 0.55)
		var tip := root + Vector2(length, rise)
		var shoot := _sample(root, root + tangent * length * 0.45,
			tip - Vector2(length * 0.3, rise * rng.randf_range(0.5, 1.1)), tip, 16)
		_append_ribbon(shoot, lengths[root_index], rng.randf_range(0.20, 0.32), false)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = coords
	arrays[Mesh.ARRAY_COLOR] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var generated := ArrayMesh.new()
	generated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = generated
	ribbon.set_shader_parameter("path_length", lengths[-1])
	ribbon.set_shader_parameter("phase", rng.randf_range(0.0, 1.0))


func _sample(a: Vector2, b: Vector2, c: Vector2, d: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count + 1:
		var t := float(i) / float(count)
		points.append(a.bezier_interpolate(b, c, d, t))
	return points


func _append_ribbon(points: PackedVector2Array, root_distance: float, strength: float, main: bool) -> void:
	var start := vertices.size()
	var distance := root_distance
	for i in points.size():
		if i > 0:
			distance += points[i].distance_to(points[i-1])
		var tangent := (points[mini(i+1, points.size()-1)] - points[maxi(i-1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var t := float(i) / float(points.size()-1)
		var fade := smoothstep(0.0, 0.15, t) * (1.0-smoothstep(0.72, 1.0, t)) if main else (1.0-smoothstep(0.45, 1.0, t))
		for side: float in [-1.0, 1.0]:
			var point := points[i] + normal * side * 7.0
			vertices.append(Vector3(point.x, point.y, 0.0))
			coords.append(Vector2(distance, side * 7.0))
			weights.append(Color(1.0, 1.0, 1.0, strength * fade))
		if i > 0:
			var v := start + i * 2
			indices.append_array(PackedInt32Array([v-2, v-1, v, v, v-1, v+1]))
