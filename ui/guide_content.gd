class_name GuideContent
extends RefCounted

const DISPLAY_FONT: FontFile = preload("res://assets/fonts/huiwen-ming.ttf")
const SMALL_FONT: FontFile = preload("res://assets/fonts/jinghua-song.ttf")
const BODY_COLOR := Color("d9d4c5")
const MUTED_COLOR := Color("aeb9b5")

const ARTICLES := [
	{"key": "A–Z", "title": "落笔 · 完词施法", "body": "输入敌人头顶的词咒。首字符锁定目标，写完一词即施法，每第三次施法强化。错字不清空进度；目标提前倒下时，可继续写完原词，法术会转向其附近的敌人。"},
	{"key": "Space", "title": "御术 · 挡下攻击", "body": "轻按空格进入短暂防御，挡住敌弹与近身攻击。起手迎击为完美御术：反弹直接命中的敌弹，打断近战攻击者，并短暂放慢时间。完美御术后可以短暂连续迎击；闪避会结束这个窗口。激光与爆圈会穿过御术，需闪避。"},
	{"key": "Ctrl", "title": "主动补全 · 通灵羽毛笔", "body": "获得通灵羽毛笔后，亲手完成词咒可积累主动补全机会。身旁的补字符文亮起时，先输入部分词咒，再按 Ctrl 补齐。法术只按亲手输入的部分计算；补出的字母不增加威力、成长或亲手完成奖励。"},
	{"key": "方向键 / Alt", "title": "折页 · 闪避", "body": "按方向键立即朝对应方向闪避，或按 Alt 自动选择威胁较低的落点，获得 1 秒无敌。敌弹、近战、冲锋、激光或爆圈即将命中时闪避，可获得完美闪避：额外共鸣，并放慢战场至本次无敌结束。空格独立释放御术。"},
	{"key": "Shift", "title": "终章 · 释放终式", "body": "亲手输入与完词积累共鸣，充满后单独轻按 Shift。终式推开近敌并清除大范围敌弹；已落下的激光和地面危险仍需避开。持续期间不积累共鸣。"},
	{"key": "Tab / ⌫", "title": "换行 · 调整目标", "body": "Tab 切换同前缀目标，退格取消锁定。Esc 暂停。菜单词令敲完即执行。"},
	{"key": "", "title": "翻卷 · 行间与守关者", "body": "选择法书与词库即可出征。远征共三章九房，每章末尾迎战守关者。击败敌人积累经验，三选一取得遗物；房间之间可以休息或付血换取遗物。通关后可保留遗物升到下一难度；灭世通关后可继续更强的周目。"},
	{"key": "", "title": "观潮 · 八向来袭", "body": "每波敌人从随机方向主攻。角色周围的金色箭头指向敌人来处，珊瑚红外围箭头短暂提示其他方向的偷袭。注意观察四周，及时调整目标。"},
	{"key": "", "title": "留痕 · 输入与记录", "body": "亲手正确输入的字符自动累计；每 1000 字符增加 4 点初始生命，最多增加 20 点，在新远征开始时生效。四书共享，战败或主动结束也会结算。中途关闭游戏会保存远征；再次出征可继续或重开，战斗中断后从该房恢复。远征记录可回顾已结束的旅程与遗物。"},
	{"key": "", "title": "断墨 · 道具词咒", "body": "输入场上道具的词咒也能解除危机。反制符大范围反弹敌弹、打断敌人及守关者的动作，并清除尚未落下的危险预警；伤害较低。爆墨清除近处敌弹并造成范围伤害。道具有存在时间，需要及时完成。"},
	{"key": "", "title": "藏词 · 自己的词库", "body": "本局始终使用所选词库。支持英文、数字、下划线、连字符与撇号；请使用英文输入法。"},
	{"key": "", "title": "页边注 · 术语", "body": "词咒是道具或敌人头顶漂浮的单词；词令是菜单中的英文指令。连续完词积累「连笔」；「共鸣」蓄满后可释放终式。"},
	{"key": "", "title": "纸灵 · 持续唤醒", "body": "完词逐步唤醒纸灵，并给目标施加易伤；每第三次施法指挥全员交叉斩。正确输入维持活动，停笔后逐只休眠，换页重新唤醒。闪避留下挡弹反击的符文纸鹤；终式唤起纸灵并使其狂暴。"},
	{"key": "", "title": "灰烬 · 预判转火", "body": "火弹被前排敌人挡住，命中后持续燃烧；血条上的橙色尾段估计余火伤害。每第三次命中触发焰印并留下火雾，闪避也留下火雾。重叠火雾的收益逐层减半；终式释放火浪和持续火域。"},
	{"key": "", "title": "寒墨 · 争取空档", "body": "冰锥沿弹道穿透敌人，强化冰矛可穿透更多目标。冰蓝弧线表示寒气积累，寒气减慢移动与攻击，积满触发冻结；解冻后敌人继续原动作。闪避冰雾遮挡远敌视线；终式给予护盾，领域持续积寒并从不同方向发射冰锥。"},
	{"key": "", "title": "雷鸣 · 连接敌群", "body": "电链连接多个敌人，伤害逐段降低，每第三次施法附带电爆。感电让幸存敌人成为更远的连接点；已带电的目标还能充能并延长电链。闪避路径带电，终式领域持续感电，并让每次施法附带电爆。"},
	{"key": "Alt", "title": "遗物 · 阅读与搭配", "body": "选择遗物时，按住 Alt 查看取得前后的数值、前置与互斥关系。常见、珍本、秘藏与觉醒使用不同卡片颜色。前置可以来自本书或其他遗物；本书觉醒只能选择一种。将鼠标停在正文术语上，可查看解释。"},
]

const EXAMPLES := [
	{"id": &"R016", "title": "无瑕落款", "family": "无错字", "tradeoff": "错字不会清空输入，但该词失去无错加成。", "note": "先保证输入稳定，再逐渐提速。"},
	{"id": &"R014", "title": "短咒连珠", "family": "词长", "tradeoff": "只对符合词长的词咒生效。", "note": "选择含短词的词库与范围。"},
	{"id": &"R006", "title": "双生笔尖", "family": "复制", "tradeoff": "复制不会再次触发复制，也不增加人工字符。", "note": "持续完词才能继续触发。"},
	{"id": &"R041", "title": "停笔书签", "family": "防御", "tradeoff": "减速只持续片刻，闪避仍需恢复。", "note": "在危险逼近时闪避，利用空档完成词咒。"},
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


static func _add_demonstration(parent: VBoxContainer, accent_labels: Array[Dictionary], accent_rules: Array[Dictionary], current_build: CompiledBuild = null) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 13)
	section.focus_mode = Control.FOCUS_NONE
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(section)
	_add_rule(section, 0.45, accent_rules)
	_accent_label(section, "搭配示例", 24, DISPLAY_FONT, accent_labels, Color("e8d9ad"), 0.2)
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
	var event_change := _detail(details, "输入建议", accent_labels)
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
		button.pressed.connect(_select_example.bind(index, buttons, purpose, tradeoff, event_change, current_build))
		_label(cell, example.family, 12, MUTED_COLOR, SMALL_FONT)
	_select_example(0, buttons, purpose, tradeoff, event_change, current_build)


static func _detail(parent: HBoxContainer, heading: String, accent_labels: Array[Dictionary]) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 5)
	column.focus_mode = Control.FOCUS_NONE
	parent.add_child(column)
	_accent_label(column, heading, 15, DISPLAY_FONT, accent_labels)
	return _label(column, "", 15, BODY_COLOR, SMALL_FONT)


static func _select_example(index: int, buttons: Array[OpenButton], purpose: Label, tradeoff: Label, event_change: Label, current_build: CompiledBuild = null) -> void:
	var example: Dictionary = EXAMPLES[index]
	purpose.text = ContentDescription.summary(BuildCatalog.new().get_definition(example.id), maxi(1, current_build.asset_stacks(example.id)) if current_build != null else 1)
	tradeoff.text = example.tradeoff
	event_change.text = example.note
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
