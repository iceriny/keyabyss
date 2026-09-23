import type { TalentNode } from '../contracts/talents.ts';
import type { CombatStat } from '../contracts/stats.ts';
import type { CombatCapability } from '../contracts/combat-weave.ts';
import type { BookId } from '../contracts/game.ts';

export const TALENT_BOOKS = ['frost', 'flame', 'storm', 'spirit'] as const;
type Grant = Partial<Record<CombatStat, number>>;
type Seed = { id: string; name: string; description: string; grants: Grant; capabilities?: CombatCapability[]; requires?: CombatCapability[]; requiresNodes?: string[]; exclusive?: string };
const nodes: TalentNode[] = [];
const ratioStats = new Set<CombatStat>(['spellPower', 'copyEfficiency', 'fragmentShare', 'chainShare', 'materialConserve', 'materialRate', 'reactionEfficiency', 'recoveryEfficiency', 'guardEfficiency']);
const pathNames = ['起笔', '留痕', '续页', '深刻', '承接', '回环', '远读', '析义', '复调', '定序', '藏锋', '归章'];
const statLabels: Partial<Record<CombatStat, string>> = { spellPower: '法术威力', coldStacks: '寒气强度', burnPower: '灼烧强度', burnDuration: '灼烧期限', copyEfficiency: '复写折算', carrierCapacity: '载体容量', carrierLifetime: '载体寿命', payloadPierce: '穿透次数', fragmentShare: '碎片分配', fragmentCount: '碎片数量', chainShare: '传导分配', chainCount: '传导次数', chainReach: '传导距离', materialConserve: '加工保留率', materialRate: '材料供给率', reactionEfficiency: '派生效率', heatCapacity: '热量容量', recoveryEfficiency: '回收率', reflectPower: '反射强度', guardEfficiency: '护持效率', copyCadence: '复写供给节省' };
const schools: { id: BookId; name: string; capability: CombatCapability; root: Grant; paths: Grant[]; rules: Seed[]; keys: Seed[] }[] = [
  { id: 'frost', name: '霜', capability: 'cold', root: { crystalPayload: 1 },
    paths: [{ coldStacks: .2 }, { spellPower: .025 }, { carrierLifetime: .4 }, { payloadPierce: 1 }, { coldStacks: .2 }, { fragmentShare: .02 }, { chainReach: 18 }, { materialConserve: .03 }, { carrierCapacity: 1 }, { fragmentCount: 1 }, { spellPower: .025 }, { heatCapacity: 8 }],
    rules: [
      { id: 'crystal', name: '晶构', description: '主术获得可加工的晶体结构；热性材料可使其中的威力分裂。', grants: { crystalPayload: 1 }, capabilities: ['cold'] },
      { id: 'frost-vessel', name: '冰匣', description: '允许已付片段进入晶壳保存，增加承载容量与寿命。', grants: { crystalStorage: 1, carrierCapacity: 1, carrierLifetime: 1 }, capabilities: ['carrier'] },
      { id: 'frost-division', name: '析晶', description: '碎裂多分出一份片段，增加分配给碎片的威力份额。', grants: { fragmentCount: 1, fragmentShare: .06 } },
      { id: 'frost-needle', name: '贯晶', description: '片段穿过目标继续交付；集中单体的同时降低散射份额。', grants: { payloadPierce: 1, fragmentShare: -.04 } },
      { id: 'frost-preserve', name: '封寒', description: '减少加工损耗，保存载荷更久；交付稍晚。', grants: { materialConserve: .12, carrierLifetime: 1, carrierDelay: .2 } },
      { id: 'frost-melt', name: '解冻出口', description: '晶壳接受热性释放，投入的热量可提前交出已有载荷。', grants: { thermalRelease: 1 }, requires: ['carrier'] },
    ], keys: [
      { id: 'whole-crystal', name: '完整晶页', description: '将片段集中到更少落点，强化穿透；减少广域碎片。', grants: { concentrate: 1, payloadPierce: 1, fragmentCount: -1 }, exclusive: 'frost-form' },
      { id: 'broken-mirror', name: '碎镜书写', description: '已有威力分向更多片段，覆盖扩大而单份减弱。', grants: { forkPayload: 1, fragmentCount: 2, fragmentShare: .12 }, exclusive: 'frost-form' },
      { id: 'cold-manuscript', name: '冷藏抄本', description: '晶壳保存兼容法术，并保留防御出口；正常交付更晚。', grants: { crystalStorage: 1, carrierRetain: 1, carrierCapacity: 2, carrierDelay: .6 }, capabilities: ['carrier'] },
    ] },
  { id: 'flame', name: '焰', capability: 'heat', root: { heatPayload: 1 },
    paths: [{ burnPower: .15 }, { spellPower: .025 }, { heatCapacity: 10 }, { recoveryEfficiency: .025 }, { burnDuration: .15 }, { materialRate: .04 }, { carrierLifetime: .4 }, { fragmentShare: .025 }, { heatCapacity: 10 }, { reactionEfficiency: .025 }, { spellPower: .025 }, { materialConserve: .04 }],
    rules: [
      { id: 'heat-payload', name: '热载', description: '真实人工字符持续供给可分配的热性材料。', grants: { heatPayload: 1 }, capabilities: ['heat'] },
      { id: 'recovery', name: '余热回收', description: '按来源回收未兑现的合法热量，折损保存供后续施法。', grants: { heatRecovery: 1 }, capabilities: ['recovery'], requires: ['heat'] },
      { id: 'flame-extract', name: '续写抽取', description: '完词抽取上个存活人工目标的既存灼烧；牺牲未来持续伤害，最早下词使用。', grants: { recoveryExtract: 1, heatRecovery: 1 }, capabilities: ['recovery'], requires: ['heat'] },
      { id: 'flame-furnace', name: '热匣', description: '增加可保存热量，等待更高储备再释放；即时兑现减少。', grants: { heatCapacity: 30, reserveThreshold: 12 }, capabilities: ['recovery'] },
      { id: 'flame-delivery', name: '焚页', description: '热量可提前触发载体出口，缩短防御留存。', grants: { thermalRelease: 1, carrierLifetime: -.5 }, requires: ['carrier'] },
      { id: 'flame-economy', name: '余温', description: '提高回收效率和加工保留率，降低可存容量。', grants: { recoveryEfficiency: .12, materialConserve: .08, heatCapacity: -8 } },
    ], keys: [
      { id: 'furnace-binding', name: '炉心封装', description: '热量转入晶壳与纸页，换取跨出口加工；交付更慢。', grants: { crystalStorage: 1, heatCapacity: 30, carrierDelay: .5 }, capabilities: ['carrier'] },
      { id: 'ash-manuscript', name: '灰烬归卷', description: '允许储备跨房保存，减少即时主术威力以换取延续。', grants: { reservePersist: 1, heatRecovery: 1, spellPower: -.05 }, capabilities: ['recovery'] },
      { id: 'burning-script', name: '焚页速写', description: '更快制造和交付有限纸页，但纸页寿命缩短，防御留存下降。', grants: { thermalRelease: 1, copyCadence: 2, carrierDelay: -.6, carrierLifetime: -1.5 } },
    ] },
  { id: 'storm', name: '雷', capability: 'conduction', root: { conductionPayload: 1 },
    paths: [{ chainShare: .025 }, { spellPower: .025 }, { chainReach: 25 }, { materialRate: .04 }, { reflectPower: .15 }, { chainCount: 1 }, { reactionEfficiency: .025 }, { carrierCapacity: 1 }, { chainReach: 25 }, { materialConserve: .04 }, { spellPower: .025 }, { carrierLifetime: .4 }],
    rules: [
      { id: 'conduction-payload', name: '导流', description: '人工字符供给有限电荷，在合法接收者间分配威力。', grants: { conductionPayload: 1 }, capabilities: ['conduction'] },
      { id: 'storm-relay', name: '页间中继', description: '允许载体成为电性片段的中继，延伸有效路径。', grants: { carrierRelay: 1, chainReach: 40 }, requires: ['carrier'] },
      { id: 'storm-far', name: '长弧', description: '延长传递距离，减少一次跳转，适合分散目标。', grants: { chainReach: 110, chainCount: -1 } },
      { id: 'storm-near', name: '短路分枝', description: '增加两次分配，缩短传距，每份威力更薄。', grants: { chainCount: 2, chainReach: -60 } },
      { id: 'storm-return', name: '回路', description: '未命中的合法份额折损回收；不再制造人工材料。', grants: { missRecovery: 1, heatCapacity: 12 }, capabilities: ['recovery'] },
      { id: 'storm-merge', name: '并流', description: '兼容的已付片段可聚合，减少落点并延后交付。', grants: { mergePayload: 1, carrierDelay: .3 } },
    ], keys: [
      { id: 'remote-resonance', name: '远枝共鸣', description: '以更多电荷延伸载体与敌人间的中继，减少单份输出。', grants: { carrierRelay: 1, chainReach: 150, chainShare: -.05, chainCount: 1 }, exclusive: 'storm-form' },
      { id: 'single-thunder', name: '孤雷定本', description: '减少落点并集中已付电性片段，放弃广域传递。', grants: { concentrate: 1, chainCount: -2, chainShare: .06 }, exclusive: 'storm-form' },
      { id: 'parallel-pages', name: '并行传页', description: '把有限电性载荷分给更多载体，增加容量但降低复制折算。', grants: { forkPayload: 1, carrierCapacity: 3, copyEfficiency: -.08 }, requires: ['carrier'] },
    ] },
  { id: 'spirit', name: '纸', capability: 'carrier', root: { copyPages: 1 },
    paths: [{ copyEfficiency: .015 }, { spellPower: .025 }, { carrierCapacity: 1 }, { carrierLifetime: .5 }, { guardEfficiency: .08 }, { copyCadence: .5 }, { materialConserve: .03 }, { carrierCapacity: 1 }, { copyEfficiency: .02 }, { carrierLifetime: .5 }, { spellPower: .025 }, { chainReach: 20 }],
    rules: [
      { id: 'paper-carrier', name: '承页', description: '以人工字符积累复写页，承载真正可加工的法术片段。', grants: { copyPages: 1 }, capabilities: ['carrier'] },
      { id: 'echo', name: '遗响', description: '防御或寿命终结时领取一次尚未释放的载荷。', grants: { carrierRelease: 1 }, capabilities: ['release'], requires: ['carrier'] },
      { id: 'paper-ward', name: '护页', description: '载体可选择防御出口；同一份载荷不能攻击和护持各领一次。', grants: { carrierGuard: 1 }, capabilities: ['guard'], requires: ['carrier'] },
      { id: 'paper-inherit', name: '复文', description: '复制片段继承法术的合法加工方式；提高材料成本压力。', grants: { copyInheritance: 1, copyEfficiency: -.03 } },
      { id: 'paper-salvage', name: '归纸', description: '未释放纸页的合法剩余折损回收，不恢复已消费的防御。', grants: { paperRecovery: 1, heatCapacity: 12 }, capabilities: ['recovery'] },
      { id: 'paper-transport', name: '递书', description: '纸灵可运输付费载荷；运输占用原攻击周期。', grants: { summonTransport: 1 }, requires: ['carrier'] },
    ], keys: [
      { id: 'defensive-script', name: '以守代发', description: '优先把载体留给防御，正常攻击减少；遗响可以交出余载。', grants: { carrierRetain: 1, carrierGuard: 1, carrierLifetime: 2 }, capabilities: ['guard'], exclusive: 'paper-form' },
      { id: 'swift-script', name: '速行装订', description: '更快释放和复写，减少可留存的载体容量。', grants: { copyCadence: 2, carrierDelay: -.7, carrierCapacity: -1 }, exclusive: 'paper-form' },
      { id: 'between-lines', name: '行间编队', description: '纸灵运输并聚合兼容载荷，放弃部分原有召唤攻击。', grants: { summonTransport: 1, mergePayload: 1, carrierCapacity: 2 } },
    ] },
];

for (const school of schools) {
  const pathIds = school.paths.map((_, i) => i === 0 ? ({ frost: 'cold-ink', flame: 'warm-ink', storm: 'branch', spirit: 'copy-page' }[school.id]) : i === 4 && school.id !== 'spirit' ? ({ frost: 'rime', flame: 'ember', storm: 'reflected-light', spirit: '' }[school.id]) : `${school.id}-path-${i + 1}`);
  nodes.push({ id: `${school.id}-root`, name: `${school.name}页`, description: `${school.name}系主书的免费起点；从其他区域连入可取得其基础材料来源。`, school: school.id, root: school.id, family: school.id, cost: 2, links: [pathIds[0], pathIds[3]], grants: school.root, capabilities: [school.capability] });
  school.paths.forEach((grants, i) => nodes.push({ id: pathIds[i], name: `${school.name}·${pathNames[i]}`, description: describeGrants(grants), school: school.id, family: school.id, kind: 'path', cost: 1, budget: 3, grants, links: i < 11 ? [pathIds[i + 1]] : [] }));
  school.rules.forEach((rule, i) => nodes.push({ ...rule, school: school.id, family: school.id, kind: 'rule', cost: 2, budget: 6, links: [pathIds[i * 2 + 1], ...(i < 5 ? [school.rules[i + 1].id] : [])] }));
  school.keys.forEach((key, i) => nodes.push({ ...key, school: school.id, family: school.id, kind: 'keystone', cost: 3, budget: 9, links: [school.rules[i * 2].id, school.rules[i * 2 + 1].id] }));
}

const bridges: { id: string; name: string; schools: [BookId, BookId]; paths: Grant[]; rules: Seed[]; key: Seed }[] = [
  { id: 'binding', name: '合订', schools: ['frost', 'flame'], paths: [{ materialRate: .05 }, { copyEfficiency: .02 }, { heatCapacity: 10 }, { materialConserve: .04 }], rules: [
    { id: 'binding', name: '合订', description: '开放一本副书的有限材料来源，不启动第二套完整主书循环。', grants: { secondaryBinding: 1 }, exclusive: 'binding' },
    { id: 'binding-supply', name: '副页供给', description: '提高材料供给率，减少副材料等待。', grants: { materialRate: .12 } },
  ], key: { id: 'binding-economy', name: '异材同工', description: '提高跨材料加工效率，减少即时主术威力。', grants: { materialConserve: .2, reactionEfficiency: .06, spellPower: -.05 } } },
  { id: 'focus', name: '独卷', schools: ['storm', 'spirit'], paths: [{ spellPower: .025 }, { payloadPierce: 1 }, { heatCapacity: 10 }, { materialConserve: .04 }], rules: [
    { id: 'focus', name: '独卷', description: '关闭副书槽，按当前主书选择集中、持续或编队结构。', grants: { singleFocus: 1 }, exclusive: 'binding' },
    { id: 'focus-structure', name: '定本', description: '强化主书结构：冰穿透、火储备、雷集中、纸编队。', grants: { singleFrost: 1, singleFlame: 1, singleStorm: 1, singleSpirit: 1 } },
  ], key: { id: 'single-refinement', name: '独卷精修', description: '沿独卷路线提高材料保留与结构继承，减少一次传导。', grants: { copyInheritance: 1, materialConserve: .18, chainCount: -1 }, requiresNodes: ['focus'] } },
  { id: 'reserve', name: '藏量', schools: ['flame', 'storm'], paths: [{ heatCapacity: 12 }, { recoveryEfficiency: .025 }, { heatCapacity: 12 }, { materialConserve: .04 }], rules: [
    { id: 'reserve-wide', name: '大匣', description: '扩大储备，降低回收率。', grants: { heatCapacity: 45, recoveryEfficiency: -.06 }, exclusive: 'reserve-shape' },
    { id: 'reserve-fine', name: '细匣', description: '提高回收率，缩小储备。', grants: { recoveryEfficiency: .15, heatCapacity: -10 }, exclusive: 'reserve-shape' },
  ], key: { id: 'reserve-archive', name: '余量归档', description: '储备跨房延续，达到阈值才交付；即时主术略弱。', grants: { reservePersist: 1, reserveThreshold: 15, spellPower: -.04 } } },
  { id: 'geometry', name: '分合', schools: ['frost', 'storm'], paths: [{ chainReach: 25 }, { fragmentShare: .025 }, { carrierCapacity: 1 }, { reactionEfficiency: .025 }], rules: [
    { id: 'geometry-split', name: '分发', description: '把付费威力分给更多对象，单份减弱。', grants: { forkPayload: 1 }, exclusive: 'geometry' },
    { id: 'geometry-merge', name: '收束', description: '将兼容份额聚到更少落点，覆盖减少。', grants: { concentrate: 1, mergePayload: 1 }, exclusive: 'geometry' },
  ], key: { id: 'geometry-network', name: '旁路传递', description: '载体中继接入更多接收者，延伸传距但增加交付延迟。', grants: { carrierRelay: 1, chainReach: 90, carrierDelay: .4 } } },
  { id: 'warding', name: '护持', schools: ['frost', 'spirit'], paths: [{ carrierLifetime: .6 }, { guardEfficiency: .08 }, { carrierCapacity: 1 }, { copyEfficiency: .02 }], rules: [
    { id: 'warding-new', name: '新页护封', description: '防御优先消耗最新载体，把旧载体留给输出。', grants: { guardNewest: 1, carrierGuard: 1 }, capabilities: ['guard'] },
    { id: 'warding-echo', name: '终页交付', description: '载体终结时交出一次剩余载荷，折算略低。', grants: { carrierRelease: 1, copyEfficiency: -.03 }, capabilities: ['release'] },
  ], key: { id: 'warding-return', name: '护文反照', description: '留存更多护页并允许遗响，自动攻击周期变长。', grants: { carrierRetain: 1, carrierRelease: 1, carrierCapacity: 2, carrierDelay: .5 } } },
  { id: 'letters', name: '词形', schools: ['flame', 'spirit'], paths: [{ copyEfficiency: .02 }, { carrierCapacity: 1 }, { materialRate: .05 }, { carrierLifetime: .5 }], rules: [
    { id: 'letters-carry', name: '聚字成页', description: '一部分标记增伤转为有限复制载荷，而非同时全领。', grants: { markCarrier: 1 }, exclusive: 'letter-form' },
    { id: 'letters-scatter', name: '分字联章', description: '散字优先分向不同合法词条，覆盖更广而集中更少。', grants: { markSpread: 1, letterScatter: 1 }, exclusive: 'letter-form' },
  ], key: { id: 'letters-resonance', name: '词令复调', description: '让已人工兑现的标记接入复写继承，提高容量但延迟交付。', grants: { markCarrier: 1, copyInheritance: 1, carrierCapacity: 2, carrierDelay: .3 } } },
  { id: 'transport', name: '运输', schools: ['spirit', 'storm'], paths: [{ carrierLifetime: .5 }, { chainReach: 25 }, { copyEfficiency: .02 }, { carrierCapacity: 1 }], rules: [
    { id: 'transport-relay', name: '接力页', description: '载体可作为有限电性中继，扩大交付范围。', grants: { carrierRelay: 1, chainReach: 40 } },
    { id: 'transport-spirit', name: '行间递送', description: '纸灵以攻击周期运输已有片段，不生产额外弹药。', grants: { summonTransport: 1 } },
  ], key: { id: 'transport-fleet', name: '流动书架', description: '扩大运输容量并聚合兼容载荷，牺牲正常交付速度。', grants: { summonTransport: 1, mergePayload: 1, carrierCapacity: 3, carrierDelay: .6 } } },
  { id: 'transmutation', name: '易形', schools: ['flame', 'frost'], paths: [{ materialConserve: .04 }, { reactionEfficiency: .025 }, { heatCapacity: 12 }, { fragmentShare: .025 }], rules: [
    { id: 'transmutation-heat', name: '受热易形', description: '热量改变晶壳和纸页的出口，提前消耗留存。', grants: { thermalRelease: 1 } },
    { id: 'transmutation-return', name: '废页再用', description: '纸页和未命中片段的合法剩余可折损回收。', grants: { paperRecovery: 1, missRecovery: 1 }, capabilities: ['recovery'] },
  ], key: { id: 'transmutation-furnace', name: '万页炉', description: '多类载体接受热加工并保留原加工描述，降低即时复制威力。', grants: { thermalRelease: 1, crystalStorage: 1, copyInheritance: 1, copyEfficiency: -.08 } } },
];

for (const bridge of bridges) {
  const ids = bridge.paths.map((_, i) => `${bridge.id}-bridge-${i + 1}`);
  bridge.paths.forEach((grants, i) => nodes.push({ id: ids[i], name: `${bridge.name}·${['入径', '承势', '转义', '通章'][i]}`, description: describeGrants(grants), school: 'shared', family: bridge.id, kind: 'path', cost: 1, budget: 3, grants, links: [...(i < 3 ? [ids[i + 1]] : []), ...(i === 0 ? [`${bridge.schools[0]}-path-7`] : []), ...(i === 3 ? [`${bridge.schools[1]}-path-10`] : [])] }));
  bridge.rules.forEach((rule, i) => nodes.push({ ...rule, school: 'shared', family: bridge.id, kind: 'rule', cost: 2, budget: 6, links: [ids[i ? 2 : 1]] }));
  nodes.push({ ...bridge.key, school: 'shared', family: bridge.id, kind: 'keystone', cost: 3, budget: 9, links: bridge.rules.map(rule => rule.id) });
}

function describeGrants(grants: Grant) {
  return Object.entries(grants).map(([key, value]) => `${statLabels[key as CombatStat] ?? key} ${value! >= 0 ? '+' : ''}${Number((value! * (ratioStats.has(key as CombatStat) ? 100 : 1)).toFixed(3))}${ratioStats.has(key as CombatStat) ? '%' : ''}`).join('；') + '。';
}

export const TALENT_NODES: readonly TalentNode[] = nodes;
export const TALENT_BY_ID: Readonly<Record<string, TalentNode>> = Object.fromEntries(nodes.map(node => [node.id, node]));
