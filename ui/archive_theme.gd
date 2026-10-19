class_name ArchiveTheme
extends Theme

signal accent_changed

static func create(accent: Color) -> ArchiveTheme:
	var result := ArchiveTheme.new()
	result.merge_with(preload("res://ui/theme/keyabyss.tres").duplicate(true) as Theme)
	apply_accent(result, accent)
	return result


static func apply_accent(result: ArchiveTheme, accent: Color) -> void:
	# The book accent belongs to state cues; shared metal stays warm gold.
	if result.has_color("accent", "Archive") and result.get_color("accent", "Archive") == accent:
		return
	result.set_block_signals(true)
	result.set_color("accent", "Archive", accent)
	var bright := accent.lerp(Color.WHITE, 0.45)
	for type: String in ["LineEdit", "TextEdit"]:
		result.set_color("caret_color", type, bright)
		result.set_color("selection_color", type, Color(accent, 0.3))
	result.set_block_signals(false)
	# Color animation must not invalidate fonts and layout throughout the tree.
	result.accent_changed.emit()


static func inherited_by(control: Control) -> ArchiveTheme:
	var node: Node = control
	while node != null:
		if node is Control and node.theme != null:
			return node.theme as ArchiveTheme
		node = node.get_parent()
	return null


static func watch_colors(control: Control) -> void:
	var palette := inherited_by(control)
	if palette != null:
		# Only native inputs / explicit color consumers need their theme cache reset.
		var refresh := control.notification.bind(Control.NOTIFICATION_THEME_CHANGED)
		if not palette.accent_changed.is_connected(refresh):
			palette.accent_changed.connect(refresh)
