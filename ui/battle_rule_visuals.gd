class_name BattleRuleVisuals
extends Control
## Read-only projection of committed finite objects, never a rule owner.

var session: BattleSession
var reduced_motion := false
var quality := 2
var traces: Array[Dictionary] = []
const GOLD := Color("d7bd7d")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.event_committed.connect(_present)


func _present(event: Dictionary) -> void:
	if event.kind in [&"guard", &"transport", &"relay", &"letter_mark", &"letter_redeem", &"release"]:
		traces.append({"from": event.get("from", event.get("at", Vector2.ZERO)), "at": event.get("target", event.get("at", Vector2.ZERO)), "age": 0.0, "kind": event.kind})


func _process(delta: float) -> void:
	for trace in traces.duplicate():
		trace.age += delta
		if trace.age >= 0.65: traces.erase(trace)
	queue_redraw()


func _draw() -> void:
	if session.runtime == null: return
	for field in session.runtime.fields:
		var color := Color("7abacb") if field.effect.lot.material == SpellLot.Kind.COLD else Color("db975f")
		var at := field.center * size
		for band in (3 if quality > 0 else 1):
			draw_arc(at, field.radius - band * 8, 0.15 + band * 1.2, 1.8 + band * 1.2, 36, Color(color, 0.20 - band * 0.045), 2.0, true)
		if field.endpoint != field.center:
			draw_line(at, field.endpoint * size, Color(color, 0.13), field.radius * 1.2, true)
	for shell in session.runtime.stored:
		if shell.closed or shell.transporting: continue
		var at := shell.position * size
		# Offset the projection only: overlapping stored objects retain their true position.
		at += Vector2.from_angle(shell.id * 2.39996) * (16 + (shell.id % 3) * 12)
		var warmth := clampf(shell.heat_q / 1024.0, 0.0, 1.0)
		var tint := Color("89cbd4").lerp(Color("ebba72"), warmth)
		_leaf(at, 21 + 3 * shell.space_units, tint, 0.64)
		if shell.effect.build.has(&"guard"):
			draw_arc(at, 31, 0.15, PI - 0.15, 28, Color(GOLD, 0.45), 1.2, true)
		var fraction := clampf((session.runtime.clock - shell.born_at) / maxf(0.1, shell.ready_at - shell.born_at), 0.0, 1.0)
		draw_arc(at, 35, -PI / 2, -PI / 2 + fraction * TAU, 36, Color(tint, 0.32), 1.0, true)
	for spirit in session.spirits:
		if spirit.cargo != null and not spirit.cargo.closed:
			_leaf(spirit.position * size, 20, Color("d6c4e9"), 0.8)
	for trace in traces:
		var fraction: float = trace.age / 0.65
		var alpha := (1.0 - fraction) * 0.6
		var from: Vector2 = trace.from * size
		var at: Vector2 = trace.at * size
		if from.distance_squared_to(at) > 4.0:
			var curve := PackedVector2Array()
			var bend := (at - from).orthogonal().normalized() * minf(55, from.distance_to(at) / 5)
			for point in 25:
				var t := point / 24.0
				curve.append(from.lerp(at, t) + bend * sin(t * PI))
			draw_polyline(curve, Color(GOLD, alpha), 1.6, true)
		else:
			draw_arc(at, 14 + (0.0 if reduced_motion else fraction * 23), 0.2, TAU - 0.5, 32, Color(GOLD, alpha), 1.5, true)


func _leaf(at: Vector2, radius: float, tint: Color, alpha: float) -> void:
	var outline := PackedVector2Array()
	for index in 33:
		var angle := index * TAU / 32
		outline.append(at + Vector2(sin(angle) * radius * 0.55, cos(angle) * radius))
	draw_colored_polygon(outline, Color(tint, alpha * 0.08))
	draw_polyline(outline, Color(tint, alpha), 1.4, true)
	draw_line(at - Vector2(0, radius * 0.8), at + Vector2(0, radius * 0.8), Color(GOLD, alpha * 0.6), 1.0, true)
	for side in [-1, 1]:
		for branch in [-1, 0, 1]:
			draw_line(at + Vector2(0, branch * radius * 0.35), at + Vector2(side * radius * 0.4, branch * radius * 0.35 - radius * 0.22), Color(GOLD, alpha * 0.5), 1.0, true)
