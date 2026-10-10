class_name RelicGlyph
extends Control
## Named objects, operation engravings and an individual leaf signature.

const OUTLINES := {
	"nib": [Vector2(0, -0.72), Vector2(0.46, 0.15), Vector2(0.22, 0.65), Vector2(-0.22, 0.65), Vector2(-0.46, 0.15), Vector2(0, -0.72)],
	"rod": [Vector2(-0.34, 0.66), Vector2(0.24, -0.66), Vector2(0.4, -0.59), Vector2(-0.18, 0.73), Vector2(-0.34, 0.66)],
	"bottle": [Vector2(-0.2, -0.68), Vector2(0.2, -0.68), Vector2(0.2, -0.34), Vector2(0.48, -0.12), Vector2(0.46, 0.56), Vector2(-0.46, 0.56), Vector2(-0.48, -0.12), Vector2(-0.2, -0.34), Vector2(-0.2, -0.68)],
	"bookmark": [Vector2(-0.32, -0.65), Vector2(0.32, -0.65), Vector2(0.32, 0.68), Vector2(0, 0.43), Vector2(-0.32, 0.68), Vector2(-0.32, -0.65)],
	"stamp": [Vector2(-0.16, -0.68), Vector2(0.16, -0.68), Vector2(0.22, 0.12), Vector2(0.53, 0.34), Vector2(0.53, 0.57), Vector2(-0.53, 0.57), Vector2(-0.53, 0.34), Vector2(-0.22, 0.12), Vector2(-0.16, -0.68)],
	"page": [Vector2(-0.46, -0.62), Vector2(0.16, -0.62), Vector2(0.47, -0.28), Vector2(0.47, 0.62), Vector2(-0.46, 0.62), Vector2(-0.46, -0.62)],
	"book": [Vector2(0, -0.4), Vector2(-0.62, -0.59), Vector2(-0.62, 0.5), Vector2(0, 0.68), Vector2(0.62, 0.5), Vector2(0.62, -0.59), Vector2(0, -0.4), Vector2(0, 0.68)],
	"crystal": [Vector2(0, -0.72), Vector2(0.47, -0.17), Vector2(0.35, 0.46), Vector2(0, 0.7), Vector2(-0.35, 0.46), Vector2(-0.47, -0.17), Vector2(0, -0.72)],
	"crown": [Vector2(-0.55, 0.49), Vector2(-0.69, -0.4), Vector2(-0.3, -0.05), Vector2(0, -0.65), Vector2(0.3, -0.05), Vector2(0.69, -0.4), Vector2(0.55, 0.49), Vector2(-0.55, 0.49)],
	"hourglass": [Vector2(-0.43, -0.63), Vector2(0.43, -0.63), Vector2(0.35, -0.35), Vector2(0.1, 0), Vector2(0.35, 0.35), Vector2(0.43, 0.63), Vector2(-0.43, 0.63), Vector2(-0.35, 0.35), Vector2(-0.1, 0), Vector2(-0.35, -0.35), Vector2(-0.43, -0.63)],
	"bell": [Vector2(-0.55, 0.39), Vector2(-0.39, 0.05), Vector2(-0.33, -0.36), Vector2(0, -0.58), Vector2(0.33, -0.36), Vector2(0.39, 0.05), Vector2(0.55, 0.39), Vector2(-0.55, 0.39)],
	"ruler": [Vector2(-0.62, 0.38), Vector2(0.49, -0.62), Vector2(0.7, -0.38), Vector2(-0.4, 0.62), Vector2(-0.62, 0.38)],
	"compass": [Vector2(0.2, -0.64), Vector2(0.34, 0.28), Vector2(-0.2, 0.64), Vector2(-0.34, -0.28), Vector2(0.2, -0.64)],
	"clamp": [Vector2(-0.55, -0.47), Vector2(-0.55, 0.36), Vector2(-0.3, 0.57), Vector2(0.3, 0.57), Vector2(0.55, 0.36), Vector2(0.55, -0.47)],
	"box": [Vector2(-0.58, -0.2), Vector2(0, -0.5), Vector2(0.58, -0.2), Vector2(0.58, 0.43), Vector2(0, 0.73), Vector2(-0.58, 0.43), Vector2(-0.58, -0.2), Vector2(0, 0.1), Vector2(0.58, -0.2)],
	"tube": [Vector2(-0.55, 0.62), Vector2(-0.55, -0.23), Vector2(-0.36, -0.53), Vector2(0.35, -0.53), Vector2(0.55, -0.32), Vector2(0.55, 0.18)],
	"needle": [Vector2(-0.38, 0.71), Vector2(0.25, -0.67), Vector2(0.42, -0.57), Vector2(-0.38, 0.71)],
	"stone": [Vector2(-0.54, 0.34), Vector2(-0.45, -0.28), Vector2(-0.1, -0.57), Vector2(0.39, -0.4), Vector2(0.59, 0.15), Vector2(0.26, 0.62), Vector2(-0.31, 0.58), Vector2(-0.54, 0.34)],
	"knife": [Vector2(-0.47, 0.69), Vector2(-0.05, 0.1), Vector2(0.34, -0.68), Vector2(0.49, -0.3), Vector2(0.1, 0.28), Vector2(-0.3, 0.79), Vector2(-0.47, 0.69)],
	"cup": [Vector2(-0.57, -0.52), Vector2(0.6, -0.52), Vector2(0.39, 0.6), Vector2(-0.39, 0.6), Vector2(-0.57, -0.52)],
	"shoe": [Vector2(-0.61, -0.49), Vector2(-0.24, -0.49), Vector2(-0.17, 0.07), Vector2(0.51, 0.27), Vector2(0.63, 0.53), Vector2(-0.62, 0.53), Vector2(-0.61, -0.49)],
	"fold": [Vector2(-0.7, 0), Vector2(-0.32, -0.12), Vector2(0, -0.67), Vector2(0.32, -0.12), Vector2(0.7, 0), Vector2(0, 0.61), Vector2(-0.7, 0), Vector2(0, 0.08), Vector2(0.7, 0)],
}

var definition: CombatContentDefinition
@export var tint := Color("d8bc80")


func _ready() -> void:
	custom_minimum_size = custom_minimum_size.max(Vector2(56, 56))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if definition != null:
		draw_glyph(self, size * 0.5, minf(size.x, size.y) * 0.43, definition, tint)


static func draw_glyph(surface: CanvasItem, center: Vector2, radius: float, item: CombatContentDefinition, color: Color) -> void:
	var line := maxf(1.0, radius / 17.0)
	var motif := _motif(item.title)
	if item.title.contains("双生") or item.title.contains("双尖"):
		_draw_object(surface, center + Vector2(-0.21, 0.07) * radius, radius * 0.77, motif, color, line)
		_draw_object(surface, center + Vector2(0.21, -0.07) * radius, radius * 0.77, motif, color, line)
	else:
		_draw_object(surface, center, radius, motif, color, line)
	if motif in ["bottle", "bookmark", "page", "crystal", "cup", "ring", "stone"]:
		var terms := str(item.title)
		for rule in item.rules:
			terms += " " + str(rule.operation)
			for parameter in rule.parameters: terms += " " + str(parameter)
		_draw_engraving(surface, center + Vector2(0, 0.08) * radius, radius * 0.32, terms, color, line * 0.85)
	var signature := str(item.id).substr(1).to_int()
	for index in 8:
		var direction := Vector2.from_angle(index * TAU / 8.0 - PI * 0.5)
		var point := center + direction * radius * 0.88
		if signature & (1 << index):
			var leaf := PackedVector2Array([point - direction * radius * 0.10, point + direction.rotated(0.9) * radius * 0.14, point + direction * radius * 0.13, point - direction * radius * 0.10])
			surface.draw_polyline(leaf, color, line * 0.8, true)
		else:
			surface.draw_circle(point, line * 0.65, Color(color, 0.5))


static func _motif(title: String) -> String:
	for entry in [
		["exclamation", ["惊叹"]], ["stop", ["终止"]],
		["feather", ["羽毛", "羽签", "轻羽"]], ["nib", ["笔尖", "笔锋", "抄笔"]], ["rod", ["笔杆", "笔套", "笔架"]],
		["shoe", ["鞋"]], ["knife", ["刀"]], ["crown", ["冠"]], ["hourglass", ["沙漏", "砂钟"]], ["bell", ["铃"]],
		["compass", ["罗盘", "路标"]], ["ruler", ["尺"]], ["lens", ["镜", "玻片", "底片"]], ["gear", ["齿轮", "开关"]],
		["coil", ["线圈", "接点", "电桥"]], ["net", ["网", "筛", "粉", "砂", "灰"]], ["tube", ["吸管", "虹吸"]],
		["valve", ["阀"]], ["needle", ["针", "钉"]], ["clamp", ["夹", "扣"]], ["box", ["匣", "袋"]],
		["cup", ["杯", "陶胆", "晶胆"]], ["crystal", ["晶", "棱", "楔"]], ["stone", ["石", "坠", "镇"]],
		["thread", ["绳", "线", "索", "丝", "缝", "引线"]], ["stamp", ["印", "蜡", "标章", "雷章"]],
		["bookmark", ["签", "封条", "书票"]], ["ring", ["环", "结界"]], ["beads", ["连珠"]],
		["fold", ["使魔", "军团"]], ["book", ["书封", "封皮", "圣典", "残卷", "禁卷", "抄本", "底本", "卷", "字谱", "簿", "誓书"]],
		["bottle", ["墨水", "墨瓶", "银墨", "余烬墨", "墨囊", "墨池"]], ["drop", ["墨迹", "墨点", "墨核", "封釉"]],
		["page", ["页", "片", "箔", "内衬", "字帖", "字模", "折痕"]]]:
		for word: String in entry[1]:
			if title.contains(word): return entry[0]
	return "script"


static func _stroke(surface: CanvasItem, center: Vector2, radius: float, points: Array, color: Color, line: float) -> void:
	var path := PackedVector2Array()
	for point: Vector2 in points: path.append(center + point * radius)
	surface.draw_polyline(path, color, line, true)


static func _draw_object(surface: CanvasItem, center: Vector2, radius: float, motif: String, color: Color, line: float) -> void:
	if OUTLINES.has(motif): _stroke(surface, center, radius, OUTLINES[motif], color, line)
	match motif:
		"exclamation":
			_stroke(surface, center, radius, [Vector2(-0.07, -0.65), Vector2(0.07, -0.65), Vector2(0, 0.19), Vector2(-0.07, -0.65)], color, line)
			surface.draw_circle(center + Vector2(0, 0.51) * radius, radius * 0.11, color)
		"stop":
			surface.draw_circle(center, radius * 0.55, color, false, line, true)
			_stroke(surface, center, radius, [Vector2(-0.23, -0.23), Vector2(0.23, -0.23), Vector2(0.23, 0.23), Vector2(-0.23, 0.23), Vector2(-0.23, -0.23)], color, line)
		"nib":
			_stroke(surface, center, radius, [Vector2(0, -0.69), Vector2(0, 0.13)], color, line)
			surface.draw_circle(center + Vector2(0, 0.18) * radius, radius * 0.07, color, false, line, true)
		"rod", "knife", "needle":
			_stroke(surface, center, radius, [Vector2(-0.2, 0.22), Vector2(0.02, 0.32)], color, line)
		"bottle":
			_stroke(surface, center, radius, [Vector2(-0.26, -0.49), Vector2(0.26, -0.49)], color, line)
		"page":
			_stroke(surface, center, radius, [Vector2(0.16, -0.62), Vector2(0.16, -0.28), Vector2(0.47, -0.28)], color, line)
		"book":
			for side in [-1, 1]:
				for y in [-0.13, 0.12, 0.37]:
					_stroke(surface, center, radius, [Vector2(side * 0.14, y), Vector2(side * 0.47, y - 0.09)], Color(color, 0.6), line * 0.75)
		"stamp", "crown", "bell":
			_stroke(surface, center, radius, [Vector2(-0.39, 0.43), Vector2(0.39, 0.43)], color, line)
			if motif == "bell": surface.draw_circle(center + Vector2(0, 0.57) * radius, radius * 0.09, color, false, line, true)
		"crystal":
			_stroke(surface, center, radius, [Vector2(0, -0.72), Vector2(-0.17, -0.17), Vector2(0, 0.7), Vector2(0.17, -0.17), Vector2(0, -0.72)], Color(color, 0.55), line * 0.7)
		"hourglass":
			_stroke(surface, center, radius, [Vector2(-0.25, 0.47), Vector2(0, 0.14), Vector2(0.25, 0.47)], color, line)
		"ruler":
			for index in 5:
				var start := Vector2(-0.43, 0.2) + Vector2(0.19, -0.17) * index
				_stroke(surface, center, radius, [start, start + Vector2(0.09, 0.1)], color, line)
		"compass", "ring", "lens":
			surface.draw_arc(center, radius * 0.63, 0, TAU, 48, color, line, true)
			if motif == "lens":
				_stroke(surface, center, radius, [Vector2(-0.33, -0.16), Vector2(-0.07, -0.4)], Color(color, 0.6), line)
			elif motif == "compass":
				surface.draw_circle(center, radius * 0.08, color)
		"gear":
			var points: Array[Vector2] = []
			for index in 33:
				points.append(Vector2.from_angle(index * TAU / 32.0) * (0.67 if index % 4 in [1, 2] else 0.49))
			_stroke(surface, center, radius, points, color, line)
			surface.draw_circle(center, radius * 0.21, color, false, line, true)
		"coil":
			var points: Array[Vector2] = []
			for index in 65:
				var t := index / 64.0
				points.append(Vector2(-0.58 + t * 1.16, sin(t * TAU * 3) * 0.34))
			_stroke(surface, center, radius, points, color, line)
		"net":
			for index in 4:
				var offset := -0.46 + index * 0.3
				_stroke(surface, center, radius, [Vector2(offset, -0.55), Vector2(offset + 0.15, 0.55)], color, line * 0.8)
				_stroke(surface, center, radius, [Vector2(-0.55, offset), Vector2(0.55, offset + 0.15)], color, line * 0.8)
		"clamp":
			_stroke(surface, center, radius, [Vector2(-0.29, -0.34), Vector2(-0.29, 0.29), Vector2(0.29, 0.29), Vector2(0.29, -0.34)], color, line)
		"box":
			_stroke(surface, center, radius, [Vector2(0, 0.1), Vector2(0, 0.73)], color, line)
		"valve":
			_stroke(surface, center, radius, [Vector2(-0.65, -0.12), Vector2(-0.17, -0.12), Vector2(-0.17, 0.15), Vector2(0.65, 0.15)], color, line * 1.3)
			surface.draw_circle(center + Vector2(0.17, -0.37) * radius, radius * 0.27, color, false, line, true)
			_stroke(surface, center, radius, [Vector2(0.17, -0.64), Vector2(0.17, 0.15)], color, line)
		"cup":
			for y in [-0.19, 0.12, 0.37]:
				_stroke(surface, center, radius, [Vector2(0.19, y), Vector2(0.41, y)], color, line * 0.8)
		"shoe":
			_stroke(surface, center, radius, [Vector2(-0.62, 0.35), Vector2(0.51, 0.35)], color, line)
		"fold":
			_stroke(surface, center, radius, [Vector2(0, -0.67), Vector2(0, 0.61)], color, line)
		"feather", "drop", "thread":
			var points: Array[Vector2] = []
			for index in 33:
				var t := index / 32.0
				if motif == "thread": points.append(Vector2(sin(t * TAU * 1.5) * 0.42, t * 1.3 - 0.65))
				elif motif == "feather": points.append(Vector2(sin(t * TAU) * 0.32 + (t - 0.5) * 0.65, cos(t * TAU) * 0.66))
				else: points.append(Vector2(sin(t * TAU) * (0.32 - cos(t * TAU) * 0.13), cos(t * TAU) * 0.66))
			_stroke(surface, center, radius, points, color, line)
			if motif == "feather":
				_stroke(surface, center, radius, [Vector2(-0.4, 0.7), Vector2(0.31, -0.64)], color, line)
		"beads":
			for index in 4:
				var point := center + Vector2.from_angle(-1.9 + index * 0.84) * radius * 0.48
				surface.draw_circle(point, radius * 0.2, color, false, line, true)
		"script":
			for index in 3:
				var y := -0.39 + index * 0.39
				_stroke(surface, center, radius, [Vector2(-0.58, y), Vector2(-0.24, y - 0.09), Vector2(-0.03, y + 0.1), Vector2(0.26, y - 0.06), Vector2(0.53 - index * 0.13, y)], color, line)


static func _draw_engraving(surface: CanvasItem, center: Vector2, radius: float, terms: String, color: Color, line: float) -> void:
	if "cold" in terms or "freeze" in terms or "寒" in terms or "冰" in terms:
		for index in 3:
			var axis := Vector2.from_angle(index * PI / 3.0)
			surface.draw_line(center - axis * radius, center + axis * radius, color, line, true)
	elif "charge" in terms or "conduct" in terms or "电" in terms or "雷" in terms:
		_stroke(surface, center, radius, [Vector2(0.35, -1), Vector2(-0.44, 0.05), Vector2(0.38, -0.05), Vector2(-0.3, 1)], color, line)
	elif "heat" in terms or "dot" in terms or "烬" in terms or "热" in terms:
		_stroke(surface, center, radius, [Vector2(0, -1), Vector2(-0.7, 0.27), Vector2(-0.32, 0.85), Vector2(0.35, 0.85), Vector2(0.7, 0.24), Vector2(0, -1)], color, line)
	elif "heal" in terms or "hp" in terms:
		_stroke(surface, center, radius, [Vector2(-0.7, 0), Vector2(0.7, 0)], color, line)
		_stroke(surface, center, radius, [Vector2(0, -0.7), Vector2(0, 0.7)], color, line)
	elif "storage" in terms or "copy" in terms:
		_stroke(surface, center, radius, [Vector2(-0.7, -0.5), Vector2(0.35, -0.5), Vector2(0.35, 0.6), Vector2(-0.7, 0.6), Vector2(-0.7, -0.5)], color, line)
		_stroke(surface, center, radius, [Vector2(-0.3, -0.8), Vector2(0.7, -0.8), Vector2(0.7, 0.3)], color, line)
