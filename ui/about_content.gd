class_name AboutContent
extends RefCounted

const PROJECT := "https://github.com/iceriny/keyabyss"


static func populate(parent: VBoxContainer) -> void:
	var title := PageShell.label(parent, "键渊 · 失控咒典", 30, Color("eee0b9"))
	title.custom_minimum_size.y = 54
	PageShell.label(parent, "词令共鸣", 18, Color("9eb5b3"))
	var credits := HBoxContainer.new()
	credits.add_theme_constant_override("separation", 30)
	parent.add_child(credits)
	PageShell.label(credits, "版本  " + str(ProjectSettings.get_setting("application/config/version")), 16)
	PageShell.label(credits, "作者  Iceriny", 16)
	_links(parent, [{"text": "项目 GitHub", "url": PROJECT}, {"text": "问题反馈", "url": PROJECT + "/issues"}])
	_links(parent, [{"text": "serinamisssu@gmail.com", "url": "mailto:serinamisssu@gmail.com"}])
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	parent.add_child(spacer)
	PageShell.label(parent, "许可与致谢", 22, Color("d4c395"))
	PageShell.label(parent, "游戏源码依 GNU GPL-3.0 许可发布；字体、词库与其他第三方素材遵循各自许可。", 17)
	_links(parent, [{"text": "GPL-3.0 许可全文", "url": PROJECT + "/blob/main/LICENSE"}, {"text": "第三方许可", "url": PROJECT + "/blob/main/THIRD_PARTY_NOTICES.md"}])
	PageShell.label(parent, "字体采用汇文明朝体与京華老宋体 v3.0，感谢特里王与特里活字库，以及开源依赖、词库项目的作者和贡献者。", 17, Color("a5b5b2"))
	_links(parent, [{"text": "特里活字库", "url": "https://huozi.cool/"}])
	PageShell.label(parent, "保存在此设备", 22, Color("d4c395"))
	PageShell.label(parent, "设置、自定义词库与玩家存档保存在本机的游戏用户数据目录中。卸载或清理该目录前，请备份需要保留的数据。", 17, Color("a5b5b2"))
	var location := PageShell.label(parent, OS.get_user_data_dir(), 14, Color("839b98"))
	location.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY


static func _links(parent: VBoxContainer, entries: Array[Dictionary]) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 26)
	row.add_theme_constant_override("v_separation", 12)
	parent.add_child(row)
	for entry in entries:
		var link := LinkButton.new()
		link.text = entry.text
		link.uri = entry.url
		link.focus_mode = Control.FOCUS_NONE
		link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		link.add_theme_font_override("font", PageShell.SMALL_FONT)
		link.add_theme_font_size_override("font_size", 16)
		link.add_theme_color_override("font_color", Color("c7bb92"))
		row.add_child(link)
