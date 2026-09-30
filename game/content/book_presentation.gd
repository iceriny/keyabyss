class_name BookPresentation
extends Resource
## Archive identity retained from the original book definitions; no combat state.

@export var id: StringName
@export var title: String
@export var color: Color
@export var artwork: Texture2D
@export var seal: Texture2D
@export var eyebrow: String
@export var headline: String
@export var subtitle: String
@export var description: String
@export var ultimate: String
@export var fluid_material: FluidMedium
@export var fluid_effects: Dictionary[StringName, FluidEffectProfile] = {}
