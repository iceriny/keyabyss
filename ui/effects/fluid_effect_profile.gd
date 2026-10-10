class_name FluidEffectProfile
extends Resource
## A reusable composition of motion, material and a native scene light.
## Rates use field-local units per second unless emission_per_distance is set.
## Zero duration means persistent.

@export var influences: Array[FluidInfluence] = []
@export var duration: float = 0.5
@export_range(0.0, 1.0) var fade_out: float = 0.7
@export var sweep: bool = false
## Interpret density/heat per travelled local unit; a stopped trail emits nothing.
@export var emission_per_distance: bool = false
@export var inherit_velocity: float = 0.0
@export var along_path: bool = false
@export var light_color := Color.WHITE
@export var light_energy: float = 0.0
@export var light_radius: float = 200.0
@export var particles: PackedScene
@export var particle_coupling: float = 1.8
