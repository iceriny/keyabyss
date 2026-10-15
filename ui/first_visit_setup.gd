class_name FirstVisitSetup
extends PageShell
## A bounded live encounter uses the same full-output battlefield as normal play.

signal settings_changed
signal completed

const LOOP_SECONDS := 24.0
const ENEMY_TYPES: Array[EnemyCombatDefinition] = [
	preload("res://game/content/enemies/quill.tres"),
	preload("res://game/content/enemies/wisp.tres"),
	preload("res://game/content/enemies/mortar.tres"),
]
const WORDS := ["amber", "bloom", "crystal", "dawn", "ember", "feather", "glimmer", "harbor", "ink", "jade", "kindle", "luminous", "moonlight", "night", "ocean", "petal", "quartz", "river", "silver", "thunder", "under", "velvet", "willow", "xenon", "yearn", "zephyr"]
const MEANINGS := ["琥珀", "绽放；花朵", "水晶；晶体", "黎明", "余烬", "羽毛", "微光", "港湾", "墨水", "玉石", "点燃", "发光的", "月光", "夜晚", "海洋", "花瓣", "石英", "河流", "银色的", "雷声", "在下方", "丝绒", "柳树", "氙", "渴望", "和风"]

var settings: AppSettings
var volume_slider: HSlider
var meaning_toggle: CheckButton
var quality_select: OptionButton
var fluid_select: OptionButton
var confirm_button: Button
var controls: Dictionary[String, Control] = {}
var fps: FpsDisplay
var preview: BattlePage
var preview_session: BattleSession
var _volume_value: Label
var _loop_age := 0.0
var _input_clock := 0.0
var _field_clock := 0.0
var _word_index := 0
var _letter_index := 0
var _typing_word := ""
var _preview_quality := -1
var _preview_fluid := -1
var _preview_reduced := false
@onready var _sample_audio: BattleAudio = $SampleAudio


static func create_setup(options: AppSettings) -> FirstVisitSetup:
	var page := load("res://ui/first_visit_setup.tscn").instantiate() as FirstVisitSetup
	page.settings = options
	page.reduced_motion = options.reduce_motion
	page.configure("让墨光恰到好处", "在启程之前，找到适合自己的声音与画面。")
	return page


func _ready() -> void:
	# Calibration owns an isolated encounter even when the real run is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	volume_slider = body.get_node("Volume/Slider")
	_volume_value = body.get_node("Volume/Heading/Value")
	meaning_toggle = body.get_node("Meaning")
	quality_select = body.get_node("Quality/Select")
	fluid_select = body.get_node("Fluid/Select")
	confirm_button = footer.get_node("Finish")
	controls = {"volume": volume_slider, "show_meaning": meaning_toggle, "quality": quality_select, "fluid_quality": fluid_select}
	for entry: Array in [[body.get_node("Volume/Heading/Title"), "volume"], [meaning_toggle, "translation"], [body.get_node("Quality/Title"), "effects"], [body.get_node("Fluid/Title"), "fluid"]]:
		var caption: Control = entry[0]
		var tag := CommandTag.create(entry[1])
		caption.add_child(tag)
		tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		tag.offset_left = -110
		tag.offset_right = -20
		tag.offset_top = -9
		tag.offset_bottom = 9
	for control in body.find_children("*", "Control", true, false):
		if control is Label or control is BaseButton:
			(control as Control).add_theme_font_override("font", PageShell.SMALL_FONT)
	fps = $ContentLayer/PreviewCaption/FpsDisplay
	for caption in ["低 · 轻盈", "中 · 均衡", "高 · 丰富"]: quality_select.add_item(caption)
	for caption in ["关闭", "低", "中", "高", "极高"]: fluid_select.add_item(caption)
	volume_slider.value_changed.connect(func(value: float) -> void:
		settings.volume = value
		_volume_value.text = "%d%%" % roundi(value * 100.0)
		settings_changed.emit())
	meaning_toggle.toggled.connect(func(value: bool) -> void:
		settings.show_meaning = value
		settings_changed.emit())
	quality_select.item_selected.connect(func(index: int) -> void:
		settings.quality = index
		settings_changed.emit())
	fluid_select.item_selected.connect(func(index: int) -> void:
		settings.fluid_quality = index
		settings_changed.emit())
	confirm_button.pressed.connect(func() -> void: completed.emit())
	close_button.hide()
	status.hide()
	command_hint.hide()
	visibility_changed.connect(_sync_preview_visibility)
	set_options()
	_build_preview()
	_layout_panel()


func set_options() -> void:
	if volume_slider == null: return
	volume_slider.set_value_no_signal(settings.volume)
	_volume_value.text = "%d%%" % roundi(settings.volume * 100.0)
	meaning_toggle.set_pressed_no_signal(settings.show_meaning)
	quality_select.select(settings.quality)
	fluid_select.select(settings.fluid_quality)
	reduced_motion = settings.reduce_motion
	(scroll as SmoothScroll).set_motion_reduced(reduced_motion)
	$ContentLayer/GoldBranch.set_motion_reduced(reduced_motion)
	$ContentLayer/GoldDivider.set_motion_reduced(reduced_motion)
	var graphics_changed := _preview_quality != settings.quality or _preview_fluid != settings.fluid_quality or _preview_reduced != settings.reduce_motion
	_preview_quality = settings.quality
	_preview_fluid = settings.fluid_quality
	_preview_reduced = settings.reduce_motion
	_sample_audio.enabled = settings.sound
	_sample_audio.effects_volume = settings.effects_volume
	if preview != null:
		preview.apply_options()
		preview.audio.enabled = false
		if graphics_changed: fps.restart_sampling(45)


func _build_preview() -> void:
	var entries: Array[VocabularyEntry] = []
	for index in WORDS.size(): entries.append(VocabularyEntry.new(WORDS[index], MEANINGS[index]))
	preview_session = BattleSession.new()
	preview_session.start_baseline(&"frost", entries, "hard", "first-visit-preview", false)
	preview_session.activate_god_mode()
	preview_session.player_position = Vector2(.53, .53)
	preview_session.previous_player_position = preview_session.player_position
	while preview_session.enemies.size() < 18:
		var index := preview_session.enemies.size()
		preview_session._spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], preview_session.player_position)
	# Spread this finite encounter across the backdrop, with real attacks and
	# collision processing. It has no progression or save repository attached.
	for index in preview_session.enemies.size():
		var enemy := preview_session.enemies[index]
		var angle := TAU * float(index) / preview_session.enemies.size()
		var ring := Vector2(270.0, 270.0) if index % 2 == 0 else Vector2(430.0, 365.0)
		enemy.position = preview_session.player_position + Vector2(cos(angle), sin(angle)) * ring / BattleSession.ARENA_SIZE
		enemy.previous_position = enemy.position
		enemy.combat_locked = true
		enemy.word_age = 1.0
		enemy.speed = 0.0
		enemy.stationary = true
		enemy.max_hp_q = 100000 * BattleSession.Q
		enemy.hp_q = enemy.max_hp_q
		enemy.attack_clock = .4 + index * .13
	preview_session._spawned = preview_session._room_quota
	preview = BattlePage.create(preview_session, settings, ArchiveHome.BOOKS[0])
	preview.name = "PressurePreview"
	preview.z_index = -30
	add_child(preview)
	move_child(preview, 0)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.hud.hide()
	preview.audio.enabled = false
	(preview.get_node("BattleCompass") as Control).hide()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in preview.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loop_age = 0.0
	_input_clock = .25
	_field_clock = 0.0
	_word_index = 0
	_letter_index = 0
	_typing_word = ""
	fps.restart_sampling(45)
	_sync_preview_visibility()


func _physics_process(delta: float) -> void:
	if preview == null or not is_visible_in_tree(): return
	_loop_age += delta
	if _loop_age >= LOOP_SECONDS:
		_release_preview()
		_build_preview()
		return
	_field_clock -= delta
	if _field_clock <= 0.0:
		_field_clock = 5.0
		preview_session.runtime._region(Vector2(.25, .31), 175.0, 4.8, &"cold_field")
		preview_session.runtime._region(Vector2(.73, .68), 155.0, 4.8, &"cold_field")
		preview_session.runtime._region(Vector2(.27, .73), 185.0, 4.8, &"fire_field")
		preview_session.runtime._region(Vector2(.78, .32), 165.0, 4.8, &"fire_field")
		# One familiar spell sound accompanies each field cycle. The dense enemy
		# demonstration stays quiet enough to judge the volume control itself.
		_sample_audio.play_input("cast.frost", size)
	_input_clock -= delta
	if _input_clock <= 0.0:
		_input_clock = .14
		var target := preview_session.enemies[_word_index % preview_session.enemies.size()]
		if _letter_index == 0:
			preview_session.typing.select_target(target.id)
			_typing_word = target.word
		preview_session.typing.feed(_typing_word[_letter_index])
		_letter_index += 1
		if _letter_index >= _typing_word.length():
			_letter_index = 0
			_word_index += 1


func _sync_preview_visibility() -> void:
	if preview == null: return
	var active := is_visible_in_tree() and not closing
	preview.process_mode = Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
	preview_session.process_mode = Node.PROCESS_MODE_INHERIT
	preview.stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	preview.visuals.fluid.set_active(active)
	if not active: _sample_audio.stop_all()
	if active: fps.restart_sampling(45)


func _release_preview() -> void:
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.stage.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	preview.visuals.fluid.set_active(false)
	remove_child(preview)
	preview.queue_free()
	preview = null
	preview_session = null


func dismiss() -> void:
	_sample_audio.stop_all()
	if preview != null: _release_preview()
	super.dismiss()


func _exit_tree() -> void:
	# Native descendants own their GPU teardown and disconnect their signals.
	if preview != null:
		preview.stage.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		preview.visuals.fluid.set_active(false)


func _layout_panel() -> void:
	panel.size = Vector2(520.0, minf(720.0, size.y - 112.0))
	panel.position = (size - panel.size) * .5
	pattern.position = panel.position + Vector2(-22, -26)
	pattern.modulate.a = .02
	$ContentLayer/GoldBranch.position = panel.position + Vector2((panel.size.x - 370.0) * .5, -6)
	$ContentLayer/GoldBranch.size = Vector2(370, 139)
	$ContentLayer/GoldDivider.position = panel.position + Vector2(12, panel.size.y - 128)
	$ContentLayer/GoldDivider.size = Vector2(panel.size.x - 60.0, 90)
	var caption := $ContentLayer/PreviewCaption as Control
	caption.position = Vector2(size.x * .57, 56.0)
	caption.size.x = size.x * .36
	if not reading_style.is_empty():
		_layout_reading_crystal()
