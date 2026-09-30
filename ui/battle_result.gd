class_name BattleResult
extends VBoxContainer


func configure(session: BattleSession, book: BookPresentation, abandoned: bool) -> void:
	var won := session.result > 0
	var tint := Color("dfc58b") if won else (Color("9bb8c8") if abandoned else Color("d58f83"))
	$Intro/Seal/Art.texture = book.seal
	$Intro/Seal/Art.modulate = Color(tint, 0.5)
	$Intro/Seal/Character.text = "成" if won else ("归" if abandoned else "殁")
	$Intro/Seal/Character.modulate = tint
	$Intro/Words/Eyebrow.text = "THE CHRONICLE REWRITTEN" if won else ("RETURN TO THE ARCHIVE" if abandoned else "THE INK FALLS SILENT")
	$Intro/Words/Eyebrow.modulate = tint
	$Intro/Words/Line.text = "此页已明，墨迹留存。" if won else ("合上这一页，带着所学重返书库。" if abandoned else "此页止于此刻，未竟之言留待下一次书写。")
	$Intro/Stamp.text = "胜利" if won else ("主动结束" if abandoned else "战败")
	$Intro/Stamp.modulate = tint
	$Stage.text = "第 1 章 · 失落书库     第 %d / %d 波" % [session.wave, session.encounter.wave_count]
	var kills := 0
	for enemy in session.enemies:
		if not enemy.alive():
			kills += 1
	var inputs := session.manual_characters + session.typing.mistakes
	$Stats/Kills.display(str(kills), tint)
	$Stats/Combo.display("—", tint)
	$Stats/Accuracy.display("%.1f%%" % (100.0*session.manual_characters/inputs) if inputs > 0 else "—", tint)
	$Stats/Wpm.display(str(roundi(session.manual_characters*12.0/session.elapsed)) if session.elapsed > 0.0 else "—", tint)
	$Stats/Time.display("%02d:%02d" % [floori(session.elapsed/60.0), floori(fmod(session.elapsed,60.0))], tint)
	$Stats/Casts.display(str(session.completed_words), tint)
	$Input.text = "正确 / 错误输入   %d / %d      剩余生命   %d / %d" % [session.manual_characters, session.typing.mistakes, ceili(float(session.player_hp_q)/BattleSession.Q), ceili(float(session.player_max_hp_q)/BattleSession.Q)]
	$Columns/Build/Book.text = book.title + " · 主书独行"
	$Columns/Build/Description.text = book.description
