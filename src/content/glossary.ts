import { BOOKS, TYPES, ELITES, RELICS, ROUTES } from "./catalog.ts";
import { DEFENSE } from "../shared/defense.ts";

export interface GlossaryEntry {
  id: string;
  name: string;
  category: string;
  description: string;
  aliases?: readonly string[];
}
const term = (
  id: string,
  name: string,
  category: string,
  description: string,
  aliases: string[] = [],
): GlossaryEntry => ({ id, name, category, description, aliases });

/** Gameplay concepts are authored here; named content below reuses its original definitions. */
export const TERMS: readonly GlossaryEntry[] = [
  term(
    "cast",
    "施法",
    "操作",
    "完成目标身上的一整条咒文，释放当前咒典的法术。不同咒典拥有不同的弹道、命中效果与强化节奏。",
    ["完词"],
  ),
  term(
    "spell-word",
    "咒文",
    "操作",
    "战场单位身上的可输入词条。首字符锁定目标；错字保留已输入进度。Tab 切换同前缀目标，退格取消锁定。",
  ),
  term(
    "command",
    "词令",
    "操作",
    "菜单按钮旁的英文指令。连续输入完整词令即可执行；Esc 清空当前输入。战斗中输入的是咒文。",
  ),
  term(
    "parry",
    "弹反",
    "防御",
    `轻按 Space 开启 ${DEFENSE.window} 秒弹反窗口，基础冷却 ${DEFENSE.cooldown} 秒，使用次数不限。反射近身敌弹；对接触或冲锋敌人造成 ${DEFENSE.damage} 点基础伤害并强力击退。成功后同时无伤推开周边敌人，短暂时缓后平滑恢复；周边压力不清除或推开弹道。无法反射激光或地面爆炸。`,
    ["反弹"],
  ),
  term(
    "dodge",
    "闪避",
    "防御",
    `方向键立即朝对应方向闪避；Alt 自动选择威胁较低的落点。消耗闪避充能，获得 ${DEFENSE.dodgeInvulnerability} 秒无敌。自动择位仍可能遇到后续攻击。`,
  ),
  term(
    "invulnerability",
    "无敌",
    "防御",
    "持续期间免受伤害。闪避提供的无敌按真实时间计算，不受停笔减速影响。",
  ),
  term(
    "shield",
    "护盾",
    "防御",
    "受击时优先消耗护盾，剩余伤害再扣除生命。护盾不会提高最大生命。",
  ),
  term(
    "health",
    "生命",
    "防御",
    "生命耗尽即结束本局。恢复无法超过最大生命；护盾与生命分别计算。",
  ),
  term(
    "cooldown",
    "冷却",
    "防御",
    "能力再次使用前需要等待的时间。弹反冷却与闪避充能均按真实时间恢复。",
    ["内置冷却"],
  ),
  term(
    "charge",
    "闪避充能",
    "防御",
    "每次闪避消耗 1 次充能，并随时间恢复。遗物可以增加充能上限或加快恢复。",
  ),
  term(
    "graze",
    "擦弹",
    "防御",
    "在未被命中的情况下与敌弹近距离擦过，可获得共鸣；同一颗子弹只结算一次。",
  ),
  term(
    "combo",
    "连笔",
    "成长",
    "连续完成咒文积累的连击记录。保持准确输入可延续节奏；错字或受伤会损失连笔。",
    ["连击"],
  ),
  term(
    "resonance",
    "共鸣",
    "成长",
    "完词与擦弹等行为积累的终式能量。达到 100% 后，单独轻按 Shift 释放终式。",
  ),
  term(
    "ultimate",
    "终式",
    "成长",
    "当前咒典的强力能力。消耗蓄满的共鸣释放；持续时间和战斗效果由咒典与觉醒遗物决定。",
    ["大招"],
  ),
  term(
    "experience",
    "经验",
    "成长",
    "击破敌人获得经验，蓄满后提升等级并获得遗物选择机会。",
    ["XP"],
  ),
  term(
    "relic",
    "遗物",
    "构筑",
    "本局获得的被动强化。相同遗物可以叠加至各自上限；效果可能强化施法、生存或咒典特性。",
  ),
  term(
    "awaken",
    "觉醒",
    "构筑",
    "专属咒典的高阶遗物。满足列出的前置遗物后才进入奖励候选池。",
  ),
  term(
    "curse",
    "诅咒",
    "构筑",
    "以额外代价换取强力收益的遗物。代价与收益均写在该遗物的说明中。",
  ),
  term(
    "build",
    "构筑",
    "构筑",
    "当前咒典与本局遗物形成的能力组合。暂停后可查看已持有遗物及叠加数量。",
  ),
  term("reroll", "重掷", "构筑", "消耗重掷次数，重新生成当前遗物候选。"),
  term(
    "cold",
    "寒气",
    "冰霜",
    "命中积累寒气，达到 100 时清空寒气并使敌人冻结。零度批注可增加寒气与冻结时长。",
  ),
  term(
    "freeze",
    "冻结",
    "冰霜",
    "短暂阻止敌人行动。普通敌人的冲锋会被打断；守页者冻结时间较短。冻结目标可触发冻裂或额外伤害。",
  ),
  term(
    "shatter",
    "冻裂",
    "冰霜",
    "冻结目标被击碎时产生的范围爆裂，可通过遗物强化伤害、连锁或冰针。",
    ["碎裂"],
  ),
  term(
    "frost-field",
    "霜场",
    "冰霜",
    "留在场地上的冰霜区域，对其中敌人持续施加寒气。",
  ),
  term(
    "ice-lance",
    "重型冰矛",
    "冰霜",
    "寒墨之书每第 4 次施法的强化冰枪，穿透敌人并击碎冻结目标。",
    ["重型冰枪"],
  ),
  term(
    "ice-shot",
    "冰枪",
    "冰霜",
    "寒墨之书发射的冰霜弹道，有飞行时间，命中可穿透、击退并留下霜场。",
    ["冰矛"],
  ),
  term(
    "ice-needle",
    "冰针",
    "冰霜",
    "由冰霜终式或特定遗物发射的小型冰霜攻击。冰针雨可以覆盖大范围战场。",
  ),
  term(
    "chain",
    "连锁",
    "雷鸣",
    "一次攻击从目标跳向附近其他敌人。电弧跳跃数量与伤害衰减可由遗物调整。",
    ["电弧", "传导"],
  ),
  term("conduct", "导电", "雷鸣", "目标积累至 3 层导电时清空层数并触发过载。"),
  term(
    "overload",
    "过载",
    "雷鸣",
    "导电叠满触发的范围爆炸。相关遗物可强化爆炸、牵引敌人或清除敌弹。",
  ),
  term(
    "mark",
    "标记",
    "纸灵",
    "纸灵之书施法标记目标，让已唤醒的纸灵优先集火。标记会随时间消退。",
    ["集火"],
  ),
  term(
    "spirit",
    "纸灵",
    "纸灵",
    "自动寻找目标并俯冲攻击的召唤物。纸灵之书每次完词唤醒 1 只，基础上限 3 只；遗物与终式可增加上限，灵力耗尽后休眠。",
  ),
  term(
    "spirit-energy",
    "灵力",
    "纸灵",
    "维持纸灵活跃的剩余时间。继续完词可以延长维持时间；耗尽后需要重新逐只唤醒。",
  ),
  term(
    "cross-slash",
    "交叉斩",
    "纸灵",
    "纸灵之书每第 3 次施法触发的额外交叉斩击。",
  ),
  term(
    "burn",
    "灼烧",
    "火焰",
    "持续伤害状态，基础每 0.5 秒结算一次，持续 3 秒，最多叠加 3 层。遗物可以提高伤害、持续时间和层数上限。",
    ["燃烧"],
  ),
  term(
    "fire-field",
    "火场",
    "火焰",
    "火焰留在地面的持续区域，对经过的敌人造成伤害并施加灼烧。",
  ),
  term(
    "fireball",
    "熔爆",
    "火焰",
    "灰烬之书每第 3 次施法发射强化火球，命中造成范围爆炸并留下火场。",
  ),
  term(
    "meteor",
    "陨火",
    "火焰",
    "焚世余烬期间降下的追踪火焰攻击。觉醒可延长终式并缩短陨火间隔。",
  ),
  term(
    "critical",
    "暴击",
    "伤害",
    "强化单次攻击的伤害。惊叹号使每第 4 次直接施法造成 2 倍伤害。",
  ),
  term(
    "direct",
    "直接施法",
    "伤害",
    "由完成目标咒文直接发出的主法术。遗物若限定直接施法，通常不会由连锁、纸灵或持续伤害再次触发。",
  ),
  term(
    "pierce",
    "穿透",
    "伤害",
    "弹道命中后继续飞行，可命中后方敌人，直到穿透次数耗尽。",
  ),
  term(
    "knockback",
    "击退",
    "伤害",
    "将敌人推离命中位置。强力击退可引发撞墙或撞敌的碰撞伤害。",
  ),
  term(
    "pull",
    "牵引",
    "伤害",
    "将附近敌人拉向指定位置，便于范围攻击、穿透与连锁。",
  ),
  term(
    "corrosion",
    "腐蚀",
    "伤害",
    "腐蚀墨迹施加的可叠层持续伤害，与火焰灼烧分别计算。",
  ),
  term(
    "execution",
    "处决",
    "伤害",
    "终止符可直接击杀生命低于 18% 的普通敌人；守页者不会被处决，而是受到额外伤害。",
  ),
  term(
    "ward",
    "咒印",
    "战场",
    "绿色的非敌对道具单位。完成其咒文可清除敌弹与危险预警。",
  ),
  term(
    "boss",
    "守页者",
    "战场",
    "章节首领，具有独立攻击阶段。部分控制效果对守页者的持续时间或作用不同。",
    ["Boss"],
  ),
  term(
    "elite",
    "精英",
    "战场",
    "拥有更强属性或特殊攻击方式的敌人，可在试炼等战斗中出现。",
  ),
  term(
    "laser",
    "激光",
    "战场",
    "带预警的直线区域攻击，无法弹反，需要利用闪避的落点或无敌时间应对。",
  ),
  term(
    "charge-enemy",
    "冲锋",
    "战场",
    "敌人蓄力后沿预定方向突进。近身时可弹反，将其强力击退。",
  ),
  term(
    "progressive",
    "渐进词长",
    "词库",
    "开启后随流程逐步引入更长咒文；关闭后直接使用所选词库的完整词长分布。战斗难度与词库分别选择。",
  ),
  term(
    "seed",
    "种子",
    "词库",
    "用于生成本局随机流程的标识。相同种子、词库与模式便于重现开局；留空会自动生成。",
  ),
  term(
    "loop",
    "周目",
    "成长",
    "完成三章后，可携当前构筑继续挑战更高强度的下一轮流程。",
  ),
  ...Object.values(BOOKS).map((b) =>
    term(
      `cadence-${b.id}`,
      b.cadence,
      "成长",
      `当前咒典的施法计数。每第 ${b.cycle} 次施法触发强化法术。`,
    ),
  ),
];

export const GLOSSARY: readonly GlossaryEntry[] = [
  ...TERMS,
  ...Object.values(BOOKS).flatMap((b) => [
    term(`book-${b.id}`, b.name, "咒典", b.detail),
    term(`ultimate-${b.id}`, b.ultimate, "终式", b.ultimateDesc),
  ]),
  ...RELICS.map((r) =>
    term(
      `relic-${r.id}`,
      r.name,
      "遗物",
      `${r.desc} 叠加上限：${r.max}。${r.requires ? `觉醒前置：${r.requires.map((id) => RELICS.find((x) => x.id === id)?.name).join("、")}。` : ""}`,
    ),
  ),
  ...Object.entries({ ...TYPES, ...ELITES }).map(([id, e]) =>
    term(`enemy-${id}`, e.name, "敌人", e.tip),
  ),
  ...ROUTES.map((r) => term(`route-${r.id}`, r.name, "路线", r.desc)),
];
export const glossaryById = new Map(GLOSSARY.map((entry) => [entry.id, entry]));
