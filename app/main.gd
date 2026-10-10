class_name KeyabyssApp
extends Node
## Owns page navigation and services, while word progress belongs to TypingSession.

@onready var root: GameDisplay = $Interface/Root
@onready var router: InputRouter = $InputRouter
var settings := AppSettings.new()
var settings_prepared := false
var vocabulary := VocabularyRepository.new()
var page: PageShell
var practice: PracticePage
var battle: BattlePage
var departure: DepartureRitual
var route: String = "home":
	set(value):
		route = value
		if is_instance_valid(cursor):
			cursor.gameplay = value == "battle"
var paused_route: String = ""
var settings_return: String = "home"
var commands: Dictionary[String, Callable] = {}
@onready var archive: ArchiveHome = $Interface/Root/ArchiveHome
@onready var sound: ArchiveAudio = $ArchiveAudio
@onready var cursor: ArchiveCursor = $Interface/Root/Cursor
var archive_return: String = "home"
var presentation_enabled: bool = true
var welcome_gate: ArchiveGate
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
var profile_base_path: String = "user://profiles"
var profile_mode: StringName = &"normal"
var saves: SaveRepository
var profile: ProfileState
var run: RunSession
var god_enabled := false
var _restart_requested := false
var _history_detail: VBoxContainer


func _enter_tree() -> void:
	# Bootstrap already prepares this service; direct editor launches use it here.
	vocabulary.prepare_catalog()
	add_child(DebugLog.new())
	# Native preview uses an isolated user space prepared by godot.ps1 preview.
	# Inject services before the authored home scene enters its ready phase.
	get_tree().node_added.connect(_configure_new_control)
	if not settings_prepared:
		settings.load_settings()
	settings.apply(get_window())
	($Interface/Root as GameDisplay).settings = settings
	var home: ArchiveHome = $Interface/Root/ArchiveHome
	home.settings = settings
	home.repository = vocabulary


func _ready() -> void:
	_load_profile()
	get_tree().auto_accept_quit = false
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
	router.command_character.connect(func() -> void: sound.play_cue("ui.type"))
	router.command_rejected.connect(func() -> void: sound.play_cue("ui.invalid"))
	router.command_progress.connect(func(value: String) -> void:
		get_tree().call_group("open_motion_controls", "set_command_prefix", value)
		get_tree().call_group("word_command_tags", "set_command_prefix", value)
		for i in archive.cards.size():
			archive.cards[i].set_meta("command_match", not value.is_empty() and str(ArchiveHome.BOOKS[i].id).begins_with(value))
		archive.command_label.text = "›  %s▏" % value if not value.is_empty() else "›  输入词令"
		if is_instance_valid(page):
			if route in ["practice", "battle"]:
				page.command_hint.text = "Space 御术 · 方向 / Alt 闪避 · 单独松开 Shift 终式"
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
				&"menu_confirm": archive.set_prepared(true)
			return
		if route == "prepare" and action == &"menu_confirm":
			_launch_prepared()
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
		welcome_gate = gate
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
	print("Keyabyss ready | %s | %s" % [Engine.get_version_info()["string"], RenderingServer.get_current_rendering_method()])
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
		"quit": _quit_game()
		"battle": _launch_prepared()
		"profile": _profile_page()
		"relics": _relics_page()
		"history": _run_records()
		"prepared", "archive":
			route = "prepare" if destination == "prepared" else "home"
			if destination == "archive": _restart_requested = false
			if destination == "prepared" and run != null and run.has_pending_run() and not _restart_requested:
				_pending_run_page(false)
				return
			_configure_archive_commands()


func _configure_archive_commands() -> void:
	commands.clear()
	commands["back"] = func() -> void: archive.set_prepared(false)
	commands["vocab"] = _vocabulary_page
	commands["words"] = _vocabulary_page
	commands["help"] = _guide
	commands["guide"] = _guide
	commands["settings"] = func() -> void: _settings_page(route)
	commands["quit"] = _quit_game
	commands["profile"] = _profile_page
	commands["relics"] = _relics_page
	commands["history"] = _run_records
	if run != null and run.has_pending_run(): commands["continue"] = _resume_run
	if route == "home":
		commands["start"] = func() -> void: archive.set_prepared(true)
		for i in ArchiveHome.BOOKS.size():
			commands[str(ArchiveHome.BOOKS[i].id)] = func() -> void: archive.select_book(i)
			commands[str(i + 1)] = func() -> void: archive.select_book(i)
	elif route == "prepare":
		commands["start"] = _launch_prepared
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
		archive.set_prepared(true, false)


func _open(next_route: String, title: String, subtitle: String, audible: bool = true) -> void:
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
	if audible:
		sound.play_cue("ui.open")
	router.configure(InputRouter.Context.MENU)


func _button(parent: Node, caption: String, command: String, callback: Callable, cue: String = "") -> OpenButton:
	var button := PageShell.button(parent, "%s    %s" % [caption, command], callback)
	button.name = command.capitalize()
	button.set_motion_reduced(settings.reduce_motion)
	if not cue.is_empty():
		button.pressed.connect(func() -> void: sound.play_cue(cue))
	button.mouse_entered.connect(func() -> void: sound.play_cue("ui.focus"))
	_bind_control_command(button, command)
	router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
	return button


func _bind_control_command(control: Control, word: String) -> void:
	control.set_meta("word_command", word)
	if control is OptionButton and not control.has_meta("audio_bound"):
		control.set_meta("audio_bound", true)
		control.set_meta("audio_selected", control.selected)
		PopupCrystal.decorate(control, settings.reduce_motion)
		control.item_selected.connect(func(index: int) -> void:
			if index != int(control.get_meta("audio_selected")):
				control.set_meta("audio_selected", index)
				sound.play_cue("ui.tab"))
	if control is CheckButton or control is OptionButton or control is LineEdit:
		CrystalInlay.decorate(control, settings.reduce_motion, is_instance_valid(page) and page.is_ancestor_of(control))
	commands[word] = _activate_control.bind(control)


func _activate_control(control: Control) -> void:
	if is_instance_valid(page) and page.has_node("RewardDetail"):
		return
	if route == "settings" and is_instance_valid(control) and control.has_meta("settings_tab"):
		_select_settings_tab(str(control.get_meta("settings_tab")), false)
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
	if is_instance_valid(page) and page.has_node("RewardDetail"):
		if command == "back": _back()
		return
	if command == "imsuperman":
		_activate_god_mode()
		return
	if commands.has(command):
		commands[command].call()


func _home(audible: bool = true) -> void:
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
	archive.set_prepared(false, false)
	archive.refresh_vocabulary_choices()
	if returning and audible:
		sound.play_cue("ui.close")
	_configure_archive_commands()


func _back() -> void:
	if is_instance_valid(page) and page.has_node("RewardDetail"):
		_close_reward_detail()
		return
	match route:
		"reward", "reward_error", "settlement": pass
		"relics", "build":
			if run != null and run.phase in ["REWARD", "BATTLE_REWARD", "EVENT"]:
				_show_run_stage()
			else:
				_return_archive()
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
	var opened_page := page
	_catalog_button(page.footer, "返回", "back", _return_archive)
	if not get_tree().paused:
		commands["practice"] = _start_practice
	# Example commands remain available while their sections are being built.
	var requested_example := {"command": ""}
	for index in GuideContent.EXAMPLES.size():
		var command := "note-%02d" % (index + 1)
		commands[command] = func() -> void: requested_example.command = command
	router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
	var labels: Array[Dictionary] = []
	var rules: Array[Dictionary] = []
	var book := ArchiveHome.BOOKS[archive.selected]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.focus_mode = Control.FOCUS_NONE
	page.body.add_child(grid)
	page.body.theme_changed.connect(GuideContent._update_accents.bind(page.body, book.color, labels, rules))
	var build_started := Time.get_ticks_usec()
	for article: Dictionary in GuideContent.ARTICLES:
		GuideContent._add_article(grid, article, labels, rules)
		if Time.get_ticks_usec() - build_started >= 2000:
			GuideContent._update_accents(page.body, book.color, labels, rules)
			await get_tree().process_frame
			if not is_instance_valid(opened_page) or opened_page != page or not opened_page.visible:
				return
			build_started = Time.get_ticks_usec()
	var sections := VBoxContainer.new()
	GuideContent._add_demonstration(sections, labels, rules)
	GuideContent._add_practice(sections, rules, _start_practice)
	for button: OpenButton in sections.find_children("*", "OpenButton", true, false):
		button.defer_decoration = true
		button.set_motion_reduced(settings.reduce_motion)
	for section in sections.get_children():
		sections.remove_child(section)
		page.body.add_child(section)
	sections.free()
	for button: Button in page.body.find_children("*", "Button", true, false):
		if button is OpenButton and not button._command_word.is_empty():
			if get_tree().paused and button._command_word == "practice":
				button.disabled = true
				continue
			_bind_control_command(button, button._command_word)
	GuideContent._update_accents(page.body, book.color, labels, rules)
	if not requested_example.command.is_empty():
		commands[requested_example.command].call()


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
		var choice := _button(list, str(book.title), word_command, func() -> void:
			if selected_id != str(book.id):
				_show_vocabulary(str(book.id))
				sound.play_cue("ui.select"))
		choice.name = "V%02d" % (index + 1)
		choice.custom_minimum_size.y = 44
		choice.add_theme_font_size_override("font_size", 18)
	selected_id = settings.vocabulary_id
	if not catalog.any(func(book: Dictionary) -> bool: return str(book.id) == selected_id) and not catalog.is_empty():
		selected_id = str(catalog[0].id)
	_show_vocabulary(selected_id)
	_button(page.footer, "返回", "back", _return_archive)
	_button(page.footer, "导入词表", "import", _import_page)
	_button(page.footer, "使用词库", "use", _use_vocabulary)
	_button(page.footer, "导出", "export", _export_vocabulary, "ui.select")


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
	PageShell.label(vocab_detail, title, 25, Color("f0ddae"))
	var metadata := vocabulary.describe(id)
	PageShell.label(vocab_detail, str(metadata.get("description", "")), 16, Color("a8b6b4"))
	PageShell.label(vocab_detail, str(metadata.get("source", "")), 13, Color("82918c"))
	PageShell.label(vocab_detail, "%d 个可用词条%s" % [selected_entries.size(), " · 当前使用" if id == settings.vocabulary_id else ""], 18)
	var source := vocabulary.sync_source(id)
	if not source.is_empty():
		var source_id := str(source.id)
		var sync_button := _button(vocab_detail, "同步中…" if _syncing_source == source_id else "同步源词表", "sync", func() -> void: _sync_vocabulary(source_id), "ui.select")
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
	_button(page.footer, "选择文件", "file", _choose_file, "ui.select")
	_button(page.footer, "预览", "preview", _preview_import, "ui.select")
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
		sound.play_cue("ui.invalid")
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
	_select_settings_tab(settings_tab, false)
	_button(page.footer, "返回", "back", _settings_back)
	_button(page.footer, "恢复默认", "defaults", _defaults)
	page.status.text = "设置自动保存于本机"
	for control: Control in settings_controls.values():
		if control is CheckButton:
			control.toggled.connect(func(value: bool) -> void:
				var key: String = settings_controls.find_key(control)
				if settings.get(key) != value:
					sound.play_cue("ui.tab" if _save_settings() else "ui.invalid"))
		elif control is OptionButton:
			control.item_selected.connect(func(_index: int) -> void: _save_settings())


func _select_settings_tab(id: String, audible: bool = true) -> void:
	var changed := settings_tab != id
	settings_tab = id
	for key: String in _settings_groups:
		_settings_groups[key].visible = key == id
		_settings_tabs[key].set_pressed_no_signal(key == id)
		_settings_tabs[key].set_selected_visual(key == id)
	page.scroll.scroll_vertical = 0
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and not focused.is_visible_in_tree():
		focused.release_focus()
	if changed and audible:
		sound.play_cue("ui.tab")


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
	slider.drag_ended.connect(func(changed: bool) -> void:
		_persist_audio_settings()
		if changed and key == "effects_volume":
			sound.play_cue("ui.confirm"))
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
		elif control is OptionButton:
			control.set_meta("audio_selected", control.selected)
	for key: String in _volume_labels:
		_volume_labels[key].text = "%d%%" % roundi((settings_controls[key] as HSlider).value * 100)
	if _save_settings():
		page.status.text = "已恢复默认设置。"
		sound.play_cue("ui.confirm")
	else:
		sound.play_cue("ui.invalid")


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
	practice = PracticePage.create_practice(entries, settings, vocabulary.prepared_index(settings.vocabulary_id))
	practice.typing.character_judged.connect(func(_attempt: String, _word: String, correct: bool) -> void:
		sound.play_cue("ui.type" if correct else "ui.invalid"))
	practice.typing.feedback_requested.connect(func(cue: StringName) -> void:
		sound.play_cue("ui.tab" if cue == &"target" else "ui.close" if cue == &"cancel" else "ui.invalid"))
	practice.theme = _archive_theme
	practice.name = "Practice"
	root.add_child(practice)
	page = practice
	route = "practice"
	practice.set_width(1160)
	practice.close_button.pressed.connect(_pause)
	PageShell.button(practice.footer, "暂停    Esc", _pause)
	practice.command_hint.text = "Space 御术 · 方向 / Alt 闪避 · 单独松开 Shift 终式"
	router.typing = practice.typing
	router.configure(InputRouter.Context.TYPING)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _start_battle() -> void:
	if route == "departure":
		return
	var active_options: Dictionary = run.options if run != null and run.phase == "READY_FOR_ROOM" else {"vocabulary_id": settings.vocabulary_id, "minimum_length": settings.min_length, "maximum_length": settings.max_length}
	var entries := vocabulary.select_entries(PackedStringArray([str(active_options.vocabulary_id)]), int(active_options.minimum_length), int(active_options.maximum_length))
	if entries.is_empty():
		_vocabulary_page()
		page.status.text = "当前词库或词长范围不可用，请重新选择。"
		return
	if profile == null:
		archive.command_label.text = saves.last_error
		return
	if run != null and run.phase not in ["RESULT", "READY_FOR_ROOM"]:
		_resume_run()
		return
	if run == null or run.phase == "RESULT":
		run = RunSession.new(saves, profile)
		if not run.begin(StringName(settings.book_id), settings):
			archive.command_label.text = run.last_error
			return
		profile = run.profile
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
	departure.book = _run_book()
	departure.stage_text = "第 %d 章 · 第 %d 页" % [run.itinerary.chapter_of(run.room_serial + 1), run.room_serial % run.itinerary.rooms_per_chapter + 1]
	departure.reduced_motion = settings.reduce_motion
	departure.cue_requested.connect(sound.play_cue)
	departure.covered.connect(_enter_battle.bind(entries))
	departure.completed.connect(func() -> void:
		departure = null
		if not is_instance_valid(battle):
			_run_records()
			return
		route = "battle"
		battle.session.set_physics_process(true)
		router.typing = battle.session.typing
		router.configure(InputRouter.Context.TYPING)
		if DisplayServer.get_name() != "headless" and not get_window().has_focus():
			_pause()
	)
	root.add_child(departure)


func _launch_prepared() -> void:
	if run != null and run.has_pending_run():
		if not _restart_requested:
			_pending_run_page()
			return
		if not run.restart(StringName(settings.book_id), settings):
			if is_instance_valid(page): page.status.text = run.last_error
			else: archive.command_label.text = run.last_error
			return
		profile = run.profile
	_restart_requested = false
	_start_battle()


func _pending_run_page(audible: bool = true) -> void:
	_open("resume_run", "未完的远征", "", audible)
	page.compact_height = 650
	page.set_width(920)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 42)
	page.body.add_child(hero)
	var art := TextureRect.new()
	art.texture = _run_book().artwork
	art.custom_minimum_size = Vector2(250, 260)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(art)
	var description := VBoxContainer.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	description.add_theme_constant_override("separation", 18)
	hero.add_child(description)
	PageShell.label(description, _run_book().title, 28, Color("e8d4a4"))
	var next_room := mini(9, run.room_serial + (1 if run.phase in ["READY_FOR_ROOM", "REWARD"] else 0))
	PageShell.label(description, "%s · 第 %d 章 · 第 %d 页 · %d 件遗物" % [RunSession.DIFFICULTY_NAMES[RunSession.DIFFICULTIES.find(str(run.options.get("difficulty", "normal")))], run.itinerary.chapter_of(maxi(1, next_room)), (maxi(1, next_room) - 1) % run.itinerary.rooms_per_chapter + 1, run.selection.instances.size()], 18)
	PageShell.label(description, "继续这次远征，或重新出征。重开会归档当前远征并清空局内遗物。", 17, Color("9daea7"))
	_button(page.footer, "重新出征", "restart", func() -> void:
		_home()
		_restart_requested = true
		archive.set_prepared(true))
	_button(page.footer, "继续远征" if not bool(run.facts.get("victory_pending", false)) else "继续挑战", "continue", _resume_run)
	_button(page.footer, "返回书库", "back", _home)


func _resume_run() -> void:
	_restart_requested = false
	if is_instance_valid(battle) and battle.session.result == 0:
		if run.phase == "BATTLE_REWARD": _show_run_stage()
		else: _resume()
	elif run.phase == "READY_FOR_ROOM": _start_battle()
	elif bool(run.facts.get("victory_pending", false)): _continue_challenge()
	else: _show_run_stage()


func _activate_god_mode() -> void:
	if god_enabled: return
	var god_saves := SaveRepository.new(&"god", profile_base_path)
	if run != null and run.has_pending_run():
		var current_battle: BattleSession = battle.session if is_instance_valid(battle) and battle.session.result == 0 else null
		if not run.isolate_to_god(god_saves, current_battle):
			profile = run.profile
			if is_instance_valid(page):
				page.status.text = run.last_error
				page.status.show()
			else: archive.command_label.text = run.last_error
			return
		saves = run.repository
		profile = run.profile
		profile_mode = &"god"
		if current_battle == null:
			if not run.restore():
				if is_instance_valid(page): page.status.text = run.last_error
				return
			profile = run.profile
	else:
		profile_mode = &"god"
		_load_profile()
	god_enabled = true
	if is_instance_valid(battle) and battle.session.result == 0:
		battle.session.activate_god_mode()
		_pause()
	elif route in ["home", "prepare"]:
		_configure_archive_commands()
		archive.command_label.text = "God · 致死回满 · 无限终式与闪避"
	else:
		_home()
		archive.command_label.text = "God · 致死回满 · 无限终式与闪避"


func _enter_battle(entries: Array[VocabularyEntry]) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
	var session := BattleSession.new()
	session.name = "Session"
	var request := run.start_room(entries, vocabulary.prepared_index(str(run.options.vocabulary_id)))
	if request == null:
		session.free()
		_open("room_error", "未能进入书页", run.last_error)
		page.add_action("重试进入").pressed.connect(_start_battle)
		if is_instance_valid(departure):
			departure.release()
		return
	profile = run.profile
	request.god_mode = god_enabled
	session.start(request, run.combat)
	run.install_room_opening(session)
	battle = BattlePage.create(session, settings, _run_book())
	battle.theme = _archive_theme
	battle.name = "Battle"
	root.add_child(battle)
	session.set_physics_process(false)
	battle.pause_requested.connect(_pause)
	session.finished.connect(_battle_finished)
	session.progression_changed.connect(_progression_changed)
	archive.hide()
	archive.set_interactive(false)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	# The paid session remains stopped until its real viewport has drawn.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await get_tree().process_frame
	if is_instance_valid(departure):
		departure.release()


func _battle_finished(victory: bool) -> void:
	if not is_instance_valid(battle):
		return
	var session := battle.session
	var gained_level := false
	if run != null:
		var previous_level := TalentProgress.level_for(profile.manual_characters)
		if not run.finish_room(session):
			_open("settlement", "正在归档", run.last_error)
			_button(page.footer, "重试保存", "retry", _battle_finished.bind(victory))
			return
		profile = run.profile
		gained_level = TalentProgress.level_for(profile.manual_characters) > previous_level
		if gained_level:
			sound.play_cue("ui.level")
		if run.phase != "RESULT":
			_show_run_stage(not gained_level)
			return
	if not session.abandoned_run:
		battle.audio.play_result(victory, battle.size)
	_open("result", "墨迹 · 此页已明" if victory else ("归卷 · 重返书库" if session.abandoned_run else "墨尽 · 未完待续"), "", not gained_level)
	page.compact_height = 740.0
	page.set_width(960)
	page.heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.heading.add_theme_color_override("font_color", Color("dfc58b") if victory else (Color("9bb8c8") if session.abandoned_run else Color("d58f83")))
	page.pattern.hide()
	page.get_node("ContentLayer/GoldBranch").hide()
	page.status.hide()
	var report := load("res://ui/scenes/battle_result.tscn").instantiate() as BattleResult
	page.body.add_child(report)
	var vocabulary_title := str(run.options.get("vocabulary_id", settings.vocabulary_id)) if run != null else settings.vocabulary_id
	for entry: Dictionary in vocabulary.catalog():
		if str(entry.id) == vocabulary_title:
			vocabulary_title = str(entry.title)
			break
	report.configure(session, _run_book(), session.abandoned_run, run, vocabulary_title)
	for detail in [{"title": "战斗详情", "command": "stats"}, {"title": "此行构筑", "command": "build"}, {"title": "错词回顾", "command": "words"}]:
		var detail_index := report.detail_buttons.size()
		report.detail_buttons.append(_button(report.get_node("DetailTabs"), detail.title, detail.command, report.show_detail.bind(detail_index), "ui.select"))
	var atmosphere := preload("res://ui/scenes/outcome_atmosphere.tscn").instantiate() as OutcomeAtmosphere
	atmosphere.victory = victory
	atmosphere.reduced_motion = settings.reduce_motion or session.abandoned_run
	page.add_child(atmosphere)
	page.move_child(atmosphere, page.content_layer.get_index())
	page.footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_button(page.footer, "返回书库", "home", _home)
	_button(report.get_node("DetailSlot/Secondary"), "远征记录", "history", _run_records)
	_button(report.get_node("DetailSlot/Secondary"), "导出战报", "export", _export_battle_report.bind(report.report), "ui.select")
	if run != null and bool(run.facts.get("victory_pending", false)):
		_button(page.footer, "保留遗物 · 挑战" + run.next_challenge_label(), "continue", _continue_challenge)
		_button(page.footer, "结束远征", "finish", _end_challenge)
	_button(page.footer, "再写一局", "retry", func() -> void:
		_restart_requested = true
		_launch_prepared())
	if profile != null:
		report.report["profile_characters"] = profile.manual_characters


func _export_battle_report(report: Dictionary) -> void:
	var dialog := FileDialog.new()
	dialog.use_native_dialog = true
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; 战报"])
	dialog.current_file = "keyabyss-report-%s.json" % Time.get_date_string_from_system()
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			page.status.text = "战报保存失败：%s" % error_string(FileAccess.get_open_error())
			page.status.show()
		else:
			file.store_string(JSON.stringify(report, "\t"))
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.7)


func _load_profile() -> void:
	saves = SaveRepository.new(profile_mode, profile_base_path)
	profile = saves.load_profile()
	if profile != null:
		run = RunSession.new(saves, profile)
		if run.restore():
			profile = run.profile
		else:
			profile.diagnostics.append(run.last_error)


func _run_book() -> BookPresentation:
	for book in ArchiveHome.BOOKS:
		if book.id == run.selection.book_id: return book
	return ArchiveHome.BOOKS[archive.selected]


func _continue_challenge() -> void:
	if not run.continue_challenge():
		page.status.text = run.last_error
		sound.play_cue("ui.invalid")
		return
	profile = run.profile
	sound.play_cue("ui.confirm")
	_start_battle()


func _end_challenge() -> void:
	if not run.end_challenge():
		page.status.text = run.last_error
		sound.play_cue("ui.invalid")
		return
	profile = run.profile
	_home()


func _profile_page() -> void:
	if is_instance_valid(battle) and battle.session.result == 0:
		return
	_open("profile", "留痕", "每一次落笔，都留下痕迹")
	page.compact_height = 730
	page.set_width(1040)
	if profile == null:
		page.status.text = saves.last_error
		return
	var growth := TalentProgress.level_for(profile.manual_characters)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 40)
	page.body.add_child(hero)
	var emblem := JourneyEmblem.new()
	emblem.kind = &"growth"
	emblem.progress = float(growth) / TalentProgress.MAX_LEVEL
	emblem.custom_minimum_size = Vector2(220, 220)
	hero.add_child(emblem)
	var progress_body := VBoxContainer.new()
	progress_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_body.add_theme_constant_override("separation", 18)
	hero.add_child(progress_body)
	PageShell.label(progress_body, "%s  累计正确输入" % ("GOD ·" if god_enabled else ""), 14, Color("94aaa5"))
	PageShell.label(progress_body, "%s" % profile.manual_characters, 54, Color("ead8ac"))
	PageShell.label(progress_body, "初始生命 +%d     ·     留痕 %d / %d" % [TalentProgress.health_for(profile.manual_characters), growth, TalentProgress.MAX_LEVEL], 20)
	var track := ProgressBar.new()
	track.custom_minimum_size.y = 4
	track.show_percentage = false
	track.max_value = TalentProgress.CHARACTERS_PER_LEVEL
	track.value = float(profile.manual_characters % TalentProgress.CHARACTERS_PER_LEVEL) if growth < TalentProgress.MAX_LEVEL else track.max_value
	progress_body.add_child(track)
	PageShell.label(progress_body, "距下一阶 %d 字符" % [(growth + 1) * TalentProgress.CHARACTERS_PER_LEVEL - profile.manual_characters] if growth < TalentProgress.MAX_LEVEL else "五阶已满，落笔仍会记录。", 16, Color("a2b6ae"))
	var milestones := HBoxContainer.new()
	milestones.add_theme_constant_override("separation", 20)
	page.body.add_child(milestones)
	for index in TalentProgress.MAX_LEVEL:
		var mark := VBoxContainer.new()
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		milestones.add_child(mark)
		var lit := growth > index
		PageShell.label(mark, "+%d 生命" % ((index + 1) * TalentProgress.HP_PER_LEVEL), 19, Color("dcc89a") if lit else Color("7b8c89")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PageShell.label(mark, "%d 字符" % ((index + 1) * TalentProgress.CHARACTERS_PER_LEVEL), 13, Color("889b94")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PageShell.label(page.body, "四书共享 · 每 1000 正确字符增加 4 点初始生命 · 在新远征开始时生效", 15, Color("9caaa3")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(page.footer, "远征记录", "history", _run_records)
	_button(page.footer, "返回书库", "back", _home)


func _progression_changed() -> void:
	var started := DebugLog.begin()
	_observe_battle_progression()
	DebugLog.end(&"battle.progression", started)


func _observe_battle_progression() -> void:
	if run == null or not is_instance_valid(battle):
		return
	var previous_level := TalentProgress.level_for(profile.manual_characters)
	if not run.observe_battle(battle.session):
		_open("reward_error", "奖励暂未保存", run.last_error)
		_button(page.footer, "重试保存", "retry", _progression_changed)
		return
	profile = run.profile
	var gained_level := TalentProgress.level_for(profile.manual_characters) > previous_level
	if gained_level:
		sound.play_cue("ui.level")
	if run.phase == "BATTLE_REWARD":
		_show_run_stage(not gained_level)


func _show_run_stage(audible: bool = true) -> void:
	if run.phase == "READY_FOR_ROOM":
		_start_battle()
		return
	if run.phase in ["REWARD", "BATTLE_REWARD"]:
		_open("reward", "选择遗物", "选择一件带走 · 还可领取 %d 件" % run.rewards.available(), audible)
		page.set_width(1320.0)
		page.close_button.disabled = true
		var choices := HBoxContainer.new()
		choices.name = "RewardChoices"
		choices.add_theme_constant_override("separation", 26)
		page.body.add_child(choices)
		for id: String in run.offer.candidates:
			var definition := run.compiler.catalog.get_definition(StringName(id))
			var choice := preload("res://ui/scenes/relic_reward_choice.tscn").instantiate() as RelicRewardChoice
			choice.definition = definition
			choice.reduced_motion = settings.reduce_motion
			choice.shortcut = str(run.offer.candidates.find(id) + 1)
			choices.add_child(choice)
			var column := choice.content
			var parent: OptionButton
			if definition.replaces != &"":
				parent = OptionButton.new()
				parent.focus_mode = Control.FOCUS_NONE
				for instance in run.selection.instances:
					if instance.content_id == definition.replaces:
						parent.add_item(_instance_caption(instance))
						parent.set_item_metadata(parent.item_count - 1, instance.instance_id)
				column.add_child(parent)
			var take := _button(column, "取得", "take" + str(run.offer.candidates.find(id) + 1), _choose_reward.bind(StringName(id), str(run.offer.id), parent))
			commands[str(run.offer.candidates.find(id) + 1)] = take.pressed.emit
			take.add_theme_font_size_override("font_size", 21)
			choice.picked.connect(take.pressed.emit)
			var details := OpenButton.new()
			details.text = "查看详情"
			details.pressed.connect(_show_reward_detail.bind(definition))
			column.add_child(details)
		_reward_companion()
		_button(page.footer, "查看遗物", "relics", _relics_page)
		if run.offer.candidates.is_empty():
			PageShell.label(page.body, "当前可用遗物已满层。领取补给：恢复 25 点生命，补充一次闪避。", 22)
			_button(page.footer, "领取补给", "supply", func() -> void:
				var session: BattleSession = battle.session if is_instance_valid(battle) and battle.session.result == 0 else null
				if run.supply_reward(str(run.offer.id), session):
					profile = run.profile
					sound.play_cue("ui.supply")
					_resume_reward_or_stage(false)
				else:
					page.status.text = run.last_error
					sound.play_cue("ui.invalid"))
		var reroll := _button(page.footer, "重抽 · 剩余 %d 次" % int(run.facts.get("rerolls", 0)), "reroll", func() -> void:
			if run.reroll_reward(str(run.offer.id)):
				profile = run.profile
				sound.play_cue("ui.reroll")
				_show_run_stage(false)
			else:
				page.status.text = run.last_error
				sound.play_cue("ui.invalid"))
		reroll.disabled = int(run.facts.get("rerolls", 0)) <= 0 or run.offer.candidates.is_empty()
		_button(page.footer, "放弃本次奖励", "skip", func() -> void:
			if run.skip_reward(str(run.offer.id)):
				profile = run.profile
				sound.play_cue("ui.close")
				_resume_reward_or_stage(false)
			else:
				page.status.text = run.last_error
				sound.play_cue("ui.invalid"))
	else:
		_open("route", "行间", "下一页，选择如何继续。", audible)
		page.set_width(1080)
		page.compact_height = 840
		var path := HBoxContainer.new()
		path.add_theme_constant_override("separation", 14)
		page.body.add_child(path)
		for index in run.itinerary.encounters.size():
			var marker := PageShell.label(path, "%d章·%d页%s" % [run.itinerary.chapter_of(index + 1), index % run.itinerary.rooms_per_chapter + 1, "\n守关" if (index + 1) % run.itinerary.rooms_per_chapter == 0 else ""], 15, Color("d8c397") if index < run.room_serial else Color("647f7a"))
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var maximum_hp := ceili(run.compiler.compile(run.selection).build.maximum_hp_q() / 1024.0)
		var hp := ceili(float(run.combat.hp_q) / 1024.0)
		PageShell.label(page.body, "第 %d 章 · 第 %d 页已完成       生命 %d / %d       持有 %d 件遗物" % [run.itinerary.chapter_of(run.room_serial), (run.room_serial - 1) % run.itinerary.rooms_per_chapter + 1, hp, maximum_hp, run.selection.instances.size()], 16, Color("afc0b5")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var paths := HBoxContainer.new()
		paths.add_theme_constant_override("separation", 70)
		page.body.add_child(paths)
		_route_choice(paths, &"rest", "休息", "生命已满" if hp >= maximum_hp else "恢复 %d 点生命" % mini(20, maximum_hp - hp), "让墨息平稳，再写下一页。", "1", "rest", false)
		_route_choice(paths, &"offering", "献血", "付出 15 点生命 · 选择一件遗物", "生命需多于 15 点" if hp <= 15 else "以此刻的余力，换取更强的构筑。", "2", "offering", hp <= 15)
		_button(page.footer, "直接进入下一页", "next", _next_room)
		_button(page.footer, "保存并返回书库", "home", _home)


func _route_choice(parent: HBoxContainer, kind: StringName, title: String, benefit: String, note: String, number: String, command: String, unavailable: bool) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	parent.add_child(column)
	var emblem := JourneyEmblem.new()
	emblem.kind = kind
	emblem.custom_minimum_size.y = 180
	column.add_child(emblem)
	PageShell.label(column, title, 29, Color("e4cf9f")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PageShell.label(column, benefit, 19).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PageShell.label(column, note, 15, Color("92a69e")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var action_center := CenterContainer.new()
	column.add_child(action_center)
	var action := _button(action_center, "选择 · " + number, command, _choose_route.bind(command))
	action.disabled = unavailable
	column.mouse_filter = Control.MOUSE_FILTER_STOP
	column.mouse_default_cursor_shape = Control.CURSOR_ARROW if unavailable else Control.CURSOR_POINTING_HAND
	column.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not action.disabled:
			column.accept_event()
			action.pressed.emit())
	column.mouse_entered.connect(func() -> void:
		if not unavailable:
			emblem.tint = Color("f0d9a1")
			emblem.queue_redraw())
	column.mouse_exited.connect(func() -> void:
		emblem.tint = Color("ccb887")
		emblem.queue_redraw())
	commands[number] = func() -> void:
		if not action.disabled: action.pressed.emit()


func _show_reward_detail(definition: CombatContentDefinition) -> void:
	if page.get_node_or_null("RewardDetail") != null:
		return
	var detail := PageShell.create(definition.title, "遗物效果与取得条件")
	detail.name = "RewardDetail"
	detail.theme = _archive_theme
	detail.reduced_motion = settings.reduce_motion
	detail.accent = archive.accent
	detail.compact_height = 690
	page.add_child(detail)
	detail.set_width(740)
	detail.command_hint.text = "Esc 返回"
	PageShell.label(detail.body, ContentDescription.text(definition, run.compiler.catalog), 21)
	detail.close_button.pressed.connect(_close_reward_detail)
	PageShell.button(detail.footer, "关闭详情", _close_reward_detail)
	sound.play_cue("ui.open")


func _close_reward_detail() -> void:
	var detail := page.get_node_or_null("RewardDetail")
	if detail == null or detail.is_queued_for_deletion():
		return
	detail.queue_free()
	sound.play_cue("ui.close")


func _reward_companion() -> void:
	var companion := HBoxContainer.new()
	companion.name = "CurrentBuild"
	companion.add_theme_constant_override("separation", 30)
	companion.custom_minimum_size.y = 148
	page.body.add_child(companion)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/books/%s.png" % run.selection.book_id)
	art.custom_minimum_size = Vector2(126, 146)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color(0.8, 0.9, 0.9, 0.8)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	companion.add_child(art)
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 234
	vitals.add_theme_constant_override("separation", 9)
	companion.add_child(vitals)
	PageShell.label(vitals, ContentDescription.BOOKS[str(run.selection.book_id)], 22, Color("bdc4b5"))
	var hp: int = battle.session.player_hp_q if is_instance_valid(battle) else int(run.combat.hp_q)
	var maximum_hp: int = battle.session.player_max_hp_q if is_instance_valid(battle) else run.compiler.compile(run.selection).build.maximum_hp_q()
	PageShell.label(vitals, "生命 %d / %d" % [ceili(hp / 1024.0), ceili(maximum_hp / 1024.0)], 17, Color("a2b2a5"))
	var health := ProgressBar.new()
	health.custom_minimum_size.y = 4
	health.max_value = maximum_hp
	health.value = hp
	health.show_percentage = false
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(health)
	var shield: int = battle.session.run_state.shield_q if is_instance_valid(battle) else int(run.combat.shield_q)
	PageShell.label(vitals, "护盾 %d" % ceili(shield / 1024.0), 17, Color("a2b4bd"))
	var owned := VBoxContainer.new()
	owned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	companion.add_child(owned)
	PageShell.label(owned, "已持有的遗物", 17, Color("94a59e"))
	var names: PackedStringArray = []
	for instance in run.selection.instances:
		names.append(run.compiler.catalog.get_definition(instance.content_id).title)
	PageShell.label(owned, "、".join(names) if not names.is_empty() else "尚未取得遗物", 17, Color("8c9f97"))


func _choose_route(choice: String) -> void:
	if not run.take_route(choice):
		page.status.text = run.last_error
		sound.play_cue("ui.invalid")
		return
	profile = run.profile
	sound.play_cue("ui.route")
	_show_run_stage(false)


func _instance_caption(instance: CombatAssetInstance) -> String:
	return run.compiler.catalog.get_definition(instance.content_id).title


func _relics_page(owned_only: bool = false) -> void:
	_open("build" if owned_only else "relics", "当前构筑" if owned_only else "遗物图鉴", "本次远征已取得的遗物" if owned_only else "查看效果、叠层与局内前置")
	page.set_width(1120)
	page.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var search := LineEdit.new()
	search.placeholder_text = "搜索遗物名称"
	search.focus_mode = Control.FOCUS_CLICK
	page.body.add_child(search)
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 40)
	page.body.add_child(workspace)
	var list_scroll := SmoothScroll.new()
	list_scroll.custom_minimum_size.x = 320
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list_scroll.add_child(list)
	workspace.add_child(list_scroll)
	var detail_scroll := SmoothScroll.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(detail_scroll)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 18)
	detail_scroll.add_child(detail)
	var compiler := run.compiler if run != null else BuildCompiler.new()
	var catalog := compiler.catalog
	var acquisition := AcquisitionService.new(compiler)
	var glyph := RelicGlyph.new()
	glyph.custom_minimum_size = Vector2(100, 100)
	detail.add_child(glyph)
	var title := PageShell.label(detail, "", 26, Color("dfc58b"))
	var description := PageShell.label(detail, "", 18)
	var eligibility := PageShell.label(detail, "", 17)
	eligibility.visible = not owned_only
	var ownership := PageShell.label(detail, "", 18)
	var current := {"id": &""}
	var select := func(id: StringName) -> void:
		if current.id == id:
			return
		if current.id != &"":
			sound.play_cue("ui.select")
		current.id = id
		var definition := catalog.get_definition(id)
		glyph.definition = definition
		glyph.queue_redraw()
		title.text = definition.title
		description.text = ContentDescription.text(definition, catalog)
		var chosen := run.selection if run != null and run.phase != "RESULT" else BuildSelection.new()
		if run == null or run.phase == "RESULT":
			chosen.book_id = StringName(settings.book_id)
		var context := run.acquisition_context() if run != null else {"shortest": settings.min_length, "longest": settings.max_length}
		if not owned_only:
			var qualification := acquisition.evaluate(chosen, id, context)
			eligibility.text = "当前可取得" if qualification.eligible else ContentDescription.diagnostics(qualification.diagnostics, catalog)
		var count := 0
		for instance in chosen.instances:
			if instance.content_id == id: count += 1
		ownership.text = "本局持有 %d 层" % count
		ownership.visible = count > 0
	var buttons: Array[Button] = []
	var first_id: StringName = &""
	var listed: Array[StringName] = []
	var owned: Dictionary[StringName, int] = {}
	if run != null:
		for instance in run.selection.instances:
			owned[instance.content_id] = owned.get(instance.content_id, 0) + 1
	for id: String in AcquisitionService.ACTIVE_RELICS:
		if owned_only and owned.get(StringName(id), 0) <= 0: continue
		if first_id == &"": first_id = StringName(id)
		listed.append(StringName(id))
		# Commands select details immediately, including rows not instantiated yet.
		commands["relic" + str(listed.size())] = select.bind(StringName(id))
	search.text_changed.connect(func(query: String) -> void:
		for button in buttons:
			button.visible = query.is_empty() or str(button.get_meta("relic_title")).contains(query))
	if first_id != &"": select.call(first_id)
	else: PageShell.label(detail, "尚未取得遗物。击败敌人积累经验，获得三选一机会。", 18, Color("acbab2"))
	_catalog_button(page.footer, "返回", "back", _back)
	router.configure(InputRouter.Context.MENU, PackedStringArray(commands.keys()))
	var opened_page := page
	var build_started := Time.get_ticks_usec()
	for index in listed.size():
		var definition := catalog.get_definition(listed[index])
		var caption := definition.title + (" ×%d" % owned.get(listed[index], 0) if owned_only else "")
		var button := _catalog_button(list, caption, "relic" + str(index + 1), select.bind(listed[index]))
		button.set_meta("relic_title", definition.title)
		button.visible = search.text.is_empty() or definition.title.contains(search.text)
		buttons.append(button)
		if Time.get_ticks_usec() - build_started >= 2000 and index + 1 < listed.size():
			await get_tree().process_frame
			if not is_instance_valid(opened_page) or opened_page != page or not opened_page.visible:
				return
			build_started = Time.get_ticks_usec()


func _catalog_button(parent: Node, caption: String, command: String, callback: Callable) -> OpenButton:
	var button := OpenButton.new()
	button.text = "%s    %s" % [caption, command]
	button.defer_decoration = true
	button.pressed.connect(callback)
	button.name = command.capitalize()
	button.set_motion_reduced(settings.reduce_motion)
	button.mouse_entered.connect(func() -> void: sound.play_cue("ui.focus"))
	var scroll_parent := parent.get_parent()
	if scroll_parent is ScrollContainer:
		# A newly built row receives its final rectangle in the queued container sort.
		button.pressed.connect(scroll_parent.ensure_control_visible.bind(button), CONNECT_DEFERRED)
	_bind_control_command(button, command)
	parent.add_child(button)
	return button


func _choose_reward(id: StringName, offer_id: String, parent: OptionButton) -> void:
	var session: BattleSession = battle.session if is_instance_valid(battle) and battle.session.result == 0 else null
	var parent_id := str(parent.get_selected_metadata()) if parent != null else ""
	if not run.take_reward(id, offer_id, parent_id, session):
		page.status.text = run.last_error
		sound.play_cue("ui.invalid")
		return
	profile = run.profile
	sound.play_cue("ui.reward")
	_resume_reward_or_stage(false)


func _resume_reward_or_stage(audible: bool = true) -> void:
	if run.phase == "BATTLE":
		page.queue_free()
		page = null
		route = "battle"
		battle.show()
		battle.session.set_physics_process(true)
		router.typing = battle.session.typing
		router.configure(InputRouter.Context.TYPING)
	else:
		_show_run_stage(audible)


func _next_room() -> void:
	if not run.leave_route():
		page.status.text = run.last_error
		sound.play_cue("ui.invalid")
		return
	profile = run.profile
	sound.play_cue("ui.route")
	_start_battle()


func _run_records() -> void:
	_open("history", "远征记录", "已经归卷的旅程")
	page.set_width(1140)
	page.compact_height = 820
	page.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if profile == null:
		page.status.text = saves.last_error
		return
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 45)
	page.body.add_child(workspace)
	var list_scroll := SmoothScroll.new()
	list_scroll.custom_minimum_size.x = 310
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list_scroll.add_child(list)
	var detail_scroll := SmoothScroll.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(detail_scroll)
	_history_detail = VBoxContainer.new()
	_history_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_detail.add_theme_constant_override("separation", 20)
	detail_scroll.add_child(_history_detail)
	var record_index := 0
	var records := profile.records.duplicate()
	records.reverse()
	for record in records:
		record_index += 1
		var book_title := BuildCatalog.new().get_definition(StringName(record.book)).title
		var action := _button(list, "%02d · %s" % [records.size() - record_index + 1, book_title], "entry%d" % record_index, _record_detail.bind(record))
		action.add_theme_font_size_override("font_size", 18)
		PageShell.label(list, "%s · %d 页" % [_result_name(record), int(record.rooms)], 14, Color("92a69f"))
	if not records.is_empty(): _record_detail(records[0], false)
	else:
		var emblem := JourneyEmblem.new()
		emblem.kind = &"growth"
		emblem.custom_minimum_size.y = 210
		_history_detail.add_child(emblem)
		PageShell.label(_history_detail, "这里还没有归卷的远征", 25, Color("ddc79b"))
		PageShell.label(_history_detail, "远征结束后，法书、遗物与行间选择会留在这里。", 17, Color("a0b1a8"))
	_button(page.footer, "返回书库", "back", _home)


func _result_name(record: Dictionary) -> String:
	return {"victory": "通关", "defeat": "战败", "abandon": "主动结束", "interrupted": "中断", "incompatible": "旧远征"}.get(str(record.reason), str(record.reason))


func _record_detail(record: Dictionary, audible: bool = true) -> void:
	if _history_detail.get_meta("record", {}) == record:
		return
	_history_detail.set_meta("record", record)
	if audible:
		sound.play_cue("ui.select")
	for child in _history_detail.get_children():
		_history_detail.remove_child(child)
		child.queue_free()
	var book := BuildCatalog.new().get_definition(StringName(record.book))
	PageShell.label(_history_detail, book.title, 30, Color("e4ce9b"))
	PageShell.label(_history_detail, "%s   ·   %d 页   ·   %d 正确字符" % [_result_name(record), int(record.rooms), int(record.get("characters", 0))], 18)
	var mode := str(record.get("difficulty", "normal"))
	PageShell.label(_history_detail, "%s · 第 %d 周目" % [RunSession.DIFFICULTY_NAMES[RunSession.DIFFICULTIES.find(mode)], int(record.get("loop", 0)) + 1], 15, Color("94aba3"))
	PageShell.label(_history_detail, "随行遗物", 21, Color("d8c496"))
	var build: Dictionary = record.get("build", {})
	var assets: Dictionary = build.get("assets", {}).duplicate()
	if not build.get("instances", []).is_empty():
		assets.clear()
		for instance: Dictionary in build.instances:
			var id := str(instance.content_id)
			assets[id] = int(assets.get(id, 0)) + 1
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 20)
	_history_detail.add_child(grid)
	for id in assets:
		var definition := BuildCatalog.new().get_definition(StringName(id))
		if definition == null: continue
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var glyph := RelicGlyph.new()
		glyph.definition = definition
		glyph.custom_minimum_size = Vector2(120, 65)
		cell.add_child(glyph)
		PageShell.label(cell, "%s ×%d" % [definition.title, int(assets[id])], 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if assets.is_empty(): PageShell.label(_history_detail, "未携带遗物", 16, Color("91a69b"))
	PageShell.label(_history_detail, "行间足迹", 21, Color("d8c496"))
	for item: Dictionary in record.get("routes", []):
		PageShell.label(_history_detail, "%02d  ─  %s" % [int(item.room), {"continue": "前行", "rest": "休息", "offering": "献血换取遗物"}.get(str(item.choice), str(item.choice))], 16)
	if record.get("routes", []).is_empty():
		PageShell.label(_history_detail, "尚未经过行间", 16, Color("91a69b"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


func _quit_game() -> void:
	if run != null and is_instance_valid(battle) and battle.session.result == 0:
		if not profile.run_checkpoint.get("facts", {}).has("god_transfer") and not run.suspend_battle(battle.session):
			if is_instance_valid(page):
				page.status.text = run.last_error
				page.status.show()
			return
		profile = run.profile
	get_tree().quit()


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
		content.get_node("Stats/Level").display(str(run.rewards.level))
	else:
		content.get_node("Stats").hide()
	var actions := {"Build": func() -> void: _relics_page(true), "Codex": _relics_page, "Guide": _guide, "Settings": func() -> void: _settings_page("pause")}
	for node_name: String in actions:
		var button := content.get_node("Menu/" + node_name) as OpenButton
		button.set_motion_reduced(settings.reduce_motion)
		button.pressed.connect(actions[node_name])
		button.mouse_entered.connect(func() -> void: sound.play_cue("ui.focus"))
		_bind_control_command(button, button._command_word)
	page.footer.alignment = BoxContainer.ALIGNMENT_END
	_button(page.footer, "结束并返回书库", "quit", _end_current_run)
	_button(page.footer, "继续战斗" if paused_route == "battle" else "继续习字", "resume", _resume)


func _end_current_run() -> void:
	var gained_level := false
	if paused_route == "battle":
		var previous_level := TalentProgress.level_for(profile.manual_characters)
		if not run.end_run(battle.session):
			page.status.show()
			page.status.text = run.last_error
			sound.play_cue("ui.invalid")
			return
		profile = run.profile
		gained_level = TalentProgress.level_for(profile.manual_characters) > previous_level
		if gained_level:
			sound.play_cue("ui.level")
	_home(not gained_level)


func _resume() -> void:
	if profile.run_checkpoint.get("facts", {}).has("god_transfer"):
		page.status.show()
		page.status.text = "档案接管尚未完成，请重新输入激活词令重试。"
		sound.play_cue("ui.invalid")
		return
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
		sound.play_cue("ui.close")
		return
	if not is_instance_valid(practice):
		sound.play_cue("ui.invalid")
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
	sound.play_cue("ui.close")
