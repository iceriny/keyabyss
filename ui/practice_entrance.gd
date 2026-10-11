class_name PracticeEntrance
extends Control
## Attach beside the changing page; release the opaque handover after the room is ready.

signal covered
signal completed

const SEALS: Dictionary[StringName, Texture2D] = {
	&"frost": preload("res://assets/art/runes/frost-seal.svg"),
	&"flame": preload("res://assets/art/runes/flame-seal.svg"),
	&"storm": preload("res://assets/art/runes/storm-seal.svg"),
	&"spirit": preload("res://assets/art/runes/spirit-seal.svg"),
}
const COLORS: Dictionary[StringName, Color] = {
	&"frost": Color("8bdeff"),
	&"flame": Color("ff994e"),
	&"storm": Color("ffd17c"),
	&"spirit": Color("c2a0ff"),
}

enum Phase { COVERING, WAITING, REVEALING, FINISHED }

var _phase := Phase.COVERING
var _reduced_motion := false
var _elapsed := 0.0
var _release_requested := false
var _covered_emitted := false


static func create_entrance(book_id: StringName, title: String, reduce_motion: bool) -> PracticeEntrance:
	var entrance := load("res://ui/scenes/practice_entrance.tscn").instantiate() as PracticeEntrance
	entrance._reduced_motion = reduce_motion
	(entrance.get_node("Inscription/Title") as Label).text = title
	var seal := entrance.get_node("Inscription/Seal") as TextureRect
	seal.texture = SEALS.get(book_id)
	seal.visible = seal.texture != null
	seal.modulate = Color(COLORS.get(book_id, Color("f0ddae")), 0.6)
	(entrance.get_node("Inscription/Gold") as CrystalInlay).set_motion_reduced(reduce_motion)
	return entrance


func _ready() -> void:
	_apply_opacity(0.0)


func _process(delta: float) -> void:
	if _phase == Phase.WAITING or _phase == Phase.FINISHED:
		return
	_elapsed += delta
	var duration := 0.1 if _reduced_motion else (0.32 if _phase == Phase.COVERING else 0.38)
	var progress := minf(_elapsed / duration, 1.0)
	var opacity := smoothstep(0.0, 1.0, progress)
	_apply_opacity(opacity if _phase == Phase.COVERING else 1.0 - opacity)
	if progress < 1.0:
		return
	if _phase == Phase.COVERING:
		_phase = Phase.WAITING
		_announce_covered.call_deferred()
	else:
		_phase = Phase.FINISHED
		set_process(false)
		completed.emit()
		queue_free()


func _apply_opacity(opacity: float) -> void:
	$Veil.color.a = opacity
	$Inscription.modulate.a = opacity


func _announce_covered() -> void:
	# Commit one fully covered frame before the host replaces the page.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return # The host may cancel the transition while the covered frame is pending.
	_covered_emitted = true
	covered.emit()
	if _release_requested:
		_begin_reveal()


func release() -> void:
	_release_requested = true
	if _phase == Phase.WAITING and _covered_emitted:
		_begin_reveal()


func _begin_reveal() -> void:
	# release() may be called directly inside the covered signal callback.
	if _phase != Phase.WAITING:
		return
	_elapsed = 0.0
	_phase = Phase.REVEALING
