class_name BattleSlowLens
extends ColorRect
## Composite the world and danger layer once; HUD and target text stay crisp.

var amount := 0.0
var arrival := 0.0
var bend := 0.0
var capture: BackBufferCopy


func update_effect(session: BattleSession, delta: float, reduced: bool) -> void:
	var desired := 1.0 - session.world_time_scale if session.result == 0 else 0.0
	amount = lerpf(amount, desired, 1.0 - exp(-delta * (20.0 if desired > amount else 12.0)))
	if desired > .01: arrival = minf(1.0, arrival + delta / .24)
	if amount < .002:
		amount = 0.0
		arrival = 0.0
	visible = amount > 0.0
	capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if visible else BackBufferCopy.COPY_MODE_DISABLED
	bend = 0.0 if reduced else amount * .065
	var surface := material as ShaderMaterial
	surface.set_shader_parameter("amount", amount)
	surface.set_shader_parameter("arrival", 1.0 if reduced else arrival)
	surface.set_shader_parameter("bend", bend)


func project(point: Vector2) -> Vector2:
	# Invert the shader sampling map so unwarped words follow warped world anchors.
	var original := point / size * 2.0 - Vector2.ONE
	var radius := minf(original.length(), sqrt(2.0))
	if radius < .00001: return point
	var warped_radius := radius
	for iteration in 5:
		var fourth := pow(warped_radius, 4.0)
		warped_radius -= (warped_radius * (1.0 - bend * fourth * .25) - radius) / (1.0 - bend * fourth * 1.25)
	var projected := original * (warped_radius / radius)
	return (projected + Vector2.ONE) * .5 * size
