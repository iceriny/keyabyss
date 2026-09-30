class_name GuideContent
extends RefCounted

const DISPLAY_FONT: FontFile = preload("res://assets/fonts/huiwen-ming.ttf")
const SMALL_FONT: FontFile = preload("res://assets/fonts/jinghua-song.ttf")
const BODY_COLOR := Color("d9d4c5")
const MUTED_COLOR := Color("aeb9b5")

const ARTICLES := [
	{"key": "A–Z", "title": "落笔 · 完词施法", "body": "输入敌人头顶的词咒。首字符锁定目标，写完一词即施法；错字不会清空已写进度。"},
	{"key": "Space", "title": "回锋 · 弹反", "body": "轻按空格弹反：窗口 0.24 秒，冷却 0.70 秒，次数不限。敌人近战蓄势时会标出打击范围，在挥击到来时弹反，可反击并将敌人推远；也可反射飞抵身边的敌弹。成功时短暂时缓，随后平滑恢复。基础反伤很小；返咒类能力让反击消耗打字积累的力量，继续打字才能持续强化反击。"},
	{"key": "Ctrl", "title": "补字 · 提前施法", "body": "取得辅助补全能力并积累好机会后，按 Ctrl 提前结束正在输入的词咒，只按已经手打的部分施法。不按即可继续输入。补出的字母不增加威力、成长或完整手打奖励；补全消耗的制作额度与其他辅助效果共享。"},
	{"key": "方向键 / Alt", "title": "折页 · 闪避", "body": "按方向键立即朝对应方向闪避，或按 Alt 自动选择威胁较低的落点，获得 1 秒无敌。空格独立释放弹反。"},
	{"key": "Shift", "title": "终章 · 释放终式", "body": "共鸣充满后单独轻按 Shift。组合输入不会误触终式。"},
	{"key": "Tab / ⌫", "title": "换行 · 调整目标", "body": "Tab 切换同前缀目标，退格取消锁定。Esc 暂停。菜单词令敲完即执行。"},
	{"key": "", "title": "翻卷 · 三章九场", "body": "清除每波增援，选择遗物与补给路线，击败守页者。通关可携构筑挑战下一周目。"},
	{"key": "", "title": "观潮 · 八向来袭", "body": "每波敌人从随机方向主攻。角色周围的金色箭头指向敌人来处，珊瑚红外围箭头短暂提示其他方向的偷袭。注意观察四周，及时调整目标。"},
	{"key": "", "title": "留痕 · 远征记录", "body": "书库和结算页可查看最近 50 份战报，回顾到达阶段、施法表现、遗物与错词，并导出留存。记录保存在本机中。"},
	{"key": "", "title": "藏词 · 自己的词库", "body": "本局始终使用所选词库。支持英文、数字、下划线、连字符与撇号；请使用英文输入法。"},
	{"key": "", "title": "页边注 · 术语", "body": "词咒是道具或敌人头顶漂浮的单词；词令是菜单中的英文指令。连续完词积累「连笔」；「共鸣」蓄满后可释放终式。"},
]

const EXAMPLES := [
	{"title": "复写分栏", "family": "复写", "purpose": "把人工供给分给更多纸页，观察复制数量与威力折算。", "tradeoff": "覆盖扩大，单页变轻；后续交付仍受容量约束。", "event": "覆文归档以一次后续奖励换加工继承。"},
	{"title": "守页装订", "family": "装订", "purpose": "让载体在正常攻击与护持之间选择出口。", "tradeoff": "保留护页意味着自动交付更慢。", "event": "改页使最新护页优先承受防御消耗。"},
	{"title": "完整晶壳", "family": "晶壳", "purpose": "集中晶体份额与穿透，处理耐久目标。", "tradeoff": "碎片覆盖减少，群体场面更依赖转目标。", "event": "晶匠校形改作容量更高、交付更慢的冰藏容器。"},
	{"title": "缓燃炉心", "family": "炉心", "purpose": "把人工热量留下，观察储备和后续释放。", "tradeoff": "高阈值换容量，短战即时兑现较少。", "event": "炉心退火把已有热零件转作封装材料。"},
	{"title": "长距孤弧", "family": "电路", "purpose": "延长电性片段在分散目标间的有效路径。", "tradeoff": "距离换来较少跳转，密集敌群覆盖下降。", "event": "孤弧定向进一步集中有限电性份额。"},
	{"title": "展开扇尺", "family": "几何", "purpose": "把已支付威力分给更广的接收者。", "tradeoff": "单体集中下降，远端交付需要等待。", "event": "长廊契约用后续压力换取更长中继。"},
	{"title": "细口热匣", "family": "储备", "purpose": "比较高效率低容量的回收周转。", "tradeoff": "储备很快触顶，多余热量会损失。", "event": "余量入藏改作跨房封存，兑现阈值提高。"},
	{"title": "百屑分梳", "family": "分合", "purpose": "用人工热材料加工晶体，把已有威力分成较多较轻的片段。", "tradeoff": "覆盖增加，本体持有威力减少。", "event": "百屑淬炼让热加工提前交出片段。"},
	{"title": "行间书袋", "family": "运输", "purpose": "纸灵用原攻击周期运输已付载荷。", "tradeoff": "更高容量伴随更长交付等待。", "event": "回航归档把未用运输余额接入回收出口。"},
	{"title": "分字书签", "family": "词形", "purpose": "观察未完成词的字母寻找其他同字母位置。", "tradeoff": "分散标记降低单目标集中，仍需亲手输入兑现。", "event": "词形重订把部分标记收益改作承载。"},
	{"title": "守文回敬", "family": "护持", "purpose": "护页挡下普通弹幕后交出尚未释放的余载。", "tradeoff": "同一页不能同时领取完整攻击与完整防御。", "event": "护文契约增加留存但支付生命上限。"},
	{"title": "尖锋定本", "family": "独卷", "purpose": "以独卷结构把电性份额集中到少数接收者，并让复写承接后续交付。", "tradeoff": "广域传导变少，不能覆盖所有分散目标。", "event": "定本易形交换即时威力与继承加工。"},
	{"title": "借阅终页", "family": "装订", "purpose": "观察护页余载在本章内取得终结出口。", "tradeoff": "借来的容量较少，同一页仍只能交付一次。", "event": "借阅终章的规则随本章结束到期。"},
	{"title": "一房旁路", "family": "运输", "purpose": "观察运输载体在当前房间成为电性中继。", "tradeoff": "旁路只在本房有效，下一房恢复原构筑。", "event": "借阅旁路进入下一房时到期。"},
]


static func build(parent: VBoxContainer, book: BookPresentation, on_practice: Callable) -> void:
	var fallback := book.color if book != null else Color("c8af74")
	var accent_labels: Array[Dictionary] = []
	var accent_rules: Array[Dictionary] = []
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.focus_mode = Control.FOCUS_NONE
	parent.add_child(grid)
	for article: Dictionary in ARTICLES:
		_add_article(grid, article, accent_labels, accent_rules)
	_add_demonstration(parent, accent_labels, accent_rules)
	_add_practice(parent, accent_rules, on_practice)
	parent.theme_changed.connect(_update_accents.bind(parent, fallback, accent_labels, accent_rules))
	_update_accents(parent, fallback, accent_labels, accent_rules)


static func _add_article(parent: GridContainer, article: Dictionary, accent_labels: Array[Dictionary], accent_rules: Array[Dictionary]) -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.focus_mode = Control.FOCUS_NONE
	parent.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.focus_mode = Control.FOCUS_NONE
	margin.add_child(column)
	_add_rule(column, 0.55, accent_rules)
	if not article.key.is_empty():
		var key := KeyHint.create(article.key, "")
		key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(key)
	_accent_label(column, article.title, 21, DISPLAY_FONT, accent_labels, Color("eddfbd"), 0.2)
	_label(column, article.body, 17, BODY_COLOR, SMALL_FONT)


static func _add_demonstration(parent: VBoxContainer, accent_labels: Array[Dictionary], accent_rules: Array[Dictionary]) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 13)
	section.focus_mode = Control.FOCUS_NONE
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(section)
	_add_rule(section, 0.45, accent_rules)
	_accent_label(section, "构筑札记 · 实战演示", 24, DISPLAY_FONT, accent_labels, Color("e8d9ad"), 0.2)
	_label(section, "选一条学习路线，查看它的用途、代价与事件转向。", 16, MUTED_COLOR, SMALL_FONT)
	var picker := GridContainer.new()
	picker.columns = 4
	picker.add_theme_constant_override("h_separation", 16)
	picker.add_theme_constant_override("v_separation", 7)
	picker.focus_mode = Control.FOCUS_NONE
	section.add_child(picker)
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 16)
	details.focus_mode = Control.FOCUS_NONE
	section.add_child(details)
	var purpose := _detail(details, "用途", accent_labels)
	var tradeoff := _detail(details, "代价", accent_labels)
	var event_change := _detail(details, "事件转向", accent_labels)
	var buttons: Array[OpenButton] = []
	for index in EXAMPLES.size():
		var example: Dictionary = EXAMPLES[index]
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.focus_mode = Control.FOCUS_NONE
		picker.add_child(cell)
		var button := OpenButton.new()
		button.text = "%s    note-%02d" % [example.title, index + 1]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(button)
		buttons.append(button)
		button.pressed.connect(_select_example.bind(index, buttons, purpose, tradeoff, event_change))
		_label(cell, example.family, 12, MUTED_COLOR, SMALL_FONT)
	_select_example(0, buttons, purpose, tradeoff, event_change)


static func _detail(parent: HBoxContainer, heading: String, accent_labels: Array[Dictionary]) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 5)
	column.focus_mode = Control.FOCUS_NONE
	parent.add_child(column)
	_accent_label(column, heading, 15, DISPLAY_FONT, accent_labels)
	return _label(column, "", 15, BODY_COLOR, SMALL_FONT)


static func _select_example(index: int, buttons: Array[OpenButton], purpose: Label, tradeoff: Label, event_change: Label) -> void:
	var example: Dictionary = EXAMPLES[index]
	purpose.text = example.purpose
	tradeoff.text = example.tradeoff
	event_change.text = example.event
	for button_index in buttons.size():
		buttons[button_index].set_selected_visual(button_index == index)


static func _add_practice(parent: VBoxContainer, accent_rules: Array[Dictionary], on_practice: Callable) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 14)
	section.focus_mode = Control.FOCUS_NONE
	parent.add_child(section)
	_add_rule(section, 0.4, accent_rules)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.focus_mode = Control.FOCUS_NONE
	section.add_child(row)
	var note := _label(row, "请切换为英文输入法", 15, MUTED_COLOR, SMALL_FONT)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var button := OpenButton.new()
	button.text = "练习词咒    practice"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(on_practice)
	row.add_child(button)


static func _label(parent: Node, value: String, size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	parent.add_child(label)
	return label


static func _accent_label(parent: Node, value: String, size: int, font: Font, accents: Array[Dictionary], base: Color = Color.WHITE, weight: float = 1.0) -> Label:
	var label := _label(parent, value, size, base, font)
	accents.append({"label": label, "base": base, "weight": weight})
	return label


static func _update_accents(parent: VBoxContainer, fallback: Color, labels: Array[Dictionary], rules: Array[Dictionary]) -> void:
	var accent := parent.get_theme_color("accent", "Archive") if parent.has_theme_color("accent", "Archive") else fallback
	for item: Dictionary in labels:
		var label: Label = item.label
		label.add_theme_color_override("font_color", (item.base as Color).lerp(accent, item.weight))
	for item: Dictionary in rules:
		var line: TextureRect = item.line
		line.modulate = Color(accent, item.opacity)


static func _add_rule(parent: Node, opacity: float, rules: Array[Dictionary]) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 128
	var line := TextureRect.new()
	line.texture = texture
	line.custom_minimum_size.y = 1.0
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.focus_mode = Control.FOCUS_NONE
	parent.add_child(line)
	rules.append({"line": line, "opacity": opacity})
