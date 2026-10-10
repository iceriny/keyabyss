class_name FluidMedium
extends Resource
## Material carried by the air. Temperature is heat per unit of emitted density.

@export var color := Color("8aa9b5")
@export var density_scale: float = 1.0
@export var temperature: float = 0.0
## Extra extinction per second; carried and mixed with density, not emitter age.
@export_range(0.0, 12.0) var dissipation: float = 0.0
## Radiance per unit density. Cools independently after emission stops.
@export_range(0.0, 12.0) var emission: float = 0.0
