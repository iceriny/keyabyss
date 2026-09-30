class_name UltimateIndicator
extends Control

signal activated

var session: BattleSession
var options: AppSettings
var _level := 0.0
var _clock := 0.0
@onready var _surface: ShaderMaterial = $Light.material as ShaderMaterial
@onready var _value: Label = $Value


func configure(battle: BattleSession, settings: AppSettings, book: BookPresentation) -> void:
	session = battle
	options = settings
	$Seal.texture = book.seal
	$Key.description = book.ultimate
	$Key.accent = book.color
	($Light.material as ShaderMaterial).set_shader_parameter("tint", book.color)


func _process(delta: float) -> void:
	if session == null:
		return
	var active := session.ultimate_time > 0.0
	var target := float(session.resonance_q) / BattleSession.ULTIMATE_COST_Q
	if active:
		target = session.ultimate_time / BattleUltimate.DURATIONS[session.book_id]
	_level = target if options.reduce_motion else lerpf(_level, target, 1.0 - exp(-delta * 9.0))
	if not options.reduce_motion:
		_clock += delta
	_surface.set_shader_parameter("level", _level)
	_surface.set_shader_parameter("clock", _clock)
	_surface.set_shader_parameter("ready", not active and target >= 1.0)
	_surface.set_shader_parameter("active", active)
	$Seal.modulate = Color("f4ddb1", 0.9 if active or target >= 1.0 else 0.36 + target * 0.34)
	_value.text = "%.1fs" % session.ultimate_time if active else "%d%%" % roundi(target * 100.0)
	_value.modulate = Color("f5dba5") if active or target >= 1.0 else Color("bac6c5")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()
		accept_event()
