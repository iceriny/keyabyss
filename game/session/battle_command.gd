class_name BattleCommand
extends RefCounted

var action: StringName
var build: CompiledBuild
var attempt_id: String
var target_id: StringName
var input_progress: int


static func intent(next_action: StringName) -> BattleCommand:
	var command := BattleCommand.new()
	command.action = next_action
	return command
