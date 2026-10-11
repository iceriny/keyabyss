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
	&"frost": "贯穿与强化 · 寒气冻结 · 冻裂连锁 · 冰雾遮蔽 · 冰河纪事",
	&"flame": "焰印爆炸 · 火弹阻挡 · 余火转火 · 闪避火雾 · 焚世余烬",
	&"storm": "电链与电爆 · 感电充能 · 闪避雷径 · 雷鸣终章",
	&"spirit": "交叉斩 · 易伤游击 · 维持与休眠 · 纸鹤反伤 · 千纸夜行",
}

var lesson_buttons: Dictionary[StringName, OpenButton] = {}


static func create_menu(motion_reduced: bool) -> TutorialMenu:
	var page := load("res://ui/scenes/tutorial_menu.tscn").instantiate() as TutorialMenu
	page.reduced_motion = motion_reduced
	page.configure("落笔入门", "在短小的实战练习中，熟悉输入与四书的节奏。")
	page.panel_width = 1000.0
	page._configure_lessons()
	return page


func _configure_lessons() -> void:
	var basics := body.get_node("Basics/Begin") as OpenButton
	_bind_lesson(basics, &"basics")
	for book: BookPresentation in BOOKS:
		var row := body.get_node("Books/" + str(book.id)) as HBoxContainer
		(row.get_node("Seal") as TextureRect).texture = book.seal
		var title := row.get_node("Copy/Title") as Label
		title.text = book.title
		title.add_theme_color_override("font_color", book.color)
		(row.get_node("Copy/Note") as Label).text = LESSON_NOTES[book.id]
		_bind_lesson(row.get_node("Begin") as OpenButton, book.id)
	status.text = "每节独立练习，可随时退出或重新开始。"
	command_hint.text = "点击入口，或输入旁边的词令"


func _bind_lesson(control: OpenButton, id: StringName) -> void:
	lesson_buttons[id] = control
	control.set_motion_reduced(reduced_motion)
	control.set_command_word(str(id))
	control.pressed.connect(func() -> void: lesson_requested.emit(id))
