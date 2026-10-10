class_name BattleUltimate
extends RefCounted
## A paid, finite ultimate timeline. Visuals read this state; they never drive pulses.

const DURATIONS := {&"frost": 4.0, &"flame": 5.0, &"storm": 6.0, &"spirit": 8.0}

var book: StringName
var center: Vector2
var age := 0.0
var duration: float
var lifetime: float
var radius: float
var pulse_clock := 0.12
var field_clock := 0.5
var pulses_left := 0
var effect: BattleEffect


func _init(school: StringName, origin: Vector2) -> void:
	book = school
	center = origin
	duration = DURATIONS[school]
	lifetime = duration
	radius = {&"frost": 420.0, &"flame": 460.0, &"storm": 420.0, &"spirit": 260.0}[school]
	pulses_left = 16 if school == &"frost" else (7 if school == &"flame" else 0)


func contains(at: Vector2) -> bool:
	return ((at-center)*BattleSession.ARENA_SIZE).length_squared() <= radius*radius
