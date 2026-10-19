class_name BattleRuleVisuals
extends Control
## Read-only projection of committed finite objects, never a rule owner.

var session: BattleSession
var reduced_motion := false
var quality := 2
var fire_fallback := false
var field_nodes: Dictionary = {}
var _field_capture: BackBufferCopy
var _corrosion: Dictionary[OngoingSpell, Sprite2D] = {}
var _frost_imprints: Array[SpellField] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_capture = BackBufferCopy.new()
	_field_capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(_field_capture)
	session.event_committed.connect(_present)


func _present(event: Dictionary) -> void:
	if event.kind != &"frost_ground": return
	# Reuse the original ice surface without adding a damaging combat field.
	for imprint in _frost_imprints:
		if ((imprint.center - event.at) * BattleSession.ARENA_SIZE).length() < 45.0:
			imprint.expires_at = session.runtime.clock + event.duration
			imprint.radius = maxf(imprint.radius, event.radius)
			return
	var imprint := SpellField.new()
	imprint.id = hash(Vector3(event.at.x, event.at.y, session.runtime.clock))
	imprint.center = event.at
	imprint.endpoint = event.at
	imprint.radius = event.radius
	imprint.expires_at = session.runtime.clock + event.duration
	imprint.remaining_pulses = 1
	imprint.effect = BattleEffect.new()
	imprint.effect.kind = &"cold_field"
	_frost_imprints.append(imprint)


func _process(_delta: float) -> void:
	if session.runtime != null:
		_sync_corrosion()
		for imprint in _frost_imprints.duplicate():
			if imprint.expires_at <= session.runtime.clock: _frost_imprints.erase(imprint)
		var visible_fields := session.runtime.fields.duplicate()
		visible_fields.append_array(_frost_imprints)
		for field in visible_fields:
			if field.effect.kind == &"paper_crane": continue
			if not field_nodes.has(field):
				var visual := SpellFieldVisual.create(field, session.runtime.clock)
				visual.budget = (get_parent() as BattleVisuals).budget
				visual.birth_quality = quality
				visual.birth_reduced = reduced_motion
				add_child(visual)
				if field.effect.kind == &"fire_field":
					(get_parent() as BattleVisuals).fluid.bind_particles(visual.particles, 3.0)
				field_nodes[field] = visual
			field_nodes[field].sync_frame(size, session.runtime.clock, quality, reduced_motion, fire_fallback)
		for field in field_nodes.keys():
			if not visible_fields.has(field):
				field_nodes[field].finish()
				field_nodes.erase(field)
	_field_capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if get_child_count() - _corrosion.size() > 1 else BackBufferCopy.COPY_MODE_DISABLED
	queue_redraw()


func _draw() -> void:
	if session.runtime == null: return
	for field in session.runtime.fields:
		if field.effect.kind != &"paper_crane": continue
		var at := field.center * size
		var fade := clampf(field.expires_at - session.runtime.clock, 0.0, 1.0)
		var wing := PackedVector2Array([at + Vector2(-25, -11), at + Vector2(-4, 2), at + Vector2(0, -8), at + Vector2(23, -15), at + Vector2(10, 9), at + Vector2(-5, 5)])
		draw_colored_polygon(wing, Color("cdbfea", .6 * fade))
		draw_polyline(wing, Color("eedbbe", .9 * fade), 1.2, true)
		draw_line(at + Vector2(-4, 2), at + Vector2(10, 9), Color("897dba", fade), 1.0, true)
		ArcanaRunes.draw(self, "护", at + Vector2(0, 20), 17.0, Color("d7c9f0", .7 * fade))


func _sync_corrosion() -> void:
	for status in session.runtime.ongoing:
		if status.effect.kind != &"corrosion": continue
		var enemy := session.enemy_by_id(status.target_id)
		if enemy == null or not enemy.alive(): continue
		if not _corrosion.has(status):
			var created := Sprite2D.new()
			created.texture = preload("res://ui/effects/field_light.tres")
			created.material = preload("res://ui/materials/corrosion.tres").duplicate()
			(created.material as ShaderMaterial).set_shader_parameter("seed", float(enemy.id.hash() % 100))
			add_child(created)
			_corrosion[status] = created
		var patch := _corrosion[status]
		patch.position = enemy.previous_position.lerp(enemy.position, Engine.get_physics_interpolation_fraction()) * size
		patch.scale = Vector2.ONE * (enemy.radius * 6.0 + status.stacks * 10.0) / 128.0
		var surface := patch.material as ShaderMaterial
		surface.set_shader_parameter("clock", 0.0 if reduced_motion else session.runtime.clock)
		surface.set_shader_parameter("strength", .9 + .1 * status.stacks)
		surface.set_shader_parameter("fade", clampf(status.next_at + (status.remaining_pulses - 1) * status.interval - session.runtime.clock, 0.0, 1.0))
	for status in _corrosion.keys():
		if status not in session.runtime.ongoing:
			_corrosion[status].queue_free()
			_corrosion.erase(status)
