class_name PracticePage
extends PageShell
## A real word practice session; it does not grant persistent combat progress.

const DEFAULT_PROMPT := "输入任意词咒的首字母，或用鼠标选择。"

var typing := TypingSession.new()
var entries: Array[VocabularyEntry] = []
var active: Dictionary[StringName, VocabularyEntry] = {}
var word_labels: Dictionary[StringName, RichTextLabel] = {}
var settings: AppSettings
var completed_words: int = 0
var manual_characters: int = 0
var _generation: int = 0
var _words: VBoxContainer
var _stats: Label
var _meanings: Array[Label] = []
var _rng := RandomNumberGenerator.new()
var _sampler: VocabularySampler
var _shortest_length := 1


static func create_practice(source: Array[VocabularyEntry], options: AppSettings, prepared: VocabularyIndex) -> PracticePage:
	var scene := load("res://ui/scenes/practice_page.tscn") as PackedScene
	var page := scene.instantiate() as PracticePage
	page._sampler = VocabularySampler.new(prepared)
	page._configure_practice(source, options)
	return page


func _configure_practice(source: Array[VocabularyEntry], options: AppSettings) -> void:
	configure("习字", "首字母锁定词咒 · 正确字符逐字落笔")
	entries = source
	settings = options
	_shortest_length = settings.min_length
	while _shortest_length < settings.max_length and _sampler.index.count(0, settings.min_length, _shortest_length) == 0:
		_shortest_length += 1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_stats = body.get_node("Stats")
	_words = body.get_node("Words")
	var keys := KeyHint.create_row([{ "key": "Tab", "description": "切换" }, { "key": "⌫", "description": "放弃" }, { "key": "Esc", "description": "暂停" }])
	body.add_child(keys)
	body.move_child(keys, 2)
	typing.changed.connect(_refresh)
	typing.completed.connect(_completed)
	_next_words()


func _physics_process(_delta: float) -> void:
	for _receipt in typing.drain_receipts():
		manual_characters += 1
	_stats.text = "完成 %d 词    ·    亲手输入 %d 字符    ·    错字 %d" % [completed_words, manual_characters, typing.mistakes]


func _next_words() -> void:
	for child in _words.get_children():
		_words.remove_child(child)
		child.queue_free()
	active.clear()
	word_labels.clear()
	_meanings.clear()
	var targets: Dictionary[StringName, String] = {}
	var upper := settings.max_length
	if settings.progressive:
		upper = mini(upper, maxi(_shortest_length, settings.min_length + 3 + floori(completed_words / 5.0)))
	for slot in 3:
		_generation += 1
		var id := StringName("word_%d" % _generation)
		var chosen := _sampler.take(id, _rng, settings.min_length, upper)
		if chosen == null: break
		active[id] = chosen
		targets[id] = chosen.word
		var row := VBoxContainer.new()
		_words.add_child(row)
		var word_label := RichTextLabel.new()
		word_label.name = str(id)
		word_label.bbcode_enabled = true
		word_label.fit_content = true
		word_label.scroll_active = false
		word_label.custom_minimum_size.y = 70
		word_label.add_theme_font_override("normal_font", SMALL_FONT)
		word_label.add_theme_font_size_override("normal_font_size", 46)
		word_label.mouse_filter = Control.MOUSE_FILTER_STOP
		word_label.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var changed := typing.target_id != id or typing.progress > 0
				typing.select_target(id)
				if changed:
					typing.feedback_requested.emit(&"target")
		)
		row.add_child(word_label)
		word_labels[id] = word_label
		var meaning := label(row, chosen.meaning, 26, Color("aab9c2"))
		meaning.visible = settings.show_meaning
		_meanings.append(meaning)
	typing.set_targets(targets)


func _completed(id: StringName, _count: int, _assisted: bool, _attempt_id: String) -> void:
	completed_words += 1
	active.erase(id)
	_sampler.release(id)
	word_labels[id].text = "[color=#aab9c2]已完成[/color]"
	if active.is_empty():
		call_deferred("_next_words")


func _refresh() -> void:
	for id: StringName in active:
		var word := active[id].word
		if id == typing.target_id:
			var boundary := typing.display_boundary()
			word_labels[id].text = "[color=#8bdeff]%s[/color][color=#e8e4d8]%s[/color]  [color=#c9ae72]·[/color]" % [word.left(boundary), word.substr(boundary)]
		else:
			word_labels[id].text = "[color=#aab9c2]%s[/color]" % word
	status.text = typing.last_feedback if not typing.last_feedback.is_empty() else DEFAULT_PROMPT


func show_action(action: StringName) -> void:
	if str(action).begins_with("dodge"):
		status.text = "方向 / Alt · 闪避按键"
	else:
		var descriptions := {&"parry": "Space · 御术按键", &"ultimate": "Shift · 终式按键"}
		status.text = descriptions.get(action, "")


func refresh_options() -> void:
	for meaning in _meanings:
		meaning.visible = settings.show_meaning
