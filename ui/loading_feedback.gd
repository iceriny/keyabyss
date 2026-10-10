class_name LoadingFeedback
extends VBoxContainer
## Counts completed preparation work, never elapsed-time estimates.

signal stage_changed(done: int, total: int)

var reduced_motion := false
var radial_progress := false
var _stage := ""
var _started := 0
var _done := 0
var _total := 0


func update_stage(label: String, done: int, total: int) -> void:
	if label != _stage:
		_stage = label
		_started = Time.get_ticks_msec()
	_done = done
	_total = total
	$Stage.text = label
	$Progress.max_value = maxi(1, total)
	$Progress.value = done
	$Progress.indeterminate = total <= 0 and not reduced_motion
	$Progress.visible = not radial_progress and (total > 0 or not reduced_motion)
	_refresh_elapsed()
	stage_changed.emit(done, total)


func _refresh_elapsed() -> void:
	if not is_visible_in_tree(): return
	var seconds := floori((Time.get_ticks_msec() - _started) / 1000.0)
	var count := "%d / %d" % [_done, _total] if _total > 0 else ""
	$Count.text = count + ("  ·  %d 秒" % seconds if seconds > 0 else "")


func show_error(message: String) -> void:
	$WaitingTimer.stop()
	$Stage.text = message
	$Count.text = "请关闭窗口后重试"
	$Progress.hide()
