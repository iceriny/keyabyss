class_name DampedMotion
extends RefCounted
## A frame-rate independent, critically damped 2D return to the origin.

var position := Vector2.ZERO
var velocity := Vector2.ZERO


func advance(delta: float, frequency: float) -> void:
	var omega := TAU * frequency
	var carry := velocity + position * omega
	var decay := exp(-omega * delta)
	position = (position + carry * delta) * decay
	velocity = (velocity - carry * omega * delta) * decay


func kick(offset: Vector2, limit: float) -> void:
	position = (position + offset).limit_length(limit)
	velocity = Vector2.ZERO


func reset() -> void:
	position = Vector2.ZERO
	velocity = Vector2.ZERO
