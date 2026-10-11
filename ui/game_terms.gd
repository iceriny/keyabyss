class_name GameTerms
extends RefCounted
## One glossary shared by every prose surface. Longest matches win.

const TEXT := {
	"词咒": "敌人或道具头顶可输入的单词。输入首字符锁定目标，完成后施法或使用道具。",
	"词令": "菜单上的英文操作指令。完整输入后执行对应操作。",
	"强化施法": "每第三次对敌人施法得到强化；道具词咒不会推进这个节奏。",
	"亲手完成": "整个词咒都由本次人工输入完成；主动补全与继承字符不计入。",
	"连笔": "连续完词积累，最多计10层；受到生命伤害会损失部分连笔。",
	"共鸣": "输入、完词与防御积累的终式能量。终式持续期间不再积累。",
	"终式": "共鸣充满后，单独按下再松开Shift释放本书终式。",
	"御术": "按Space短暂防御敌弹与近身攻击；激光和爆圈需要闪避。",
	"完美御术": "御术起手0.10秒内挡住攻击：反弹直接命中的敌弹，或迎击近身攻击者，并短暂放慢时间。",
	"闪避": "方向键朝指定方向闪避，Alt自动选择落点。消耗一次充能，获得1秒无敌。",
	"完美闪避": "攻击即将命中时闪避，额外获得共鸣，并让慢时间持续到本次无敌结束。",
	"护盾": "先于生命承受伤害。治疗不会补充护盾。",
	"寒气": "减慢敌人的移动与攻击；超过90点时，消耗60点触发冻结。最多127点。",
	"冻结": "暂停敌人的动作；解冻后继续原动作。普通敌人再次冻结至少间隔1秒，首领为3秒。",
	"冻裂": "被冻结的敌人死亡时，引爆周围敌人并施加寒气；连锁最多三代。",
	"冰雾": "寒墨闪避留下的区域，会积累寒气并遮挡远处敌人的视线。",
	"灼烧": "超过10点时持续造成伤害，每跳消耗5点，降至10点后停止。最多127点。",
	"燃烧": "灼烧超过10点时的状态；橙色生命尾段估计剩余灼烧伤害。",
	"火雾": "持续施加灼烧的区域；重叠区域的额外收益逐层减半。",
	"焰印": "灰烬第三次施法的强化火弹；命中后爆炸并留下火雾。",
	"感电": "让电链接入更远的敌人；超过30点时，主电链命中会消耗10点充能并多跳一次。最多127点。",
	"充能": "主电链消耗目标的感电，提高后续伤害，并增加一次跳跃；同一条链不会反复命中同一敌人。",
	"电链": "连接多个敌人的雷电。主电链逐段衰减，每条链对同一敌人只命中一次。",
	"电爆": "雷鸣强化施法对命中目标周围产生的范围放电；不会再分出额外电链。",
	"过载": "由避雷印等遗物触发的爆炸；需要对应遗物，与强化施法的电爆分别结算。",
	"易伤": "按点数提高敌人受到的伤害，127点时提高200%；停笔后逐渐消退。",
	"纸灵": "输入唤醒的随行纸灵，会自动游击标记目标。停笔后逐只休眠，换页重新唤醒。",
	"交叉斩": "纸灵法书第三次施法，指挥已唤醒的纸灵一起攻击当前目标。",
	"符文纸鹤": "纸灵闪避留下的折纸。拦截一颗敌弹后，向敌人反击并消失。",
	"腐蚀": "直接施法附加的持续伤害；同一目标最多叠3层，重新命中会续时。",
	"主动补全": "先亲手输入部分词咒，再按Ctrl消耗一次机会补齐。补出的字符不增加威力或成长。",
	"觉醒": "本书的强力分支。满足指定遗物与层数后才会出现；同一法书的觉醒只能选择一种。",
	"冰河纪事": "寒墨终式：获得护盾，在领域内积累寒气并从不同方向发射冰锥。",
	"焚世余烬": "灰烬终式：全场火浪之后留下火域，持续施加灼烧并独立造成伤害。",
	"雷鸣终章": "雷鸣终式：领域持续施加感电，期间每次施法都附带电爆。",
	"千纸夜行": "纸灵终式：唤醒纸灵并使其狂暴，提高攻击、飞行速度和攻击频率。",
}
const CAPABILITIES := {"cold": "寒气", "freeze": "冻结", "frost_shatter": "冻裂", "burn": "灼烧", "fire_field": "火雾", "chain": "电链", "shock": "感电", "spirit": "纸灵", "mark": "易伤", "shield": "护盾", "overload": "过载", "area": "范围攻击", "copy": "复制"}
static var _pattern: RegEx


static func matches(value: String) -> Array[RegExMatch]:
	if _pattern == null:
		var terms: Array = TEXT.keys()
		terms.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length() if a.length() != b.length() else a < b)
		_pattern = RegEx.create_from_string("|".join(terms))
	return _pattern.search_all(value)


static func explanation(term: String, build: CompiledBuild = null) -> String:
	var result: String = TEXT.get(term, "")
	if build == null: return result
	match term:
		"护盾": result += "\n当前上限：%d。" % RelicParameters.shield_capacity(build)
		"御术": result += "\n当前冷却：%s秒。" % GameText.number(RelicParameters.parry_cooldown(build))
		"寒气": result += "\n当前寒气增幅：%s%%。" % GameText.number(build.modifier(&"cold_pct"))
		"冻结": result += "\n当前普通／首领时长：%s／%s秒。" % [GameText.number(RelicParameters.freeze_duration(build)), GameText.number(RelicParameters.freeze_duration(build, true))]
		"纸灵": result += "\n停笔后可维持：%s秒。" % GameText.number(RelicParameters.spirit_duration(build))
		"灼烧": result += "\n每%s秒结算一跳。" % GameText.number(SpellRuntime.BURN_INTERVAL)
		"共鸣": result += "\n当前获取增幅：%s%%。" % GameText.number(((1.0 + build.relic_number(&"R040", &"resonance_pct") / 100.0) * RelicParameters.ratio(build, &"resonance_pct") - 1.0) * 100.0)
		"终式", "冰河纪事", "焚世余烬", "雷鸣终章", "千纸夜行": result += "\n本书当前持续：%s秒。" % GameText.number(RelicParameters.ultimate_duration(build))
	return result
