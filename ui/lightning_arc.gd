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
var _indices := PackedInt32Array()
var _arrays: Array = []
# Geometry calls are synchronous on the main thread; arcs share only scratch space.
static var _geometry: RefCounted = preload("res://ui/effects/LightningGeometry.cs").new()


static func prepare_geometry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_geometry.call("Build", 300.0, 0.0, 2, rng)
	_geometry.call("Build", 300.0, 96.0, 2, rng)


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
	var started := DebugLog.begin()
	_phase = phase
	_rng.seed = random_seed + phase * 7919
	var kernel_started := DebugLog.begin()
	_arrays = _geometry.call("Build", reach, burst_radius, quality, _rng)
	DebugLog.end(&"lightning.kernel", kernel_started)
	_vertices = _arrays[Mesh.ARRAY_VERTEX]
	_uvs = _arrays[Mesh.ARRAY_TEX_UV]
	_colors = _arrays[Mesh.ARRAY_COLOR]
	_indices = _arrays[Mesh.ARRAY_INDEX]
	_publish_mesh()
	DebugLog.end(&"lightning.geometry", started)


func _publish_mesh() -> void:
	var started := DebugLog.begin()
	var geometry := ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	mesh = geometry
	DebugLog.end(&"lightning.publish", started)
