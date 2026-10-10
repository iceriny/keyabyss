class_name FluidInfluence
extends Resource
## Positions, sizes and velocities are in the owning FluidField2D's local units.

enum Shape { ELLIPSE, BOX, CAPSULE }
enum BodyShape { BLUNT, POINTED }

@export var shape: Shape = Shape.ELLIPSE
@export var center := Vector2.ZERO
@export var extent := Vector2(80, 80)
@export var rotation: float = 0.0
@export var velocity := Vector2.ZERO
@export var density: float = 0.0
@export var temperature: float = 0.0
@export var spin: float = 0.0
@export var continuous: bool = true
## Transparent means use the field's ambient tint. RGB is transported with density.
@export var color := Color.TRANSPARENT
@export var medium: FluidMedium
## Positive coupling transfers a moving body's momentum instead of adding acceleration.
@export_range(0.0, 60.0) var coupling: float = 0.0
## Signed radial acceleration/impulse: outward blast or inward attraction.
@export var radial: float = 0.0
## After projection: positive outward acceleration, negative inward flow speed.
@export var expansion: float = 0.0
@export_range(0.0, 1.0) var noise_amount: float = 0.0
@export var noise_scale: float = 360.0
@export var initial_age: float = 0.0
## Moving-body radius: coherent front displacement, side flow and rear refill.
## Zero keeps the ordinary directional force / jet behaviour.
@export var displacement_radius: float = 0.0
## Body flow shape is independent of the emission / wall footprint above.
@export var body_shape: BodyShape = BodyShape.BLUNT
@export_range(1.0, 4.0) var body_aspect: float = 2.4
## Local units/second: small footprints still exchange a readable amount of air.
@export_range(0.0, 1200.0) var response_speed: float = 240.0
var sweep_length: float = 0.0


func packed(ambient: Color = Color("668b9b")) -> PackedFloat32Array:
	var tint := (ambient if color.a == 0.0 else color).srgb_to_linear()
	var emission := density
	var heat := temperature
	if medium != null:
		tint = medium.color.srgb_to_linear()
		emission *= medium.density_scale
		heat += emission * medium.temperature
	return PackedFloat32Array([center.x, center.y, extent.x, extent.y,
		velocity.x, velocity.y, emission, heat,
		rotation, spin, float(shape), 1.0 if continuous else 0.0,
		tint.r, tint.g, tint.b, coupling,
		radial, noise_amount, noise_scale, initial_age,
		displacement_radius, sweep_length, body_aspect if body_shape == BodyShape.POINTED else 0.0, response_speed,
		medium.dissipation if medium != null else 0.0, medium.emission if medium != null else 0.0, expansion, 0.0])
