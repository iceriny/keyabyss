import type { Relic } from '../../contracts/content.ts';
import type { CombatStat } from '../../contracts/stats.ts';
import type { CombatCapability } from '../../contracts/combat-weave.ts';
type Entry = [id: string, name: string, description: string, grants: Partial<Record<CombatStat, number>>];
interface Family { id: string; tag: string; provides?: CombatCapability[]; needs?: CombatCapability[]; modifies?: CombatCapability[]; entries: [Entry, Entry, Entry, Entry, Entry]; variant: Entry }

/** Each branch replaces its parent. Other compatible providers remain legitimate inputs. */
export const EXPANDED_RELIC_FAMILIES: readonly Family[] = [
  { id: 'copy', tag: '复写', provides: ['carrier'], entries: [
    ['copy-quill', '双尖抄笔', '以实际人工字符供给复写页，保存法术的基础形态。', { copyPages: 1 }],
    ['copy-margin', '宽边抄本', '提高复制威力折算并增加一格容量。', { copyEfficiency: .065, carrierCapacity: 1 }],
    ['copy-many', '分栏复写', '同一付费额度分成更多较弱片段，容量扩大。', { copyPages: 1, forkPayload: 1, carrierCapacity: 2, copyEfficiency: -.04 }],
    ['copy-deep', '重墨复写', '更少落点保存较强片段，增加交付等待。', { copyPages: 1, concentrate: 1, copyEfficiency: .1, carrierDelay: .35 }],
    ['copy-inherit', '同文底片', '复制继承合法加工方式；与晶壳、热加工和电性转交连接。', { copyInheritance: 1, materialConserve: .05 }],
  ], variant: ['copy-palimp', '覆写底本', '本局用部分复制威力换成加工继承与更高容量。', { copyPages: 1, copyInheritance: 1, carrierCapacity: 3, copyEfficiency: -.08 }] },
  { id: 'binding', tag: '装订', provides: ['guard'], needs: ['carrier'], modifies: ['release'], entries: [
    ['binding-clasp', '护文搭扣', '保存的法术可以消耗自身威力抵挡敌方普通子弹；用来挡弹的威力不能再用于攻击。', { carrierGuard: 1 }],
    ['binding-spine', '延寿书脊', '增加载体寿命和容量，保留已支付的反击机会。', { carrierLifetime: 1.6, carrierCapacity: 1 }],
    ['binding-guard', '守页装订', '优先保留防御页，延长留存，减少正常自动交付。', { carrierGuard: 1, carrierRetain: 1, carrierLifetime: 1.8 }],
    ['binding-cadence', '走页装订', '更快交付并缩短留存，防御可用窗口减少。', { carrierGuard: 1, carrierDelay: -.65, carrierLifetime: -1, copyCadence: 1 }],
    ['binding-coda', '终章扣', '终结时交出未用载荷，兼容受热与防御出口。', { carrierRelease: 1 },],
  ], variant: ['binding-newest', '新页守则', '优先消耗最新护页，把旧页留给原交付路径。', { carrierGuard: 1, guardNewest: 1, carrierRelease: 1, carrierCapacity: -1 }] },
  { id: 'crystal', tag: '晶壳', provides: ['cold'], entries: [
    ['crystal-seed', '空心晶种', '提供可加工晶体结构。', { crystalPayload: 1 }],
    ['crystal-wall', '层晶匣壁', '晶壳储存有限片段，提高留存寿命。', { crystalStorage: 1, carrierLifetime: 1.2 }],
    ['crystal-whole', '完整透镜', '集中晶体内的份额并穿透，减少碎片数量。', { crystalPayload: 1, concentrate: 1, payloadPierce: 1, fragmentCount: -1 }],
    ['crystal-brittle', '薄壁晶胆', '更易展开为多片，放弃部分本体份额。', { crystalPayload: 1, fragmentCount: 2, fragmentShare: .12 }],
    ['crystal-fuse', '熔缝晶扣', '热材料可提前释放晶壳内部片段。', { thermalRelease: 1, materialConserve: .05 }],
  ], variant: ['crystal-vault', '冰藏定本', '把晶体改作更耐久的容器，交付延迟。', { crystalPayload: 1, crystalStorage: 1, carrierCapacity: 2, carrierLifetime: 2, carrierDelay: .6 }] },
  { id: 'thermal', tag: '炉心', provides: ['heat'], entries: [
    ['thermal-wick', '字火灯芯', '亲手输入可积攒热量，用来增强法术或加热保存法术的外壳。', { heatPayload: 1 }],
    ['thermal-bellows', '页间风箱', '提高热材料供给率，扩大有限储备。', { materialRate: .1, heatCapacity: 15 }],
    ['thermal-patient', '缓燃炉膛', '保存更多热量，以更高阈值延迟兑现。', { heatPayload: 1, heatCapacity: 40, reserveThreshold: 14 }],
    ['thermal-flash', '速燃引线', '热量提前推动载体出口，留存缩短。', { heatPayload: 1, thermalRelease: 1, carrierLifetime: -1 }],
    ['thermal-siphon', '续写虹吸', '完词从上个合法人工目标抽取既存灼烧，折损后供下词使用。', { recoveryExtract: 1, heatRecovery: 1 }],
  ], variant: ['thermal-anneal', '退火封装', '较少即时威力换取晶壳封装与更高热量容量。', { heatPayload: 1, crystalStorage: 1, heatCapacity: 35, spellPower: -.04 }] },
  { id: 'conduction', tag: '电路', provides: ['conduction'], entries: [
    ['conduction-coil', '字电线圈', '人工字符供给可分配的有限电荷。', { conductionPayload: 1 }],
    ['conduction-braid', '双股导索', '延长电性片段传递范围并提高加工保留。', { chainReach: 65, materialConserve: .04 }],
    ['conduction-long', '长距孤弧', '减少落点以延伸距离，适合分散目标。', { conductionPayload: 1, chainReach: 145, chainCount: -1 }],
    ['conduction-mesh', '近距密网', '增加跳转分配，单份更薄且距离缩短。', { conductionPayload: 1, chainCount: 2, chainReach: -65 }],
    ['conduction-relay', '页桥接点', '把承载物加入有限电性路径，不复制整条链。', { carrierRelay: 1, chainReach: 35 }],
  ], variant: ['conduction-focus', '定向电桥', '把电性份额集中交付，牺牲广域跳转。', { conductionPayload: 1, concentrate: 1, chainCount: -1, chainShare: .06 }] },
  { id: 'geometry', tag: '几何', modifies: ['conduction', 'carrier'], entries: [
    ['geometry-compass', '寻页规', '扩大法术自动交付范围。', { chainReach: 65 }],
    ['geometry-map', '折距图', '扩大交付范围并延长载体等待。', { chainReach: 45, carrierLifetime: 1.2 }],
    ['geometry-lens', '收束透镜', '减少落点，集中已付威力，削减广域分配。', { chainReach: 65, concentrate: 1, chainCount: -1 }],
    ['geometry-fan', '展开扇尺', '把已有份额分给更多接收者，放弃单体集中。', { chainReach: 65, forkPayload: 1, fragmentCount: 1 }],
    ['geometry-corridor', '旁路图', '载体接力与未命中回收共同处理失去的目标。', { carrierRelay: 1, missRecovery: 1 }],
  ], variant: ['geometry-fold', '折叠走廊', '延长中继距离，增加交付等待并降低派生折算。', { carrierRelay: 1, chainReach: 170, carrierDelay: .4, reactionEfficiency: -.03 }] },
  { id: 'reserve', tag: '回收', provides: ['recovery'], needs: ['heat'], entries: [
    ['reserve-cruet', '余量小瓶', '回收合格灼烧剩余，折损入库。', { heatRecovery: 1 }],
    ['reserve-cistern', '储量夹层', '扩大储备容量，不增加回收率。', { heatCapacity: 45 }],
    ['reserve-wide', '宽口热匣', '高容量低效率，偏向积蓄与集中释放。', { heatRecovery: 1, heatCapacity: 65, recoveryEfficiency: -.07, reserveThreshold: 10 }],
    ['reserve-fine', '细口热匣', '高效率低容量，偏向持续周转。', { heatRecovery: 1, recoveryEfficiency: .15, heatCapacity: -10 }],
    ['reserve-inlet', '异材入口', '纸页和失去接收者的合法剩余可以折损回收。', { paperRecovery: 1, missRecovery: 1 }],
  ], variant: ['reserve-archive', '封存热匣', '储备跨房保存，达到阈值再释放，牺牲部分即时威力。', { heatRecovery: 1, reservePersist: 1, reserveThreshold: 15, spellPower: -.04 }] },
  { id: 'fragments', tag: '分合', modifies: ['cold', 'conduction'], entries: [
    ['fragments-chisel', '析页刀', '增加一个碎片，并将额外份额从本体转给碎片。', { fragmentCount: 1, fragmentShare: .04 }],
    ['fragments-sieve', '同文筛', '提高派生片段加工保留率。', { reactionEfficiency: .05, materialConserve: .05 }],
    ['fragments-spray', '百屑分梳', '更多较弱碎片展开，减少本体持有份额。', { fragmentCount: 3, fragmentShare: .12, forkPayload: 1 }],
    ['fragments-knot', '归并绳结', '把兼容片段归并到少数落点，延后交付。', { mergePayload: 1, concentrate: 1, carrierDelay: .4 }],
    ['fragments-casing', '碎晶封套', '允许分散片段进入晶壳并继承加工描述。', { crystalStorage: 1, copyInheritance: 1 }],
  ], variant: ['fragments-temper', '淬火分梳', '热性加工提前交出碎片，缩短防御留存。', { fragmentCount: 2, fragmentShare: .08, thermalRelease: 1, carrierLifetime: -.8 }] },
  { id: 'transport', tag: '运输', needs: ['carrier'], modifies: ['conduction', 'release'], entries: [
    ['transport-satchel', '纸灵书袋', '纸灵用原攻击周期运输已有载荷。', { summonTransport: 1 }],
    ['transport-shelves', '巡游书架', '扩大可运输容量和寿命。', { carrierCapacity: 2, carrierLifetime: .8 }],
    ['transport-courier', '急递书袋', '优先快速交付，减少留存时间。', { summonTransport: 1, carrierDelay: -.6, carrierLifetime: -.8 }],
    ['transport-convoy', '编队书袋', '聚合兼容载荷后运输，增加等待和容量。', { summonTransport: 1, mergePayload: 1, carrierCapacity: 2, carrierDelay: .6 }],
    ['transport-repeater', '接力书签', '运输载体可成为电性中继。', { carrierRelay: 1, chainReach: 55 }],
  ], variant: ['transport-return', '回航书袋', '运输后的未用合法剩余可回收，复制折算降低。', { summonTransport: 1, paperRecovery: 1, missRecovery: 1, copyEfficiency: -.04 }] },
  { id: 'letters', tag: '词形', entries: [
    ['letters-dust', '散字砂', '亲手完词积攒散字；输入目标死亡时，点亮其他词条中的相同字母。亲手输入亮字母并完词，才能取得收益。', { letterScatter: 1 }],
    ['letters-gather', '聚墨纸', '提高有限复制折算，并扩大一格容量。', { copyEfficiency: .065, carrierCapacity: 1 }],
    ['letters-page', '聚字封页', '标记的部分直接收益改作付费载荷。', { letterScatter: 1, markCarrier: 1 }],
    ['letters-scatter', '分字书签', '散字分向不同合法词条，减少集中同一目标。', { letterScatter: 1, markSpread: 1 }],
    ['letters-stencil', '形文拓片', '标记载荷可继承加工方式，增加一次分发机会。', { copyInheritance: 1, fragmentCount: 1 }],
  ], variant: ['letters-rebind', '词形重订', '分散标记并把部分收益改作承载，正常复制折算降低。', { letterScatter: 1, markCarrier: 1, markSpread: 1, copyEfficiency: -.05 }] },
  { id: 'defense', tag: '反照', needs: ['carrier'], provides: ['guard'], entries: [
    ['defense-seal', '页盾封印', '付费载体可挡住一次普通弹幕。', { carrierGuard: 1 }],
    ['defense-lining', '缓冲衬页', '增强护持效率，延长可用时间。', { guardEfficiency: .18, carrierLifetime: .8 }],
    ['defense-retain', '守文衬页', '保留载体防御，牺牲正常交付频率。', { carrierGuard: 1, carrierRetain: 1, carrierLifetime: 1.4 }],
    ['defense-reply', '回敬衬页', '防御消耗后交出未用片段，复制折算略低。', { carrierGuard: 1, carrierRelease: 1, copyEfficiency: -.04 }],
    ['defense-current', '带电护封', '护持载体可进入有限中继，扩大材料用途。', { carrierRelay: 1, chainShare: .04 }],
  ], variant: ['defense-newest', '新页反照', '优先最新护页并释放余载，减少一个可存容量。', { carrierGuard: 1, carrierRelease: 1, guardNewest: 1, carrierCapacity: -1 }] },
  { id: 'focus', tag: '定本', entries: [
    ['focus-ink', '专注墨', '以小幅威力提高支持各种主书。', { spellPower: .065 }],
    ['focus-margin', '校订页边', '减少加工损耗并提高派生折算。', { materialConserve: .09, reactionEfficiency: .025 }],
    ['focus-spike', '尖锋定本', '强化集中与穿透，削减广域传导。', { spellPower: .065, concentrate: 1, payloadPierce: 1, chainCount: -1 }],
    ['focus-cycle', '循章定本', '延长储存并提升材料供给，降低即时威力。', { materialRate: .16, carrierLifetime: 1.5, spellPower: -.04 }],
    ['focus-seal', '独卷印', '在独卷配置中强化主书结构，不开放免费副书。', { singleFrost: 1, singleFlame: 1, singleStorm: 1, singleSpirit: 1 }],
  ], variant: ['focus-sacrifice', '易形定本', '提高结构继承与加工保留，减少即时威力。', { copyInheritance: 1, materialConserve: .18, spellPower: -.05 }] },
];

export const expandedRelics: readonly Relic[] = EXPANDED_RELIC_FAMILIES.flatMap(family => {
  const [base, , branchA, branchB] = family.entries;
  const make = (entry: Entry, index: number, eventOnly = false): Relic => {
    const branch = index === 2 || index === 3 || eventOnly;
    const grants = entry[3];
    const supplied: CombatCapability[] = [];
    if (grants.crystalPayload) supplied.push('cold');
    if (grants.heatPayload) supplied.push('heat');
    if (grants.conductionPayload) supplied.push('conduction');
    if (grants.copyPages || grants.crystalStorage) supplied.push('carrier');
    if (grants.carrierGuard) supplied.push('guard');
    if (grants.carrierRelease) supplied.push('release');
    if (grants.heatRecovery || grants.paperRecovery || grants.missRecovery) supplied.push('recovery');
    return { id: entry[0], command: entry[0].replaceAll('-', ''), name: entry[1], desc: entry[2], grants: entry[3], icon: entry[0], tag: family.tag, family: family.id, budget: branch ? 16 : 8, max: 1,
      rarity: branch ? 'rare' : 'common', provides: supplied, needs: family.needs, modifies: [...new Set([...(family.modifies ?? []), ...(family.provides ?? []).filter(cap => !supplied.includes(cap))])],
      ...(branch ? { requires: [base[0]], evolution: { from: base[0], group: family.id }, excludes: [branchA[0], branchB[0], family.variant[0]].filter(id => id !== entry[0]) } : {}),
      ...(index === 4 ? { connections: [branchA[0], branchB[0]] } : {}), ...(eventOnly ? { eventOnly: true } : {}),
    };
  };
  return [...family.entries.map((entry, index) => make(entry, index)), make(family.variant, 5, true)];
});
