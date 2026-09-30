class_name BuildLab
extends Node
## Developer configuration, independent of ordinary / God progression data.

const CONFIG_PATH := "user://development/build-lab.json"
const CHOICE_SCENARIOS := ["priority", "escort", "waves"]
const SCENARIO_NAMES := {"neutral": "中性基线", "dense": "密集", "spread": "分散", "durable": "耐久", "barrage": "弹幕", "resistance": "抗性与弱点", "successive": "连续房间", "priority": "近敌与后排", "escort": "弱敌与要害", "waves": "连续三波"}
const BOOK_PRESENTATIONS := {
	&"frost": preload("res://game/content/books/frost.tres"),
	&"flame": preload("res://game/content/books/flame.tres"),
	&"storm": preload("res://game/content/books/storm.tres"),
	&"spirit": preload("res://game/content/books/spirit.tres"),
}
var selection := BuildSelection.new()
var compiler := BuildCompiler.new()
var settings := AppSettings.new()
var run := RunCombatState.new()
var vocabulary := VocabularyRepository.new()
var shell: PageShell
var battle: BattlePage
var session: BattleSession
var router := InputRouter.new()
var host: Control
var rows: VBoxContainer
var diagnostic: Label
var selected_label: Label
var details: Label
var _inspected: StringName
var inspector: Label
var search: LineEdit
var launch: Button
var offset := 0
var scenario: String = "neutral"
var _events: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = preload("res://ui/theme/keyabyss.tres")
	add_child(host)
	add_child(router)
	router.action_requested.connect(func(action: StringName) -> void:
		if session != null and not get_tree().paused: session.queue_action(action))
	router.back_requested.connect(_pause)
	router.focus_lost.connect(func() -> void:
		if session != null and not get_tree().paused: _pause())
	settings.load_settings() # Display / audio preferences are read, never saved here.
	_load_selection()
	show_configuration()


func show_configuration() -> void:
	_drop_shell()
	router.configure(InputRouter.Context.MODAL)
	shell = PageShell.create("构筑试验场", "选择内容与遭遇，使用正式编译和战斗规则验证。")
	shell.set_width(1660)
	shell.compact_height = 990
	host.add_child(shell)
	shell.close_button.pressed.connect(func() -> void: get_tree().quit())
	var book_row := HBoxContainer.new()
	shell.body.add_child(book_row)
	for id in BuildCompiler.BOOKS:
		_button(book_row, BOOK_PRESENTATIONS[id].title, func() -> void:
			selection.book_id = id
			show_configuration())
	var mode_row := HBoxContainer.new()
	shell.body.add_child(mode_row)
	_choice(mode_row, "副书", ["无", "frost", "flame", "storm", "spirit"], str(selection.secondary_book), func(value: String) -> void:
		selection.secondary_book = StringName(value if value != "无" else "")
		_refresh_diagnostics())
	var shapes: Array = ["无"] + BuildCompiler.SHAPES[selection.book_id]
	_choice(mode_row, "独卷形状", shapes, str(selection.focus_shape), func(value: String) -> void:
		selection.focus_shape = StringName(value if value != "无" else "")
		_refresh_diagnostics())
	_choice(mode_row, "遭遇", ["neutral", "dense", "spread", "durable", "barrage", "resistance", "successive", "priority", "escort", "waves"], scenario, func(value: String) -> void:
		scenario = value
		_refresh_diagnostics())
	var material_row := HBoxContainer.new()
	shell.body.add_child(material_row)
	for index in 2:
		_choice(material_row, "校准材料 %d" % (index + 1), ["自动", "cold", "heat", "charge", "summon"], selection.calibrated_materials[index] if selection.calibrated_materials.size() == 2 else "自动", func(value: String) -> void:
			if value == "自动": selection.calibrated_materials = []
			else:
				if selection.calibrated_materials.size() != 2: selection.calibrated_materials = ["cold", "heat"]
				selection.calibrated_materials[index] = value
			_refresh_diagnostics())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 60)
	shell.body.add_child(columns)
	var catalog_column := VBoxContainer.new()
	catalog_column.custom_minimum_size.x = 760
	columns.add_child(catalog_column)
	search = LineEdit.new()
	search.placeholder_text = "检索 ID、名称、规则或效果"
	search.focus_mode = Control.FOCUS_CLICK
	search.text_changed.connect(func(_text: String) -> void:
		offset = 0
		_refresh_rows())
	catalog_column.add_child(search)
	rows = VBoxContainer.new()
	catalog_column.add_child(rows)
	var pagination := HBoxContainer.new()
	catalog_column.add_child(pagination)
	_button(pagination, "上一组", func() -> void:
		offset = maxi(0, offset - 16)
		_refresh_rows())
	_button(pagination, "下一组", func() -> void:
		offset += 16
		_refresh_rows())
	var result_column := VBoxContainer.new()
	result_column.custom_minimum_size.x = 590
	columns.add_child(result_column)
	selected_label = PageShell.label(result_column, "", 19, Color("e8e4d8"))
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnostic = PageShell.label(result_column, "", 16, Color("c9ae72"))
	diagnostic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details = PageShell.label(result_column, "", 17, Color("c0ccc5"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	launch = _button(shell.footer, "开始试战", _start_battle)
	_button(shell.footer, "保存开发配置", _save_selection)
	_button(shell.footer, "清空选择", func() -> void:
		selection = BuildSelection.new()
		show_configuration())
	if session != null:
		_button(shell.footer, "应用并继续", _install_build)
		_button(shell.footer, "恢复当前试战", _resume)
	_refresh_rows()
	_refresh_diagnostics()


func _refresh_rows() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var matches: Array[CombatContentDefinition] = []
	for id in compiler.catalog.ordered_ids():
		if id == str(selection.book_id): continue
		var definition := compiler.catalog.get_definition(StringName(id))
		if search.text.is_empty() or (id + definition.title + definition.description).to_lower().contains(search.text.to_lower()): matches.append(definition)
	if not search.text.is_empty():
		matches.sort_custom(func(a: CombatContentDefinition, b: CombatContentDefinition) -> bool:
			var a_exact := str(a.id).to_lower() == search.text.to_lower()
			var b_exact := str(b.id).to_lower() == search.text.to_lower()
			return a_exact if a_exact != b_exact else str(a.id) < str(b.id))
	if offset >= matches.size(): offset = maxi(0, matches.size() - 16)
	for definition in matches.slice(offset, offset + 16):
		var row := HBoxContainer.new()
		rows.add_child(row)
		var chosen := str(definition.id) in selection.talents or selection.assets.has(definition.id)
		var button := _button(row, "%s  %s · %s" % ["✓" if chosen else "＋", definition.id, definition.title], func() -> void:
			_inspected = definition.id
			if definition is RelicDefinition:
				if selection.assets.has(definition.id): selection.assets.erase(definition.id)
				else: selection.assets[definition.id] = 1
			else:
				if str(definition.id) in selection.talents:
					var index := selection.talents.find(str(definition.id))
					selection.talents.remove_at(index)
				else: selection.talents.append(str(definition.id))
			_refresh_rows()
			_refresh_diagnostics())
		button.custom_minimum_size.x = 420
		if definition is RelicDefinition and chosen and definition.max_stacks > 1:
			var stacks := SpinBox.new()
			stacks.min_value = 1
			stacks.max_value = definition.max_stacks
			stacks.value = selection.assets[definition.id]
			stacks.focus_mode = Control.FOCUS_NONE
			stacks.get_line_edit().focus_mode = Control.FOCUS_CLICK
			stacks.value_changed.connect(func(value: float) -> void:
				selection.assets[definition.id] = int(value)
				_refresh_diagnostics())
			row.add_child(stacks)
		if not definition.supported:
			PageShell.label(row, str(definition.stage) if definition.stage != &"M3" else "待接线", 15, Color("aab9c2"))


func _refresh_diagnostics() -> void:
	var compiled := compiler.compile(selection)
	var selected := selection.talents.duplicate()
	for id in selection.assets: selected.append("%s ×%s" % [id, selection.assets[id]])
	selected.sort()
	selected_label.text = "%s主书\n\n%s" % [BOOK_PRESENTATIONS[selection.book_id].title, " · ".join(selected)]
	diagnostic.text = "编译通过 · 参数 %s\n\n本入口绕过成长图选取，仍检查内容前置、许可、层数和模式。" % CompiledBuild.PARAMETER_VERSION if compiled.success() else "\n\n".join(compiled.diagnostics)
	if scenario in CHOICE_SCENARIOS:
		diagnostic.text += "\n\n" + BuildLabScenarios.description(scenario)
	launch.disabled = not compiled.success()
	var inspected := compiler.catalog.get_definition(_inspected)
	details.text = "" if inspected == null else "%s · %s\n\n%s\n\n%s" % [inspected.id, inspected.title, inspected.description, "许可：" + " / ".join(inspected.permits) if not inspected.permits.is_empty() else ""]


func _start_battle() -> void:
	var compiled := compiler.compile(selection)
	if not compiled.success(): return
	get_tree().paused = false
	if battle != null:
		if session.result == 0: session.finish_room(&"abandon")
		session.set_physics_process(false)
		battle.queue_free()
	var request := BattleStartRequest.new()
	request.build = compiled.build
	request.vocabulary = vocabulary.select_entries(PackedStringArray([settings.vocabulary_id]), settings.min_length, settings.max_length)
	if request.vocabulary.is_empty():
		diagnostic.text = "当前词库没有可用词条，请在主界面准备词库。"
		return
	request.progressive = false
	request.seed_text = "build-lab"
	request.encounter = BattleEncounter.new()
	request.encounter.wave_count = 1
	if scenario == "resistance": request.encounter.element_traits = (preload("res://game/content/resistance_room.tres") as BattleEncounter).element_traits
	request.encounter.health_multiplier = 10.0 if scenario == "durable" else 3.0
	if scenario in CHOICE_SCENARIOS:
		request.encounter = BuildLabScenarios.encounter(scenario)
	if scenario != "successive": run = RunCombatState.new()
	session = BattleSession.new()
	session.start(request, run)
	if scenario in CHOICE_SCENARIOS:
		BuildLabScenarios.arrange(session, scenario)
	_events.clear()
	session.event_committed.connect(func(event: Dictionary) -> void:
		_events.append(event.duplicate())
		if _events.size() > 120: _events.pop_front())
	session.finished.connect(func(_victory: bool) -> void: _show_inspector())
	battle = BattlePage.create(session, settings, BOOK_PRESENTATIONS[selection.book_id])
	battle.pause_requested.connect(_pause)
	host.add_child(battle)
	if scenario in ["dense", "spread", "barrage"]:
		for index in session.enemies.size():
			var enemy := session.enemies[index]
			enemy.position = Vector2(0.65, 0.38) + Vector2(0.03, 0.03) * index if scenario == "dense" else Vector2(0.25 + index * 0.25, 0.3)
			enemy.previous_position = enemy.position
			if scenario == "barrage": enemy.attack_interval = 1.0
	_resume()


func _pause() -> void:
	if session == null or get_tree().paused: return
	get_tree().paused = true
	router.configure(InputRouter.Context.MODAL)
	_show_inspector()


func _show_inspector() -> void:
	_drop_shell()
	router.configure(InputRouter.Context.MODAL)
	if session == null: return
	session.set_physics_process(false)
	shell = PageShell.create("此刻的法术", "来源、剩余和关键事实来自已提交的战斗状态。")
	shell.set_width(1420)
	shell.compact_height = 920
	host.add_child(shell)
	inspector = PageShell.label(shell.body, "", 17, Color("e8e4d8"))
	var runtime := session.runtime
	var lines: PackedStringArray = ["房间 %s · 人工字符 %s · 人工完词 %s" % [session.ledger.room_id, session.manual_characters, session.completed_words], "实际扣血 %.2f · 过量伤害 %.2f · 未用完便结束 %.2f" % [runtime.actual_damage_q / 1024.0, runtime.overkill_damage_q / 1024.0, runtime.unused_power_q / 1024.0], "护页／纸灵挡伤 %.2f（%d 次）· 实际治疗 %.2f · 冻结触发 %d 次" % [runtime.guarded_damage_q / 1024.0, runtime.guarded_hits, runtime.healed_q / 1024.0, runtime.freezes]]
	var sources := runtime.damage_by_source.keys()
	sources.sort()
	var source_names := {&"frost_spear": "冰矛", &"frost_fragment": "冰片", &"flame_burst": "火弹", &"flame_burn": "持续作用", &"flame_splash": "溅射", &"storm_arc": "电弧", &"storm_beam": "束雷", &"spirit_mark": "纸灵", &"spirit_blade": "纸刃", &"counter": "反击", &"counter-followup": "后续反击"}
	for source: StringName in sources:
		lines.append("%s：扣血 %.2f · 击破 %d" % [source_names.get(source, str(source)), runtime.damage_by_source[source] / 1024.0, runtime.kills_by_source.get(source, 0)])
	lines.append("\n来源与剩余（资源支出包含制作与清理，不代表伤害）")
	for lot in session.ledger.active_lots():
		lines.append("#%s  %s  材料 %s  剩余 %.3f  来源 %s  历史 %s" % [lot.id, lot.owner, lot.material, lot.amount_q / 1024.0, lot.root_id.right(22), str(lot.claims.keys())])
	lines.append("\n关键事实")
	for event in _events.slice(maxi(0, _events.size() - 24)):
		lines.append(str(event))
	inspector.text = "\n".join(lines)
	inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(shell.footer, "调整构筑", show_configuration)
	if session.result == 0: _button(shell.footer, "继续", _resume)
	elif session.result == 1 and scenario == "successive": _button(shell.footer, "下一房", _start_battle)
	else: _button(shell.footer, "重新试战", func() -> void:
		run = RunCombatState.new()
		_start_battle())
	shell.close_button.pressed.connect(_resume if session.result == 0 else show_configuration)


func _install_build() -> void:
	var compiled := compiler.compile(selection)
	if compiled.success() and session != null and session.book_id == compiled.build.book():
		var command := BattleCommand.new()
		command.build = compiled.build
		session.queue_command(command)
		_resume()
	else:
		diagnostic.text = "更换主书需要新开试战；同主书的编译快照可在下一固定步安装。"


func _resume() -> void:
	_drop_shell()
	get_tree().paused = false
	if session != null and session.result == 0:
		session.set_physics_process(true)
		router.typing = session.typing
		router.configure(InputRouter.Context.TYPING)


func _drop_shell() -> void:
	if is_instance_valid(shell): shell.queue_free()
	shell = null


func _button(parent: Node, caption: String, action: Callable) -> OpenButton:
	var button := OpenButton.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _choice(parent: Node, caption: String, values: Array, current: String, changed: Callable) -> void:
	var caption_label := PageShell.label(parent, caption, 16, Color("aab9c2"))
	caption_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	caption_label.custom_minimum_size.x = 110
	var choice := OptionButton.new()
	choice.focus_mode = Control.FOCUS_NONE
	for value in values: choice.add_item(SCENARIO_NAMES.get(str(value), str(value)) if caption == "遭遇" else str(value))
	choice.select(maxi(0, values.find(current)))
	choice.item_selected.connect(func(index: int) -> void: changed.call(str(values[index])))
	parent.add_child(choice)


func _save_selection() -> void:
	DirAccess.make_dir_recursive_absolute("user://development")
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"book": selection.book_id, "talents": Array(selection.talents), "assets": selection.assets, "secondary": selection.secondary_book, "shape": selection.focus_shape, "materials": Array(selection.calibrated_materials), "scenario": scenario}))
	diagnostic.text = "开发配置已保存。"


func _load_selection() -> void:
	if not FileAccess.file_exists(CONFIG_PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary: return
	selection.book_id = StringName(parsed.get("book", "frost"))
	if selection.book_id not in BuildCompiler.BOOKS: selection.book_id = &"frost"
	selection.talents = PackedStringArray(parsed.get("talents", []))
	for id: String in parsed.get("assets", {}): selection.assets[StringName(id)] = int(parsed.assets[id])
	selection.secondary_book = StringName(parsed.get("secondary", ""))
	selection.focus_shape = StringName(parsed.get("shape", ""))
	selection.calibrated_materials = PackedStringArray(parsed.get("materials", []))
	scenario = str(parsed.get("scenario", "neutral"))
