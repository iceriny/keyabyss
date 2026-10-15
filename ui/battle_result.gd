class_name BattleResult
extends VBoxContainer
## The report reads the archived build: settlement may already have cleared selection.

var report: Dictionary = {}
var detail_buttons: Array[OpenButton] = []
var detail_panels: Array[Control] = []
var selected_detail := -1


func configure(session: BattleSession, book: BookPresentation, abandoned: bool, run: RunSession = null, vocabulary_title: String = "") -> void:
	var won := session.result > 0
	var tint := Color("e8e4d8")
	var stats: Dictionary = run.facts.get("result_stats", {}) if run != null else {}
	var scope := "此轮"
	if stats.is_empty():
		stats = session.statistics.snapshot()
		scope = "本页"
	var difficulty: String = RunSession.DIFFICULTY_NAMES[RunSession.DIFFICULTIES.find(session.difficulty)]
	var stage := "第 %d 章 · 第 %d 页    ·    %s" % [session.chapter, (session.run_state.room_serial - 1) % 3 + 1, difficulty]
	var boss: BattleEnemy
	for enemy in session.enemies:
		if enemy.boss: boss = enemy
	stage += " · 首领阶段 %d" % boss.phase if boss != null else " · 第 %d / %d 段" % [session.wave, session.encounter.wave_count]
	$Stage.text = stage
	var correct := int(stats.get("manual_characters", 0))
	var mistakes := int(stats.get("mistakes", 0))
	var elapsed := float(stats.get("elapsed", 0.0))
	var accuracy := 100.0 * correct / (correct + mistakes) if correct + mistakes > 0 else 0.0
	$Stats/Kills.display(str(stats.get("kills", 0)), tint)
	$Stats/Accuracy.display("%.1f%%" % accuracy if correct + mistakes > 0 else "—", tint)
	$Stats/Time.display("%02d:%02d" % [floori(elapsed / 60.0), floori(fmod(elapsed, 60.0))], tint)
	$DetailSlot/Statistics/Pace.text = "手打词咒  %d     ·     最高连笔  %d     ·     每分钟词数  %d" % [int(stats.get("manual_words", 0)), int(stats.get("max_combo", 0)), roundi(correct * 12.0 / elapsed) if elapsed > 0.0 else 0]
	$DetailSlot/Statistics/Input.text = "正确字符  %d     ·     错误字符  %d     ·     连续正确  %d" % [correct, mistakes, int(stats.get("best_correct_streak", 0))]
	$DetailSlot/Statistics/Tactics.text = "造成伤害  %d    ·    闪避  %d    ·    御术成功  %d（完美 %d）    ·    终式  %d" % [ceili(float(stats.get("damage_q", 0)) / BattleSession.Q), int(stats.get("dodges", 0)), int(stats.get("defense_successes", 0)), int(stats.get("perfect_defenses", 0)), int(stats.get("ultimates", 0))]
	var build: Dictionary = run.facts.get("result_build", run.selection.to_dict()) if run != null else {}
	var catalog := run.compiler.catalog if run != null else BuildCatalog.new()
	var relics: Dictionary = build.get("assets", {}).duplicate()
	if not build.get("instances", []).is_empty():
		relics.clear()
		for instance: Dictionary in build.instances:
			var id := str(instance.content_id)
			relics[id] = int(relics.get(id, 0)) + 1
	$DetailSlot/Build/Book.text = book.title
	var relic_lines := PackedStringArray()
	for id: String in relics:
		var definition := catalog.get_definition(StringName(id))
		if definition != null: relic_lines.append("%s  ×%d" % [definition.title, int(relics[id])])
	$DetailSlot/Build/Scroll/Description.text = "未携带遗物" if relic_lines.is_empty() else "\n".join(relic_lines)
	var wrong: Dictionary = stats.get("wrong_word_counts", {})
	var words := wrong.keys()
	words.sort_custom(func(a: String, b: String) -> bool: return int(wrong[a]) > int(wrong[b]) if int(wrong[a]) != int(wrong[b]) else a < b)
	$DetailSlot/Mistakes/Summary.text = "%d 次词咒出错" % int(stats.get("wrong_words", 0)) if not wrong.is_empty() else ("落笔无误" if mistakes == 0 else "未锁定词咒时的错误输入")
	var wrong_lines := PackedStringArray()
	for word: String in words:
		wrong_lines.append("%s  ·  %d 次错字\n%s" % [word, int(wrong[word]), session.word_meaning(word)])
	$DetailSlot/Mistakes/Scroll/Words.text = "\n\n".join(wrong_lines) if not wrong_lines.is_empty() else ("此次没有需要重写的词。" if mistakes == 0 else "这些输入没有对应的目标词咒，已计入错误字符。")
	var date := Time.get_datetime_string_from_system(false, true)
	var seed_text := run.seed_text if run != null else ""
	var round_number := int(run.facts.get("round_index", 0)) + 1 if run != null else 1
	var level := run.rewards.level if run != null else 1
	report = {"date": date, "outcome": "victory" if won else ("abandon" if abandoned else "defeat"), "stage": stage, "book": str(book.id), "vocabulary": vocabulary_title, "seed": seed_text, "round": round_number, "level": level, "content_version": SaveRepository.CONTENT_VERSION, "statistics_scope": scope, "stats": stats.duplicate(true), "build": build.duplicate(true), "wrong_words": []}
	for word: String in words:
		report.wrong_words.append({"word": word, "mistakes": wrong[word], "meaning": session.word_meaning(word)})
	detail_panels = [$DetailSlot/Statistics, $DetailSlot/Build, $DetailSlot/Mistakes]
	for item: String in ["Kills", "Accuracy", "Time"]:
		get_node("Stats/" + item + "/Value").add_theme_font_size_override("font_size", 36)


func show_detail(index: int) -> void:
	selected_detail = -1 if selected_detail == index else index
	for i in detail_panels.size():
		detail_panels[i].visible = i == selected_detail
		detail_buttons[i].selected_visual = i == selected_detail
	$DetailSlot/Secondary.visible = selected_detail >= 0
