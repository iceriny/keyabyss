class_name TutorialMenu
extends PageShell
## Lesson selection only; the controller owns all tutorial combat state.

signal lesson_requested(book_id: StringName)

const BOOKS: Array[BookPresentation] = [
	preload("res://game/content/books/frost.tres"),
	preload("res://game/content/books/flame.tres"),
	preload("res://game/content/books/storm.tres"),
	preload("res://game/content/books/spirit.tres"),
]
const LESSON_NOTES: Dictionary[StringName, String] = {
	&"frost": "穿过敌人 · 冻住目标 · 击碎冰冻敌人 · 闪避留雾",
	&"flame": "火弹受阻 · 爆炸与燃烧 · 闪避留火",
	&"storm": "连着攻击敌人 · 感电增强电链 · 闪避攻击",
	&"spirit": "自动攻击 · 停笔与唤醒 · 纸鹤挡弹反击",
}

var lesson_buttons: Dictionary[StringName, OpenButton] = {}


static func create_menu(motion_reduced: bool, completed_lessons: Array[StringName] = []) -> TutorialMenu:
	var page := load("res://ui/scenes/tutorial_menu.tscn").instantiate() as TutorialMenu
	page.reduced_motion = motion_reduced
	page.configure("教学练习", "先学基础操作，再试试不同法书。")
	page.panel_width = 1000.0
	page._configure_lessons(completed_lessons)
	return page


func _configure_lessons(completed_lessons: Array[StringName]) -> void:
	var basics := body.get_node("Basics/Begin") as OpenButton
	_bind_lesson(basics, &"basics")
	if &"basics" in completed_lessons:
		(body.get_node("Basics/Copy/Title") as Label).text += " · 已完成"
		basics.set_caption("再练一次")
	for book: BookPresentation in BOOKS:
		var row := body.get_node("Books/" + str(book.id)) as HBoxContainer
		var seal := row.get_node("Seal") as TextureRect
		seal.texture = ArcanaRunes.seal(book.id, 68.0)
		seal.modulate = Color(book.color, 0.8)
		var title := row.get_node("Copy/Title") as Label
		title.text = book.title
		title.add_theme_color_override("font_color", book.color)
		(row.get_node("Copy/Note") as Label).text = LESSON_NOTES[book.id]
		_bind_lesson(row.get_node("Begin") as OpenButton, book.id)
		if book.id in completed_lessons:
			title.text += " · 已完成"
			lesson_buttons[book.id].set_caption("再练一次")
	status.hide()


func _bind_lesson(control: OpenButton, id: StringName) -> void:
	lesson_buttons[id] = control
	control.set_motion_reduced(reduced_motion)
	control.set_command_word(str(id))
	control.pressed.connect(func() -> void: lesson_requested.emit(id))
