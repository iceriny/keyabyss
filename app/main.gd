class_name KeyabyssApp
extends Node
## Owns page navigation and services, while word progress belongs to TypingSession.

@onready var root: GameDisplay = $Interface/Root
@onready var router: InputRouter = $InputRouter
var settings := AppSettings.new()
var vocabulary := VocabularyRepository.new()
var page: PageShell
var practice: PracticePage
var battle: BattlePage
var departure: DepartureRitual
var route: String = "home"
var paused_route: String = ""
var settings_return: String = "home"
var commands: Dictionary[String, Callable] = {}
@onready var archive: ArchiveHome = $Interface/Root/ArchiveHome
@onready var sound: ArchiveAudio = $ArchiveAudio
@onready var cursor: ArchiveCursor = $Interface/Root/Cursor
var archive_return: String = "home"
var presentation_enabled: bool = true
var preview: VocabularyImport
var import_name: LineEdit
var import_text: TextEdit
var import_report: VBoxContainer
var import_save: Button
var selected_id: String = ""
var selected_entries: Array[VocabularyEntry] = []
var vocab_detail: VBoxContainer
var minimum: SpinBox
var maximum: SpinBox
var grow: CheckButton
var settings_controls: Dictionary[String, Control] = {}
var settings_tab: String = "display"
var _settings_groups: Dictionary[String, VBoxContainer] = {}
var _settings_tabs: Dictionary[String, OpenButton] = {}
var _settings_body: VBoxContainer
var _archive_theme: Theme
var _volume_labels: Dictionary[String, Label] = {}
var _audio_settings_dirty := false
@onready var _settings_save_timer: Timer = $SettingsSaveTimer
var _syncing_source: String = ""


func _enter_tree() -> void:
	# Native preview uses an isolated user space prepared by godot.ps1 preview.
	# Inject services before the authored home scene enters its ready phase.
	get_tree().node_added.connect(_configure_new_control)
	settings.load_settings()
	settings.apply(get_window())
	($Interface/Root as GameDisplay).settings = settings
	var home: ArchiveHome = $Interface/Root/ArchiveHome
	home.settings = settings
	home.repository = vocabulary


func _ready() -> void:
	_settings_save_timer.timeout.connect(_persist_audio_settings)
	archive.navigate.connect(_archive_navigate)
	archive.cue_requested.connect(sound.play_cue)
	archive.accent_changed.connect(func(_color: Color) -> void: _apply_book_theme())
	archive.book_selected.connect(func(_id: StringName) -> void:
		sound.play_cue("ui.book")
		_save_preparation()
	)
	archive.preparation_changed.connect(_save_preparation)
	_apply_visual_settings()
	router.command_requested.connect(_command)
	router.command_progress.connect(func(value: String) -> void:
		get_tree().call_group("open_motion_controls", "set_command_prefix", value)
		get_tree().call_group("word_command_tags", "set_command_prefix", value)
		for i in archive.cards.size():
			archive.cards[i].set_meta("command_match", not value.is_empty() and str(ArchiveHome.BOOKS[i].id).begins_with(value))
		archive.command_label.text = "›  %s▏" % value if not value.is_empty() else "›  输入词令"
		if not value.is_empty():
			sound.play_cue("ui.type")
		if is_instance_valid(page):
			if route in ["practice", "battle"]:
				page.command_hint.text = "Space 弹反 · 方向 / Alt 闪避 · 单独松开 Shift 终式"
			else:
				page.command_hint.text = "词令  %s▏" % value if not value.is_empty() else "点击或输入词令"
	)
	router.back_requested.connect(_back)
	router.action_requested.connect(func(action: StringName) -> void:
		if action == &"fullscreen":
			settings.fullscreen = not settings.fullscreen
			settings.apply(get_window())
			settings.save_settings()
			if route == "settings" and settings_controls.has("fullscreen"):
				(settings_controls["fullscreen"] as CheckButton).set_pressed_no_signal(settings.fullscreen)
				(settings_controls["fullscreen"] as CheckButton).text = "开启" if settings.fullscreen else "关闭"
			return
		if route == "home":
			match action:
				&"menu_previous": archive.select_book(archive.selected - 1)
				&"menu_next": archive.select_book(archive.selected + 1)
				&"menu_confirm": _start_battle()
			return
		if route == "prepare" and action == &"menu_confirm":
			_start_battle()
			return
		if route == "battle" and is_instance_valid(battle):
			battle.session.queue_action(action)
			return
		if is_instance_valid(practice):
			practice.show_action(action)
	)
	router.focus_lost.connect(func() -> void:
		if route in ["practice", "battle"]:
			_pause()
	)
	_home()
	if presentation_enabled:
		var gate := ArchiveGate.create()
		gate.sound = sound
		gate.reduced_motion = settings.reduce_motion
		gate.can_skip = settings.intro_complete
		root.add_child(gate)
		archive.modulate.a = 0.0
		archive.set_interactive(false)
		gate.arrival_progress.connect(func(value: float) -> void: archive.modulate.a = value)
		router.configure(InputRouter.Context.MODAL)
		gate.entered.connect(func() -> void:
			archive.modulate.a = 1.0
			archive.set_interactive(true)
			settings.intro_complete = true
			_save_preparation()
			_configure_archive_commands()
		)
	if not settings.last_error.is_empty():
		archive.command_label.text = settings.last_error
	print("Keyabyss M1 ready | %s | %s" % [Engine.get_version_info()["string"], RenderingServer.get_current_rendering_method()])
	if "--frame-profile" in OS.get_cmdline_user_args() and not "--profile-driver" in OS.get_cmdline_user_args():
		add_child(load("res://app/frame_capture.gd").new() as Node)


func _apply_visual_settings() -> void:
	root.refresh()
	_apply_book_theme()
	archive.reduced_motion = settings.reduce_motion
	archive.quality = settings.quality
	archive.fluid.scene_quality = settings.quality
	archive.fluid.set_options(settings.fluid_quality, settings.reduce_motion)
	cursor.reduced_motion = settings.reduce_motion
	archive._layout()
	get_tree().call_group("open_motion_controls", "set_motion_reduced", settings.reduce_motion)
	get_tree().call_group("smooth_scroll_controls", "set_motion_reduced", settings.reduce_motion)
	get_tree().call_group("crystal_motion_controls", "set_motion_reduced", settings.reduce_motion)
	if is_instance_valid(page):
		page.reduced_motion = settings.reduce_motion
	sound.enabled = settings.sound
	sound.effects_volume = settings.effects_volume
	sound.set_ambience(settings.ambience and settings.sound)
	if is_instance_valid(battle):
		battle.visuals.fluid.set_options(settings.fluid_quality, settings.reduce_motion)
		battle.audio.enabled = settings.sound
		battle.audio.effects_volume = settings.effects_volume


func _save_preparation() -> void:
	if not settings.save_settings():
		archive.command_label.text = settings.last_error


func _archive_navigate(destination: String) -> void:
	match destination:
		"vocab": _vocabulary_page()
		"help": _guide()
		"settings": _settings_page(route)
		"quit": get_tree().quit()
		"battle": _start_battle()
		"prepared", "archive":
			route = "prepare" if destination == "prepared" else "home"
			_configure_archive_commands()


func _configure_archive_commands() -> void:
	commands.clear()
	commands["back"] = func() -> void: archive.set_prepared(false)
	commands["vocab"] = _vocabulary_page
	commands["words"] = _vocabulary_page
	commands["help"] = _guide
	commands["guide"] = _guide
	commands["settings"] = func() -> void: _settings_page(route)
	commands["quit"] = func() -> void: get_tree().quit()
	if route == "home":
		commands["start"] = func() -> void: archive.set_prepared(true)
		for i in ArchiveHome.BOOKS.size():
			commands[str(ArchiveHome.BOOKS[i].id)] = func() -> void: archive.select_book(i)
			commands[str(i + 1)] = func() -> void: archive.select_book(i)
	elif route == "prepare":
		commands["start"] = _start_battle
		for i in ArchiveHome.MODE_IDS.size():
			_bind_control_command(archive.difficulty_buttons[i], ArchiveHome.MODE_IDS[i])
		_bind_control_command(archive.seed_edit, "seed")
		_bind_control_command(archive.vocabulary_select, "library")
		_bind_control_command(archive.get_node("LeftWingLayer/LeftWing/Progressive"), "progress")
	router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))


func _return_archive() -> void:
	if get_tree().paused and paused_route in ["battle", "practice"]:
		_pause()
		return
	var prepared := archive_return == "prepare"
	_home()
	if prepared:
		archive.set_prepared(true)


func _open(next_route: String, title: String, subtitle: String) -> void:
	_persist_audio_settings()
	if route in ["home", "prepare"]:
		archive_return = route
	if is_instance_valid(page):
		page.hide()
		if page != practice:
			page.queue_free()
	commands.clear()
	route = next_route
	page = PageShell.create(title, subtitle)
	page.theme = _archive_theme
	page.reduced_motion = settings.reduce_motion
	page.accent = archive.accent
	page.seal_texture = ArchiveHome.BOOKS[archive.selected].seal
	page.name = next_route.capitalize()
	root.add_child(page)
	archive.set_interactive(false)
	page.close_button.pressed.connect(_back)
	if next_route in ["words", "import", "guide"]:
		page.set_width(1160)
	sound.play_cue("ui.open")
	router.configure(InputRouter.Context.MENU)


func _button(parent: Node, caption: String, command: String, callback: Callable) -> OpenButton:
	var button := PageShell.button(parent, "%s    %s" % [caption, command], callback)
	button.name = command.capitalize()
	button.set_motion_reduced(settings.reduce_motion)
	button.pressed.connect(func() -> void: sound.play_cue("ui.select"))
	button.mouse_entered.connect(func() -> void: sound.play_cue("ui.focus"))
	_bind_control_command(button, command)
	router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
	return button


func _bind_control_command(control: Control, word: String) -> void:
	control.set_meta("word_command", word)
	if control is OptionButton and not control.has_meta("audio_bound"):
		control.set_meta("audio_bound", true)
		PopupCrystal.decorate(control, settings.reduce_motion)
		control.item_selected.connect(func(_index: int) -> void: sound.play_cue("ui.tab"))
	if control is CheckButton or control is OptionButton or control is LineEdit:
		CrystalInlay.decorate(control, settings.reduce_motion, is_instance_valid(page) and page.is_ancestor_of(control))
	commands[word] = _activate_control.bind(control)


func _activate_control(control: Control) -> void:
	if route == "settings" and is_instance_valid(control) and control.has_meta("settings_tab"):
		_select_settings_tab(str(control.get_meta("settings_tab")))
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	if control is BaseButton and control.disabled:
		return
	# Bring an off-screen command target into view before activating it.
	var ancestor := control.get_parent()
	while ancestor != root:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	if control is OptionButton:
		control.show_popup()
	elif control is CheckButton:
		control.button_pressed = not control.button_pressed
	elif control is BaseButton:
		control.pressed.emit()
	elif control is SpinBox:
		control.get_line_edit().grab_focus()
		control.get_line_edit().select_all()
	elif control is LineEdit or control is TextEdit or control is Slider:
		control.focus_mode = Control.FOCUS_CLICK
		control.grab_focus()


func _field_command(control: Control, word: String) -> void:
	_bind_control_command(control, word)
	var tag := CommandTag.create(word)
	control.get_parent().add_child(tag)
	control.get_parent().move_child(tag, control.get_index())


func _configure_new_control(node: Node) -> void:
	if node is Control and is_ancestor_of(node):
		_apply_control_policy.call_deferred(node)


func _apply_control_policy(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var control := node as Control
	control.focus_mode = Control.FOCUS_CLICK if control is LineEdit or control is TextEdit else Control.FOCUS_NONE
	control.tooltip_text = ""


func _apply_book_theme() -> void:
	if _archive_theme == null:
		_archive_theme = ArchiveTheme.create(archive.accent)
		root.theme = _archive_theme
		archive.theme = _archive_theme
	else:
		ArchiveTheme.apply_accent(_archive_theme, archive.accent)
	if is_instance_valid(page):
		page.set_accent(archive.accent)


func _command(command: String) -> void:
	if commands.has(command):
		commands[command].call()


func _home() -> void:
	var returning := route != "home"
	_persist_audio_settings()
	get_tree().paused = false
	if is_instance_valid(departure):
		departure.queue_free()
	departure = null
	if is_instance_valid(page):
		page.dismiss()
	page = null
	if is_instance_valid(practice) and not practice.is_queued_for_deletion():
		practice.queue_free()
	practice = null
	if is_instance_valid(battle) and not battle.is_queued_for_deletion():
		battle.queue_free()
	battle = null
	router.typing = null
	route = "home"
	archive.show()
	archive.set_interactive(true)
	archive.set_prepared(false)
	archive.refresh_vocabulary_choices()
	if returning:
		sound.play_cue("ui.close")
	_configure_archive_commands()


func _back() -> void:
	match route:
		"practice": _pause()
		"battle": _pause()
		"pause": _resume()
		"settings": _settings_back()
		"import": _vocabulary_page()
		"result": _home()
		"prepare": archive.set_prepared(false)
		"home":
			router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
		_: _return_archive()


func _guide() -> void:
	_open("guide", "施法指南", "")
	GuideContent.build(page.body, ArchiveHome.BOOKS[archive.selected], _start_practice)
	for button: Button in page.body.find_children("*", "Button", true, false):
		if button is OpenButton and not button._command_word.is_empty():
			if get_tree().paused and button._command_word == "practice":
				button.disabled = true
				continue
			_bind_control_command(button, button._command_word)
	_button(page.footer, "返回", "back", _return_archive)
	if not get_tree().paused:
		commands["practice"] = _start_practice
	router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))


func _vocabulary_page() -> void:
	_open("words", "词库工坊", "选择词咒的来源与词长")
	page.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 42)
	page.body.add_child(split)
	var list_scroll := SmoothScroll.new()
	list_scroll.reduced_motion = settings.reduce_motion
	list_scroll.custom_minimum_size.x = 295
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	split.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	var detail_scroll := SmoothScroll.new()
	detail_scroll.reduced_motion = settings.reduce_motion
	detail_scroll.name = "WordDetails"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.follow_focus = true
	split.add_child(detail_scroll)
	vocab_detail = VBoxContainer.new()
	vocab_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vocab_detail.add_theme_constant_override("separation", 16)
	detail_scroll.add_child(vocab_detail)
	var catalog := vocabulary.catalog()
	for index in catalog.size():
		var book: Dictionary = catalog[index]
		var word_command := str(book.id).replace("primary", "grade")
		if str(book.id) == "extension":
			word_command = "lexicon"
		elif str(book.id).begins_with("custom-"):
			word_command = "custom%d" % (index + 1)
		var choice := _button(list, str(book.title), word_command, func() -> void: _show_vocabulary(str(book.id)))
		choice.name = "V%02d" % (index + 1)
		choice.custom_minimum_size.y = 60
		choice.add_theme_font_size_override("font_size", 23)
	selected_id = settings.vocabulary_id
	if not catalog.any(func(book: Dictionary) -> bool: return str(book.id) == selected_id) and not catalog.is_empty():
		selected_id = str(catalog[0].id)
	_show_vocabulary(selected_id)
	_button(page.footer, "返回", "back", _return_archive)
	_button(page.footer, "导入词表", "import", _import_page)
	_button(page.footer, "使用词库", "use", _use_vocabulary)
	_button(page.footer, "导出", "export", _export_vocabulary)


func _show_vocabulary(id: String) -> void:
	commands.erase("sync")
	selected_id = id
	selected_entries = vocabulary.load_entries(id)
	for child in vocab_detail.get_children():
		vocab_detail.remove_child(child)
		child.queue_free()
	var title := id
	for book: Dictionary in vocabulary.catalog():
		if str(book.id) == id:
			title = str(book.title)
	PageShell.label(vocab_detail, title, 30, Color("f0ddae"))
	var metadata := vocabulary.describe(id)
	PageShell.label(vocab_detail, str(metadata.get("description", "")), 16, Color("a8b6b4"))
	PageShell.label(vocab_detail, str(metadata.get("source", "")), 13, Color("82918c"))
	PageShell.label(vocab_detail, "%d 个可用词条%s" % [selected_entries.size(), " · 当前使用" if id == settings.vocabulary_id else ""], 18)
	var source := vocabulary.sync_source(id)
	if not source.is_empty():
		var source_id := str(source.id)
		var sync_button := _button(vocab_detail, "同步中…" if _syncing_source == source_id else "同步源词表", "sync", func() -> void: _sync_vocabulary(source_id))
		sync_button.name = "Sync"
		sync_button.disabled = not _syncing_source.is_empty()
		PageShell.label(vocab_detail, "仅点击同步时联网；失败时继续使用已有词库。", 13, Color("82918c"))
	var range_row := HBoxContainer.new()
	range_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	range_row.add_theme_constant_override("separation", 24)
	vocab_detail.add_child(range_row)
	var length_label := PageShell.label(range_row, "词长", 18)
	length_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	minimum = _spin(range_row, settings.min_length)
	var separator := PageShell.label(range_row, "至", 18)
	separator.autowrap_mode = TextServer.AUTOWRAP_OFF
	maximum = _spin(range_row, settings.max_length)
	_field_command(minimum, "min")
	_field_command(maximum, "max")
	grow = CheckButton.new()
	grow.text = "渐进词长"
	grow.button_pressed = settings.progressive
	vocab_detail.add_child(grow)
	_field_command(grow, "progress")
	router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
	PageShell.label(vocab_detail, "词条预览", 20, Color("c9ae72"))
	var preview_grid := GridContainer.new()
	preview_grid.columns = 2
	preview_grid.add_theme_constant_override("h_separation", 28)
	preview_grid.add_theme_constant_override("v_separation", 18)
	vocab_detail.add_child(preview_grid)
	for entry in selected_entries.slice(0, 40):
		var pair := VBoxContainer.new()
		pair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_grid.add_child(pair)
		PageShell.label(pair, entry.word, 18, Color("c5d5d0"))
		PageShell.label(pair, entry.meaning, 14, Color("8b9c99"))
	if selected_entries.is_empty():
		page.status.text = vocabulary.last_error


func _sync_vocabulary(source_id: String) -> void:
	if not _syncing_source.is_empty():
		return
	var source := vocabulary.sync_source(source_id)
	if source.is_empty():
		page.status.text = "这个词库没有可同步的上游来源。"
		return
	_syncing_source = source_id
	_show_vocabulary(selected_id)
	page.status.text = "正在同步 %d 个源词表…" % source["sources"].size()
	var client := HTTPRequest.new()
	client.timeout = 15.0
	client.body_size_limit = VocabularyRepository.MAX_TEXT_LENGTH
	add_child(client)
	var entries: Array[VocabularyEntry] = []
	var seen := {}
	var failed_file := ""
	for item in source["sources"]:
		var parsed := await _download_vocabulary_source(client, item)
		if parsed == null:
			failed_file = str(item.get("file", ""))
			break
		for entry in parsed.entries:
			if not seen.has(entry.word):
				seen[entry.word] = true
				entries.append(entry)
	client.queue_free()
	_syncing_source = ""
	if not failed_file.is_empty():
		if route == "words":
			_show_vocabulary(selected_id)
			page.status.text = "源词表 %s 暂不可用，已有离线词库仍可使用。" % failed_file
		return
	var synced_id := vocabulary.save_synced(source_id, entries)
	if synced_id.is_empty():
		if route == "words":
			_show_vocabulary(selected_id)
			page.status.text = vocabulary.last_error
		return
	archive.refresh_vocabulary_choices()
	if route == "words" and selected_id in [source_id, synced_id]:
		_vocabulary_page()
		_show_vocabulary(synced_id)
		page.status.text = "已同步 %d 个可用词条。选择词长后可使用同步版。" % entries.size()


func _download_vocabulary_source(client: HTTPRequest, source: Dictionary) -> VocabularyImport:
	var filename := str(source.get("file", ""))
	var urls := [str(source.get("url", "")), "https://cdn.jsdelivr.net/gh/RealKai42/qwerty-learner@master/public/dicts/" + filename.uri_encode()]
	for url in urls:
		if client.request(url) != OK:
			continue
		var reply: Array = await client.request_completed
		if int(reply[0]) != HTTPRequest.RESULT_SUCCESS or int(reply[1]) != 200:
			continue
		var body: PackedByteArray = reply[3]
		var parsed := vocabulary.parse_import(body.get_string_from_utf8(), filename)
		if parsed.error.is_empty() and not parsed.entries.is_empty():
			return parsed
	return null


func _spin(parent: Node, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 24
	spin.value = value
	spin.custom_minimum_size.x = 125
	parent.add_child(spin)
	return spin


func _export_vocabulary() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.json ; JSON 词库"])
	dialog.current_file = selected_id + ".json"
	dialog.title = "导出词库"
	var words: Array[Dictionary] = []
	for entry in selected_entries:
		words.append({"word": entry.word, "meaning": entry.meaning})
	var payload := vocabulary.describe(selected_id)
	payload["schema_version"] = 1
	payload["words"] = words
	root.add_child(dialog)
	router.configure(InputRouter.Context.MODAL)
	dialog.canceled.connect(func() -> void:
		router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
		dialog.queue_free()
	)
	dialog.file_selected.connect(func(path: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			page.status.text = "无法导出词库，请检查保存位置的权限。"
		else:
			file.store_string(JSON.stringify(payload, "\t"))
			file.flush()
			page.status.text = "词库已导出。" if file.get_error() == OK else "写入失败，请检查磁盘空间。"
			file.close()
		router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
		dialog.queue_free()
	)
	dialog.popup_centered_ratio(.7)


func _use_vocabulary() -> void:
	if minimum.value > maximum.value:
		page.status.text = "最短词长不能大于最长词长。"
		return
	var entries := vocabulary.select_entries(PackedStringArray([selected_id]), int(minimum.value), int(maximum.value))
	if entries.is_empty():
		page.status.text = "这个词长范围内没有词条，请调整范围。"
		return
	var old := [settings.vocabulary_id, settings.min_length, settings.max_length, settings.progressive]
	settings.vocabulary_id = selected_id
	settings.min_length = int(minimum.value)
	settings.max_length = int(maximum.value)
	settings.progressive = grow.button_pressed
	if not settings.save_settings():
		settings.vocabulary_id = old[0]
		settings.min_length = old[1]
		settings.max_length = old[2]
		settings.progressive = old[3]
		page.status.text = settings.last_error
		return
	page.status.text = "已使用此词库 · 当前范围 %d 词" % entries.size()


func _import_page() -> void:
	_open("import", "导入词表", "预览后保存 · TXT / CSV / TSV / JSON / JSONL · UTF-8 · 最多 5 MB")
	preview = null
	import_name = LineEdit.new()
	import_name.text = "我的词表.txt"
	import_name.placeholder_text = "文件名，例如 words.csv"
	page.body.add_child(import_name)
	_field_command(import_name, "name")
	import_text = TextEdit.new()
	import_text.name = "ImportText"
	import_text.placeholder_text = "每行一词，或粘贴带释义的表格 / JSON"
	import_text.custom_minimum_size.y = 230
	import_text.add_theme_font_override("font", PageShell.SMALL_FONT)
	import_text.add_theme_font_size_override("font_size", 26)
	page.body.add_child(import_text)
	_field_command(import_text, "text")
	import_report = VBoxContainer.new()
	import_report.add_theme_constant_override("separation", 10)
	page.body.add_child(import_report)
	import_text.text_changed.connect(_invalidate_import)
	import_name.text_changed.connect(func(_text: String) -> void: _invalidate_import())
	_button(page.footer, "返回", "back", _vocabulary_page)
	_button(page.footer, "选择文件", "file", _choose_file)
	_button(page.footer, "预览", "preview", _preview_import)
	import_save = _button(page.footer, "保存", "save", _save_import)
	import_save.disabled = true


func _invalidate_import() -> void:
	preview = null
	if is_instance_valid(import_save):
		import_save.disabled = true
	for child in import_report.get_children():
		import_report.remove_child(child)
		child.queue_free()
	page.status.text = "修改后请重新预览。"


func _choose_file() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.txt,*.csv,*.tsv,*.json,*.jsonl ; 词表"])
	dialog.title = "选择词表"
	root.add_child(dialog)
	router.configure(InputRouter.Context.MODAL)
	dialog.canceled.connect(func() -> void:
		router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
		dialog.queue_free()
	)
	dialog.file_selected.connect(func(path: String) -> void:
		router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
		_invalidate_import()
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			page.status.text = "无法读取文件，请检查文件权限。"
		elif file.get_length() > 5000000:
			page.status.text = "文件超过 5 MB，请缩小词表后重试。"
		else:
			import_name.text = path.get_file()
			import_text.text = file.get_as_text()
			_preview_import()
		dialog.queue_free()
	)
	dialog.popup_centered_ratio(0.75)


func _preview_import() -> void:
	_invalidate_import()
	preview = vocabulary.parse_import(import_text.text, import_name.text)
	if not preview.error.is_empty():
		page.status.text = preview.error
		return
	page.status.text = "%d 条记录 · %d 有效 · %d 重复 · %d 问题" % [preview.raw_count, preview.entries.size(), preview.duplicates, preview.issues.size()]
	for issue in preview.issues.slice(0, 30):
		PageShell.label(import_report, issue, 16, Color("ffba9b"))
	for entry in preview.entries.slice(0, 30):
		PageShell.label(import_report, "%s    %s" % [entry.word, entry.meaning], 18)
	import_save.disabled = preview.entries.is_empty()


func _save_import() -> void:
	if preview == null or not preview.error.is_empty() or preview.entries.is_empty():
		return
	var id := vocabulary.save_import(preview)
	if id.is_empty():
		page.status.text = vocabulary.last_error
		return
	_vocabulary_page()
	_show_vocabulary(id)
	page.status.text = "词表已保存。选择词长后，使用此词库。"


func _settings_page(return_to: String) -> void:
	settings_return = return_to
	_open("settings", "设置", "")
	page.set_width(672)
	settings_controls.clear()
	_volume_labels.clear()
	_settings_groups.clear()
	_settings_tabs.clear()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 20)
	var layout := page.heading.get_parent().get_parent()
	layout.add_child(tabs)
	layout.move_child(tabs, 2)
	for entry: Array in [["display", "显示"], ["visuals", "效果"], ["audio", "声音"], ["gameplay", "玩法"]]:
		var id: String = entry[0]
		var tab := _button(tabs, entry[1], id, _select_settings_tab.bind(id))
		tab.toggle_mode = true
		_settings_tabs[id] = tab
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 18)
		page.body.add_child(group)
		_settings_groups[id] = group
	_settings_body = _settings_groups["display"]
	_check("fullscreen", "全屏显示", settings.fullscreen)
	var resolution_row := _setting_row("游戏分辨率", "resolution")
	var resolution_select := OptionButton.new()
	for value in AppSettings.RESOLUTIONS:
		resolution_select.add_item("自动（跟随窗口／屏幕）" if value == Vector2i.ZERO else "%d × %d" % [value.x, value.y])
	resolution_select.selected = AppSettings.RESOLUTIONS.find(settings.resolution)
	resolution_row.add_child(resolution_select)
	settings_controls["resolution"] = resolution_select
	resolution_select.set_meta("settings_tab", "display")
	_bind_control_command(resolution_select, "resolution")
	var scale_row := _setting_row("界面缩放", "scale")
	var scale_select := OptionButton.new()
	for caption in ["85%", "100%", "115%", "125%"]:
		scale_select.add_item(caption)
	var scales := [0.85, 1.0, 1.15, 1.25]
	scale_select.selected = scales.find(settings.ui_scale) if scales.has(settings.ui_scale) else 1
	scale_row.add_child(scale_select)
	settings_controls["ui_scale"] = scale_select
	scale_select.set_meta("settings_tab", "display")
	_bind_control_command(scale_select, "scale")
	_settings_body = _settings_groups["visuals"]
	_check("reduce_motion", "减少动态", settings.reduce_motion)
	var quality_row := _setting_row("画质", "effects")
	var quality_select := OptionButton.new()
	for caption in ["低", "中", "高"]:
		quality_select.add_item(caption)
	quality_select.selected = settings.quality
	quality_row.add_child(quality_select)
	settings_controls["quality"] = quality_select
	quality_select.set_meta("settings_tab", "visuals")
	_bind_control_command(quality_select, "effects")
	var fluid_row := _setting_row("流体效果", "fluid")
	var fluid_select := OptionButton.new()
	for caption in ["关闭", "低 · 更省性能", "中 · 均衡", "高 · 更细腻", "极高 · 精细雾流"]:
		fluid_select.add_item(caption)
	fluid_select.selected = settings.fluid_quality
	fluid_row.add_child(fluid_select)
	fluid_select.set_meta("settings_tab", "visuals")
	settings_controls["fluid_quality"] = fluid_select
	_bind_control_command(fluid_select, "fluid")
	PageShell.label(_settings_body, "各档保持连贯流动，越高则雾气轮廓、卷曲与雾中光线越细腻，也越需要显卡性能。减少动态时停止流动效果。", 16, Color("aab9c2"))
	_settings_body = _settings_groups["audio"]
	_check("sound", "声音", settings.sound)
	_volume_setting("volume", "总音量", settings.volume)
	_volume_setting("effects_volume", "音效音量", settings.effects_volume)
	_check("ambience", "氛围音", settings.ambience)
	_settings_body = _settings_groups["gameplay"]
	_check("show_meaning", "头顶中文释义", settings.show_meaning)
	_select_settings_tab(settings_tab)
	_button(page.footer, "返回", "back", _settings_back)
	_button(page.footer, "恢复默认", "defaults", _defaults)
	page.status.text = "设置自动保存于本机"
	for control: Control in settings_controls.values():
		if control is CheckButton:
			control.toggled.connect(func(_value: bool) -> void: _save_settings())
		elif control is OptionButton:
			control.item_selected.connect(func(_index: int) -> void: _save_settings())


func _select_settings_tab(id: String) -> void:
	settings_tab = id
	for key: String in _settings_groups:
		_settings_groups[key].visible = key == id
		_settings_tabs[key].set_pressed_no_signal(key == id)
		_settings_tabs[key].set_selected_visual(key == id)
	page.scroll.scroll_vertical = 0
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and not focused.is_visible_in_tree():
		focused.release_focus()


func _volume_setting(key: String, caption: String, value: float) -> void:
	var word := "volume" if key == "volume" else "sfx"
	var row := _setting_row(caption, word)
	row.custom_minimum_size.y = 28
	var amount := PageShell.label(row,"%d%%" % roundi(value*100),16,Color("e3c88b"))
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.custom_minimum_size.x = 60
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.size_flags_horizontal = Control.SIZE_SHRINK_END
	_volume_labels[key] = amount
	var slider := HSlider.new()
	slider.min_value = 0.
	slider.max_value = 1.
	slider.step = .01
	slider.value = value
	slider.custom_minimum_size.y = 20
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_body.add_child(slider)
	slider.set_meta("settings_tab", "audio")
	_bind_control_command(slider, word)
	slider.value_changed.connect(func(next: float) -> void:
		amount.text = "%d%%" % roundi(next*100)
		settings.set(key, next)
		if key == "volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(next, .0001)))
			AudioServer.set_bus_mute(0, next <= 0.0)
		else:
			sound.effects_volume = next
		_audio_settings_dirty = true
		_settings_save_timer.start()
	)
	slider.drag_ended.connect(func(_changed: bool) -> void: _persist_audio_settings())
	settings_controls[key] = slider


func _setting_row(caption: String, word: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46
	row.add_theme_constant_override("separation", 18)
	_settings_body.add_child(row)
	var label := PageShell.label(row, caption, 16)
	label.custom_minimum_size.x = 180
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not word.is_empty():
		row.add_child(CommandTag.create(word))
	return row


func _check(key: String, caption: String, checked: bool) -> void:
	var word: String = {"ambience": "music", "fullscreen": "full", "reduce_motion": "motion", "show_meaning": "translation"}.get(key, key)
	var row := _setting_row(caption, word)
	var toggle := CheckButton.new()
	toggle.layout_direction = Control.LAYOUT_DIRECTION_RTL
	toggle.text = "开启" if checked else "关闭"
	toggle.button_pressed = checked
	toggle.custom_minimum_size.x = 90
	toggle.toggled.connect(func(value: bool) -> void: toggle.text = "开启" if value else "关闭")
	row.add_child(toggle)
	settings_controls[key] = toggle
	toggle.set_meta("settings_tab", "gameplay" if key == "show_meaning" else "visuals" if key == "reduce_motion" else "display" if key == "fullscreen" else "audio")
	_bind_control_command(toggle, word)


func _defaults() -> void:
	for control: Control in settings_controls.values():
		control.set_block_signals(true)
	(settings_controls["fullscreen"] as CheckButton).button_pressed = false
	(settings_controls["resolution"] as OptionButton).selected = 0
	(settings_controls["ui_scale"] as OptionButton).selected = 1
	(settings_controls["reduce_motion"] as CheckButton).button_pressed = false
	(settings_controls["quality"] as OptionButton).selected = 2
	(settings_controls["fluid_quality"] as OptionButton).selected = 2
	(settings_controls["show_meaning"] as CheckButton).button_pressed = true
	(settings_controls["volume"] as HSlider).value = 0.28
	(settings_controls["effects_volume"] as HSlider).value = 1.0
	(settings_controls["sound"] as CheckButton).button_pressed = true
	(settings_controls["ambience"] as CheckButton).button_pressed = true
	for control: Control in settings_controls.values():
		control.set_block_signals(false)
		if control is CheckButton:
			control.text = "开启" if control.button_pressed else "关闭"
	for key: String in _volume_labels:
		_volume_labels[key].text = "%d%%" % roundi((settings_controls[key] as HSlider).value * 100)
	if _save_settings():
		page.status.text = "已恢复默认设置。"


func _save_settings() -> bool:
	_settings_save_timer.stop()
	var old: Dictionary[String, Variant] = {}
	for key: String in settings_controls:
		old[key] = settings.get(key)
		var control: Control = settings_controls[key]
		if control is CheckButton:
			settings.set(key, control.button_pressed)
		elif control is OptionButton:
			match key:
				"resolution": settings.resolution = AppSettings.RESOLUTIONS[control.selected]
				"ui_scale": settings.ui_scale = [0.85, 1.0, 1.15, 1.25][control.selected]
				_: settings.set(key, control.selected)
		elif control is HSlider:
			settings.set(key, control.value)
	if not settings.save_settings():
		for key: String in old:
			settings.set(key, old[key])
		page.status.text = settings.last_error
		return false
	_audio_settings_dirty = false
	settings.apply(get_window())
	_apply_visual_settings()
	page.status.text = "设置已保存。"
	return true


func _persist_audio_settings() -> void:
	if not _audio_settings_dirty:
		return
	_settings_save_timer.stop()
	var saved := settings.save_settings()
	_audio_settings_dirty = not saved
	if is_instance_valid(page) and route == "settings":
		page.status.text = "设置已保存。" if saved else settings.last_error


func _exit_tree() -> void:
	if _audio_settings_dirty:
		settings.save_settings()


func _settings_back() -> void:
	if settings_return == "pause":
		_pause()
	else:
		_return_archive()


func _start_practice() -> void:
	var entries := vocabulary.select_entries(PackedStringArray([settings.vocabulary_id]), settings.min_length, settings.max_length)
	if entries.is_empty():
		_vocabulary_page()
		page.status.text = "当前词库或词长范围不可用，请重新选择。"
		return
	if is_instance_valid(page):
		page.queue_free()
	commands.clear()
	practice = PracticePage.create_practice(entries, settings)
	practice.theme = _archive_theme
	practice.name = "Practice"
	root.add_child(practice)
	page = practice
	route = "practice"
	practice.set_width(1160)
	practice.close_button.pressed.connect(_pause)
	PageShell.button(practice.footer, "暂停    Esc", _pause)
	practice.command_hint.text = "Space 弹反 · 方向 / Alt 闪避 · 单独松开 Shift 终式"
	router.typing = practice.typing
	router.configure(InputRouter.Context.TYPING)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _start_battle() -> void:
	if route == "departure":
		return
	var entries := vocabulary.select_entries(PackedStringArray([settings.vocabulary_id]), settings.min_length, settings.max_length)
	if entries.is_empty():
		_vocabulary_page()
		page.status.text = "当前词库或词长范围不可用，请重新选择。"
		return
	if is_instance_valid(page):
		page.queue_free()
	page = null
	commands.clear()
	get_tree().paused = false
	route = "departure"
	router.typing = null
	router.configure(InputRouter.Context.MODAL)
	archive.set_interactive(false)
	departure = preload("res://ui/scenes/departure_ritual.tscn").instantiate() as DepartureRitual
	departure.book = ArchiveHome.BOOKS[archive.selected]
	departure.reduced_motion = settings.reduce_motion
	departure.cue_requested.connect(sound.play_cue)
	departure.covered.connect(_enter_battle.bind(entries))
	departure.completed.connect(func() -> void:
		departure = null
		route = "battle"
		battle.session.set_physics_process(true)
		router.typing = battle.session.typing
		router.configure(InputRouter.Context.TYPING)
		if DisplayServer.get_name() != "headless" and not get_window().has_focus():
			_pause()
	)
	root.add_child(departure)


func _enter_battle(entries: Array[VocabularyEntry]) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
	var session := BattleSession.new()
	session.name = "Session"
	var selection := BuildSelection.new()
	selection.book_id = StringName(settings.book_id)
	var compiled := BuildCompiler.new().compile(selection)
	assert(compiled.success(), str(compiled.diagnostics))
	var request := BattleStartRequest.new()
	request.build = compiled.build
	request.vocabulary = entries
	request.difficulty = settings.difficulty
	request.seed_text = settings.run_seed
	request.progressive = settings.progressive
	request.minimum_length = settings.min_length
	session.start(request)
	battle = BattlePage.create(session, settings, ArchiveHome.BOOKS[archive.selected])
	battle.theme = _archive_theme
	battle.name = "Battle"
	root.add_child(battle)
	session.set_physics_process(false)
	battle.pause_requested.connect(_pause)
	session.finished.connect(_battle_finished)
	archive.hide()
	archive.set_interactive(false)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _battle_finished(victory: bool) -> void:
	if not is_instance_valid(battle):
		return
	var session := battle.session
	if not session.abandoned_run:
		battle.audio.play_result(victory, battle.size)
	_open("result", "墨迹 · 此页已明" if victory else ("归卷 · 重返书库" if session.abandoned_run else "墨尽 · 未完待续"), "")
	page.compact_height = 850.0
	page.set_width(1180)
	page.heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.heading.add_theme_color_override("font_color", Color("dfc58b") if victory else (Color("9bb8c8") if session.abandoned_run else Color("d58f83")))
	page.pattern.hide()
	page.get_node("ContentLayer/GoldBranch").hide()
	page.status.hide()
	var report := preload("res://ui/scenes/battle_result.tscn").instantiate() as BattleResult
	page.body.add_child(report)
	report.configure(session, ArchiveHome.BOOKS[archive.selected], session.abandoned_run)
	var atmosphere := preload("res://ui/scenes/outcome_atmosphere.tscn").instantiate() as OutcomeAtmosphere
	atmosphere.victory = victory
	atmosphere.reduced_motion = settings.reduce_motion or session.abandoned_run
	page.add_child(atmosphere)
	page.move_child(atmosphere, page.content_layer.get_index())
	page.footer.alignment = BoxContainer.ALIGNMENT_END
	_button(page.footer, "返回书库", "home", _home)
	for item: Array in [["远征记录", "history"], ["调整天赋", "talents"], ["导出战报", "report"]]:
		var placeholder := _button(page.footer, item[0], item[1], func() -> void: pass)
		placeholder.disabled = true
	_button(page.footer, "再写一局", "retry", _start_battle)


func _pause() -> void:
	if route not in ["practice", "battle"] and not (get_tree().paused and paused_route in ["practice", "battle"]):
		return
	if route in ["practice", "battle"]:
		paused_route = route
	if paused_route == "battle" and is_instance_valid(battle):
		battle.audio.stop_all()
	get_tree().paused = true
	_open("pause", "已暂停", "")
	page.compact_height = 570.0
	page.set_width(760)
	page.status.hide()
	var content := preload("res://ui/scenes/pause_content.tscn").instantiate()
	page.body.add_child(content)
	if paused_route == "battle":
		var session := battle.session
		var kills := 0
		for enemy in session.enemies:
			if not enemy.alive():
				kills += 1
		content.get_node("Stats/Health").display(str(ceili(float(session.player_hp_q)/BattleSession.Q)))
		content.get_node("Stats/Kills").display(str(kills))
		content.get_node("Stats/Time").display("%02d:%02d" % [floori(session.elapsed/60.0), floori(fmod(session.elapsed,60.0))])
	else:
		content.get_node("Stats").hide()
	var actions := {"Vocabulary": _vocabulary_page, "Guide": _guide, "Settings": func() -> void: _settings_page("pause")}
	for node_name: String in actions:
		var button := content.get_node("Menu/" + node_name) as OpenButton
		button.set_motion_reduced(settings.reduce_motion)
		button.pressed.connect(actions[node_name])
		button.pressed.connect(func() -> void: sound.play_cue("ui.select"))
		button.mouse_entered.connect(func() -> void: sound.play_cue("ui.focus"))
		_bind_control_command(button, button._command_word)
	page.footer.alignment = BoxContainer.ALIGNMENT_END
	_button(page.footer, "结束本局", "quit", _confirm_quit)
	_button(page.footer, "继续战斗" if paused_route == "battle" else "继续习字", "resume", _resume)


func _confirm_quit() -> void:
	_open("quit", "合上此页", "结束后进入本局战报。" if paused_route == "battle" else "结束本次习字，返回书库。")
	page.compact_height = 330.0
	page.set_width(620)
	page.status.hide()
	_button(page.footer, "继续冒险", "cancel", _pause)
	_button(page.footer, "结束并结算" if paused_route == "battle" else "返回书库", "confirm", func() -> void:
		if paused_route == "battle":
			_resume()
			battle.session.queue_action(&"abandon")
		else:
			_home()
	)


func _resume() -> void:
	if paused_route == "battle" and is_instance_valid(battle):
		page.queue_free()
		page = null
		battle.show()
		battle.apply_options()
		route = "battle"
		commands.clear()
		get_tree().paused = false
		router.typing = battle.session.typing
		router.configure(InputRouter.Context.TYPING)
		return
	if not is_instance_valid(practice):
		return
	page.queue_free()
	page = practice
	practice.show()
	practice.refresh_options()
	route = "practice"
	commands.clear()
	get_tree().paused = false
	router.configure(InputRouter.Context.TYPING)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
