class_name StatReadout
extends VBoxContainer

@export var caption := ""
@export var value := "—"


func _ready() -> void:
	$Caption.text = caption
	$Value.text = value


func display(next_value: String, tint: Color = Color("dfcca3")) -> void:
	value = next_value
	$Value.text = value
	$Value.modulate = tint
