import type { TalentNode } from '../contracts/talents.ts';
import type { CombatStat } from '../contracts/stats.ts';
import type { CombatCapability } from '../contracts/combat-weave.ts';
import type { BookId } from '../contracts/game.ts';

export const TALENT_BOOKS = ['frost', 'flame', 'storm', 'spirit'] as const;
type Grant = Partial<Record<CombatStat, number>>;
type Seed = { id: string; name: string; description: string; grants: Grant; capabilities?: CombatCapability[]; requires?: CombatCapability[]; requiresNodes?: string[]; exclusive?: string };
const nodes: TalentNode[] = [];
const ratioStats = new Set<CombatStat>(['spellPower', 'copyEfficiency', 'fragmentShare', 'chainShare', 'materialConserve', 'materialRate', 'reactionEfficiency', 'recoveryEfficiency', 'guardEfficiency']);
const statLabels: Partial<Record<CombatStat, string>> = { spellPower: '法术伤害', coldStacks: '寒气强度', burnPower: '灼烧伤害', burnDuration: '灼烧时间', copyEfficiency: '复写法术威力', carrierCapacity: '法术保存数量', carrierLifetime: '法术保存时间', payloadPierce: '穿透次数', fragmentShare: '分给碎片的威力', fragmentCount: '碎片数量', chainShare: '分给连锁的威力', chainCount: '连锁次数', chainReach: '连锁距离', materialConserve: '法术加工保留的威力', materialRate: '施法资源积累速度', reactionEfficiency: '法术联动威力', heatCapacity: '储备上限', recoveryEfficiency: '剩余法力回收比例', reflectPower: '弹反伤害', guardEfficiency: '法术防御效果', copyCadence: '复写所需字符减少' };
export const TALENT_GRAPH_VERSION = 3;
const pathLabels: Partial<Record<CombatStat, string>> = { materialConserve: '减少损耗', materialRate: '资源积累', carrierCapacity: '法术存量', carrierLifetime: '保存时间', fragmentShare: '碎片威力', chainShare: '连锁威力', copyEfficiency: '复写威力', recoveryEfficiency: '法力回收', reactionEfficiency: '联动威力', copyCadence: '复写速度', guardEfficiency: '法术防御' };
const pathName = (grants: Grant) => { const key = Object.keys(grants)[0] as CombatStat; return pathLabels[key] ?? statLabels[key]; };
function namedPaths(prefix: string, paths: Grant[]): string[] {
  return paths.map((grants, index) => {
    const label = pathName(grants), repeated = paths.filter(other => pathName(other) === label).length > 1;
    const rank = paths.slice(0, index + 1).filter(other => pathName(other) === label).length;
    return `${prefix}·${label}${repeated ? ['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ'][rank - 1] : ''}`;
  });
}

// Three coherent branches per book. These are gameplay paths, never coordinates.
const branches: Record<BookId, number[][]> = {
  frost: [[0, 4, 1, 10], [3, 5, 9, 7], [2, 8, 6, 11]],
  flame: [[0, 4, 1, 10], [3, 7, 9, 11], [2, 8, 5, 6]],
  storm: [[0, 5, 2, 8], [4, 1, 10, 6], [3, 7, 9, 11]],
  spirit: [[0, 5, 8, 1], [4, 3, 9, 10], [2, 7, 6, 11]],
};
const branchRules: Record<BookId, string[][]> = {
  frost: [['crystal', 'frost-needle'], ['frost-division', 'frost-preserve'], ['frost-vessel', 'frost-melt']],
  flame: [['heat-payload', 'flame-delivery'], ['recovery', 'flame-extract'], ['flame-furnace', 'flame-economy']],
  storm: [['conduction-payload', 'storm-far'], ['storm-near', 'storm-return'], ['storm-relay', 'storm-merge']],
  spirit: [['paper-carrier', 'paper-inherit'], ['paper-ward', 'echo'], ['paper-salvage', 'paper-transport']],
};
const keyPorts: Record<string, string> = {
  'whole-crystal': 'frost-needle', 'broken-mirror': 'frost-division', 'cold-manuscript': 'frost-vessel',
  'furnace-binding': 'flame-furnace', 'ash-manuscript': 'flame-extract', 'burning-script': 'flame-delivery',
  'remote-resonance': 'storm-far', 'single-thunder': 'storm-near', 'parallel-pages': 'storm-merge',
  'defensive-script': 'paper-ward', 'swift-script': 'paper-inherit', 'between-lines': 'paper-transport',
};
// Shared routes join the mechanics they modify, rather than arbitrary path indices.
export const TALENT_BRIDGE_PORTS: Readonly<Record<string, readonly [string, string]>> = {
  binding: ['crystal', 'heat-payload'], focus: ['storm-near', 'paper-inherit'],
  reserve: ['recovery', 'storm-return'], geometry: ['frost-division', 'conduction-payload'],
  warding: ['frost-vessel', 'paper-ward'], letters: ['flame-delivery', 'paper-carrier'],
  transport: ['paper-transport', 'storm-relay'], transmutation: ['flame-furnace', 'frost-melt'],
};
const schools: { id: BookId; name: string; capability: CombatCapability; root: Grant; paths: Grant[]; rules: Seed[]; keys: Seed[] }[] = [
  { id: 'frost', name: '霜', capability: 'cold', root: { crystalPayload: 1 },
    paths: [{ coldStacks: .2 }, { spellPower: .025 }, { carrierLifetime: .4 }, { payloadPierce: 1 }, { coldStacks: .2 }, { fragmentShare: .02 }, { chainReach: 18 }, { materialConserve: .03 }, { carrierCapacity: 1 }, { fragmentCount: 1 }, { spellPower: .025 }, { heatCapacity: 8 }],
    rules: [
      { id: 'crystal', name: '晶构', description: '冰晶法术可以碎裂；与热量配合时，将部分威力分给碎片。', grants: { crystalPayload: 1 }, capabilities: ['cold'] },
      { id: 'frost-vessel', name: '冰匣', description: '用冰晶保存法术：可多保存 1 份，保存时间延长 1 秒。', grants: { crystalStorage: 1, carrierCapacity: 1, carrierLifetime: 1 }, capabilities: ['carrier'] },
      { id: 'frost-division', name: '析晶', description: '碎裂时多产生 1 枚碎片，并把更多法术威力分给碎片。', grants: { fragmentCount: 1, fragmentShare: .06 } },
      { id: 'frost-needle', name: '贯晶', description: '法术可多穿透 1 个敌人；分给碎片的威力减少。', grants: { payloadPierce: 1, fragmentShare: -.04 } },
      { id: 'frost-preserve', name: '封寒', description: '保存法术时损失的威力更少，保存时间延长 1 秒；释放晚 0.2 秒。', grants: { materialConserve: .12, carrierLifetime: 1, carrierDelay: .2 } },
      { id: 'frost-melt', name: '解冻出口', description: '冰晶中存有热量时，可以提前释放保存的法术。需要先学会保存法术。', grants: { thermalRelease: 1 }, requires: ['carrier'] },
    ], keys: [
      { id: 'whole-crystal', name: '完整晶页', description: '集中攻击更少的敌人，多穿透 1 个敌人；碎片数量减少。', grants: { concentrate: 1, payloadPierce: 1, fragmentCount: -1 }, exclusive: 'frost-form' },
      { id: 'broken-mirror', name: '碎镜书写', description: '产生更多碎片，并把更多威力分给碎片；攻击范围更广，单枚威力更低。', grants: { forkPayload: 1, fragmentCount: 2, fragmentShare: .12 }, exclusive: 'frost-form' },
      { id: 'cold-manuscript', name: '冷藏抄本', description: '冰晶可多保存 2 份法术，并优先留作防御；通常释放晚 0.6 秒。', grants: { crystalStorage: 1, carrierRetain: 1, carrierCapacity: 2, carrierDelay: .6 }, capabilities: ['carrier'] },
    ] },
  { id: 'flame', name: '焰', capability: 'heat', root: { heatPayload: 1 },
    paths: [{ burnPower: .15 }, { spellPower: .025 }, { heatCapacity: 10 }, { recoveryEfficiency: .025 }, { burnDuration: .15 }, { materialRate: .04 }, { carrierLifetime: .4 }, { fragmentShare: .025 }, { heatCapacity: 10 }, { reactionEfficiency: .025 }, { spellPower: .025 }, { materialConserve: .04 }],
    rules: [
      { id: 'heat-payload', name: '蓄热', description: '手动输入字符时积累热量，用于灼烧与法术联动。', grants: { heatPayload: 1 }, capabilities: ['heat'] },
      { id: 'recovery', name: '余热回收', description: '回收尚未造成伤害的剩余热量；回收时会损失一部分，其余留给后续施法。', grants: { heatRecovery: 1 }, capabilities: ['recovery'], requires: ['heat'] },
      { id: 'flame-extract', name: '续写抽取', description: '完成咒文时，抽取上一个仍存活目标身上的灼烧，转为热量储备。原本后续的灼烧伤害会减少，回收的热量最早用于下一次施法。', grants: { recoveryExtract: 1, heatRecovery: 1 }, capabilities: ['recovery'], requires: ['heat'] },
      { id: 'flame-furnace', name: '热匣', description: '热量储备上限增加 30；释放所需储备提高 12，需要积攒更久。', grants: { heatCapacity: 30, reserveThreshold: 12 }, capabilities: ['recovery'] },
      { id: 'flame-delivery', name: '焚页', description: '保存的法术含有热量时，可以提前释放；保存时间缩短 0.5 秒。', grants: { thermalRelease: 1, carrierLifetime: -.5 }, requires: ['carrier'] },
      { id: 'flame-economy', name: '余温', description: '提高剩余热量的回收比例，减少法术加工损失；储备上限减少 8。', grants: { recoveryEfficiency: .12, materialConserve: .08, heatCapacity: -8 } },
    ], keys: [
      { id: 'furnace-binding', name: '炉心封装', description: '热量可以存入冰晶；储备上限增加 30，法术释放晚 0.5 秒。', grants: { crystalStorage: 1, heatCapacity: 30, carrierDelay: .5 }, capabilities: ['carrier'] },
      { id: 'ash-manuscript', name: '灰烬归卷', description: '剩余热量可以带入下一个房间；法术伤害降低 5%。', grants: { reservePersist: 1, heatRecovery: 1, spellPower: -.05 }, capabilities: ['recovery'] },
      { id: 'burning-script', name: '焚页速写', description: '复写所需字符减少 2，保存的法术提前 0.6 秒释放；保存时间缩短 1.5 秒。', grants: { thermalRelease: 1, copyCadence: 2, carrierDelay: -.6, carrierLifetime: -1.5 } },
    ] },
  { id: 'storm', name: '雷', capability: 'conduction', root: { conductionPayload: 1 },
    paths: [{ chainShare: .025 }, { spellPower: .025 }, { chainReach: 25 }, { materialRate: .04 }, { reflectPower: .15 }, { chainCount: 1 }, { reactionEfficiency: .025 }, { carrierCapacity: 1 }, { chainReach: 25 }, { materialConserve: .04 }, { spellPower: .025 }, { carrierLifetime: .4 }],
    rules: [
      { id: 'conduction-payload', name: '导流', description: '手动输入字符时积累电荷，让法术在多个敌人之间连锁。', grants: { conductionPayload: 1 }, capabilities: ['conduction'] },
      { id: 'storm-relay', name: '页间中继', description: '连锁攻击可以经过保存法术的纸页或冰晶继续跳向敌人；连锁距离增加 40。', grants: { carrierRelay: 1, chainReach: 40 }, requires: ['carrier'] },
      { id: 'storm-far', name: '长弧', description: '连锁距离增加 110，连锁次数减少 1；更适合相距较远的敌人。', grants: { chainReach: 110, chainCount: -1 } },
      { id: 'storm-near', name: '短路分枝', description: '连锁次数增加 2，距离减少 60；总威力分给更多近处敌人。', grants: { chainCount: 2, chainReach: -60 } },
      { id: 'storm-return', name: '回路', description: '回收未命中法术的部分剩余威力；储备上限增加 12。', grants: { missRecovery: 1, heatCapacity: 12 }, capabilities: ['recovery'] },
      { id: 'storm-merge', name: '并流', description: '将可以合并的法术集中攻击更少的敌人；释放晚 0.3 秒。', grants: { mergePayload: 1, carrierDelay: .3 } },
    ], keys: [
      { id: 'remote-resonance', name: '远枝共鸣', description: '连锁可以经过纸页或冰晶接力，距离增加 150、次数增加 1；分给连锁的威力减少。', grants: { carrierRelay: 1, chainReach: 150, chainShare: -.05, chainCount: 1 }, exclusive: 'storm-form' },
      { id: 'single-thunder', name: '孤雷定本', description: '将雷电集中攻击更少的敌人；连锁次数减少，分给连锁的威力增加。', grants: { concentrate: 1, chainCount: -2, chainShare: .06 }, exclusive: 'storm-form' },
      { id: 'parallel-pages', name: '并行传页', description: '将法术分存到更多纸页或冰晶，可多保存 3 份；复写法术威力降低 8%。', grants: { forkPayload: 1, carrierCapacity: 3, copyEfficiency: -.08 }, requires: ['carrier'] },
    ] },
  { id: 'spirit', name: '纸', capability: 'carrier', root: { copyPages: 1 },
    paths: [{ copyEfficiency: .015 }, { spellPower: .025 }, { carrierCapacity: 1 }, { carrierLifetime: .5 }, { guardEfficiency: .08 }, { copyCadence: .5 }, { materialConserve: .03 }, { carrierCapacity: 1 }, { copyEfficiency: .02 }, { carrierLifetime: .5 }, { spellPower: .025 }, { chainReach: 20 }],
    rules: [
      { id: 'paper-carrier', name: '承页', description: '手动输入字符时积累纸页，用来保存法术并再次释放。', grants: { copyPages: 1 }, capabilities: ['carrier'] },
      { id: 'echo', name: '遗响', description: '纸页或冰晶用于防御、或保存时间结束时，释放其中尚未用掉的法术。', grants: { carrierRelease: 1 }, capabilities: ['release'], requires: ['carrier'] },
      { id: 'paper-ward', name: '护页', description: '保存的法术可以用于防御。用于防御的那部分威力会被消耗。', grants: { carrierGuard: 1 }, capabilities: ['guard'], requires: ['carrier'] },
      { id: 'paper-inherit', name: '复文', description: '复写的法术保留原有的联动效果；复写威力降低 3%。', grants: { copyInheritance: 1, copyEfficiency: -.03 } },
      { id: 'paper-salvage', name: '归纸', description: '纸页消失时，回收未释放法术的部分剩余威力；储备上限增加 12。', grants: { paperRecovery: 1, heatCapacity: 12 }, capabilities: ['recovery'] },
      { id: 'paper-transport', name: '递书', description: '纸灵可以运送保存的法术；运送会占用它原本的一次攻击。', grants: { summonTransport: 1 }, requires: ['carrier'] },
    ], keys: [
      { id: 'defensive-script', name: '以守代发', description: '优先保留法术用于防御，保存时间延长 2 秒，因此自动攻击变少。搭配「遗响」可释放防御后剩余的法术。', grants: { carrierRetain: 1, carrierGuard: 1, carrierLifetime: 2 }, capabilities: ['guard'], exclusive: 'paper-form' },
      { id: 'swift-script', name: '速行装订', description: '复写所需字符减少 2，法术提前 0.7 秒释放；可保存的法术减少 1 份。', grants: { copyCadence: 2, carrierDelay: -.7, carrierCapacity: -1 }, exclusive: 'paper-form' },
      { id: 'between-lines', name: '行间编队', description: '纸灵可以运送并合并法术，可多保存 2 份；运送会占用它原本的攻击。', grants: { summonTransport: 1, mergePayload: 1, carrierCapacity: 2 } },
    ] },
];

for (const school of schools) {
  const names = namedPaths(school.name, school.paths);
  const pathIds = school.paths.map((_, i) => i === 0 ? ({ frost: 'cold-ink', flame: 'warm-ink', storm: 'branch', spirit: 'copy-page' }[school.id]) : i === 4 && school.id !== 'spirit' ? ({ frost: 'rime', flame: 'ember', storm: 'reflected-light', spirit: '' }[school.id]) : `${school.id}-path-${i + 1}`);
  const routes = branches[school.id];
  nodes.push({ id: `${school.id}-root`, name: `${school.name}页`, description: ({ frost: '施法积累寒气，让冰晶法术参与碎裂和穿透。', flame: '施法积累热量，用于灼烧、储存和释放法术。', storm: '施法积累电荷，让法术在敌人之间连锁。', spirit: '输入字符积累复写纸页，用于保存和再次释放法术。' })[school.id], school: school.id, root: school.id, family: school.id, cost: 2, links: routes.map(route => pathIds[route[0]]), grants: school.root, capabilities: [school.capability] });
  school.paths.forEach((grants, i) => {
    const route = routes.find(route => route.includes(i))!;
    const next = route[route.indexOf(i) + 1];
    nodes.push({ id: pathIds[i], name: names[i], description: describeGrants(grants), school: school.id, family: school.id, kind: 'path', cost: 1, budget: 3, grants, links: next === undefined ? [] : [pathIds[next]] });
  });
  school.rules.forEach(rule => {
    const branch = branchRules[school.id].findIndex(pair => pair.includes(rule.id));
    const step = branchRules[school.id][branch].indexOf(rule.id) ? 3 : 1;
    nodes.push({ ...rule, school: school.id, family: school.id, kind: 'rule', cost: 2, budget: 6, links: [pathIds[routes[branch][step]]] });
  });
  school.keys.forEach(key => nodes.push({ ...key, school: school.id, family: school.id, kind: 'keystone', cost: 3, budget: 9, links: [keyPorts[key.id]] }));
}

const bridges: { id: string; name: string; schools: [BookId, BookId]; paths: Grant[]; rules: Seed[]; key: Seed }[] = [
  { id: 'binding', name: '合订', schools: ['frost', 'flame'], paths: [{ materialRate: .05 }, { copyEfficiency: .02 }, { heatCapacity: 10 }, { materialConserve: .04 }], rules: [
    { id: 'binding', name: '合订', description: '可以选择一本副书，获得该书的施法资源，用于与主书配合。', grants: { secondaryBinding: 1 }, exclusive: 'binding' },
    { id: 'binding-supply', name: '副页供给', description: '施法资源积累速度提高 12%。', grants: { materialRate: .12 } },
  ], key: { id: 'binding-economy', name: '异材同工', description: '减少法术加工损失，提高联动威力；法术伤害降低 5%。', grants: { materialConserve: .2, reactionEfficiency: .06, spellPower: -.05 } } },
  { id: 'focus', name: '独卷', schools: ['storm', 'spirit'], paths: [{ spellPower: .025 }, { payloadPierce: 1 }, { heatCapacity: 10 }, { materialConserve: .04 }], rules: [
    { id: 'focus', name: '独卷', description: '专精当前主书，无法选择副书。', grants: { singleFocus: 1 }, exclusive: 'binding' },
    { id: 'focus-structure', name: '定本', description: '强化当前主书：冰晶增加穿透，火焰增加储备，雷电集中攻击，纸灵加强运送。', grants: { singleFrost: 1, singleFlame: 1, singleStorm: 1, singleSpirit: 1 } },
  ], key: { id: 'single-refinement', name: '独卷精修', description: '复写保留原有联动，减少法术加工损失；连锁次数减少 1。需要先点亮「独卷」。', grants: { copyInheritance: 1, materialConserve: .18, chainCount: -1 }, requiresNodes: ['focus'] } },
  { id: 'reserve', name: '藏量', schools: ['flame', 'storm'], paths: [{ heatCapacity: 12 }, { recoveryEfficiency: .025 }, { heatCapacity: 12 }, { materialConserve: .04 }], rules: [
    { id: 'reserve-wide', name: '大匣', description: '储备上限增加 45；剩余法力的回收比例降低 6%。', grants: { heatCapacity: 45, recoveryEfficiency: -.06 }, exclusive: 'reserve-shape' },
    { id: 'reserve-fine', name: '细匣', description: '剩余法力的回收比例提高 15%；储备上限减少 10。', grants: { recoveryEfficiency: .15, heatCapacity: -10 }, exclusive: 'reserve-shape' },
  ], key: { id: 'reserve-archive', name: '余量归档', description: '储备可以带入下一个房间；释放所需储备提高 15，法术伤害降低 4%。', grants: { reservePersist: 1, reserveThreshold: 15, spellPower: -.04 } } },
  { id: 'geometry', name: '分合', schools: ['frost', 'storm'], paths: [{ chainReach: 25 }, { fragmentShare: .025 }, { carrierCapacity: 1 }, { reactionEfficiency: .025 }], rules: [
    { id: 'geometry-split', name: '分发', description: '将法术分给更多敌人；总威力不变，每份威力更低。', grants: { forkPayload: 1 }, exclusive: 'geometry' },
    { id: 'geometry-merge', name: '收束', description: '合并法术，集中攻击更少的敌人。', grants: { concentrate: 1, mergePayload: 1 }, exclusive: 'geometry' },
  ], key: { id: 'geometry-network', name: '旁路传递', description: '连锁攻击可以经过纸页或冰晶接力，距离增加 90；保存的法术释放晚 0.4 秒。', grants: { carrierRelay: 1, chainReach: 90, carrierDelay: .4 } } },
  { id: 'warding', name: '护持', schools: ['frost', 'spirit'], paths: [{ carrierLifetime: .6 }, { guardEfficiency: .08 }, { carrierCapacity: 1 }, { copyEfficiency: .02 }], rules: [
    { id: 'warding-new', name: '新页护封', description: '防御时优先消耗最新保存的法术，把更早保存的法术留给攻击。', grants: { guardNewest: 1, carrierGuard: 1 }, capabilities: ['guard'] },
    { id: 'warding-echo', name: '终页余响', description: '纸页或冰晶用于防御、或保存时间结束时，释放尚未用掉的法术；复写威力降低 3%。', grants: { carrierRelease: 1, copyEfficiency: -.03 }, capabilities: ['release'] },
  ], key: { id: 'warding-return', name: '护文反照', description: '优先保存法术用于防御，并在防御或保存结束时释放剩余法术；可多保存 2 份，释放晚 0.5 秒。', grants: { carrierRetain: 1, carrierRelease: 1, carrierCapacity: 2, carrierDelay: .5 } } },
  { id: 'letters', name: '词形', schools: ['flame', 'spirit'], paths: [{ copyEfficiency: .02 }, { carrierCapacity: 1 }, { materialRate: .05 }, { carrierLifetime: .5 }], rules: [
    { id: 'letters-carry', name: '聚字成页', description: '将一部分字母标记增伤转为纸页保存的法术；这部分威力不再直接造成标记伤害。', grants: { markCarrier: 1 }, exclusive: 'letter-form' },
    { id: 'letters-scatter', name: '分字联章', description: '散出的字母优先寻找不同敌人，扩大攻击范围。', grants: { markSpread: 1, letterScatter: 1 }, exclusive: 'letter-form' },
  ], key: { id: 'letters-resonance', name: '词令复调', description: '手动施法触发的字母标记可转为纸页法术，并保留原有联动；可多保存 2 份，释放晚 0.3 秒。', grants: { markCarrier: 1, copyInheritance: 1, carrierCapacity: 2, carrierDelay: .3 } } },
  { id: 'transport', name: '运输', schools: ['spirit', 'storm'], paths: [{ carrierLifetime: .5 }, { chainReach: 25 }, { copyEfficiency: .02 }, { carrierCapacity: 1 }], rules: [
    { id: 'transport-relay', name: '接力页', description: '连锁攻击可以经过纸页或冰晶接力，距离增加 40。', grants: { carrierRelay: 1, chainReach: 40 } },
    { id: 'transport-spirit', name: '行间递送', description: '纸灵可以运送保存的法术；每次运送占用一次普通攻击。', grants: { summonTransport: 1 } },
  ], key: { id: 'transport-fleet', name: '流动书架', description: '纸灵可以运送并合并法术，可多保存 3 份；保存的法术释放晚 0.6 秒。', grants: { summonTransport: 1, mergePayload: 1, carrierCapacity: 3, carrierDelay: .6 } } },
  { id: 'transmutation', name: '易形', schools: ['flame', 'frost'], paths: [{ materialConserve: .04 }, { reactionEfficiency: .025 }, { heatCapacity: 12 }, { fragmentShare: .025 }], rules: [
    { id: 'transmutation-heat', name: '受热易形', description: '含有热量的纸页或冰晶会提前释放法术，因此留给防御的时间更短。', grants: { thermalRelease: 1 } },
    { id: 'transmutation-return', name: '废页再用', description: '回收消失纸页和未命中法术的部分剩余威力。', grants: { paperRecovery: 1, missRecovery: 1 }, capabilities: ['recovery'] },
  ], key: { id: 'transmutation-furnace', name: '万页炉', description: '冰晶可以保存法术，热量使纸页和冰晶提前释放，复写保留原有联动；复写威力降低 8%。', grants: { thermalRelease: 1, crystalStorage: 1, copyInheritance: 1, copyEfficiency: -.08 } } },
];

for (const bridge of bridges) {
  const ids = bridge.paths.map((_, i) => `${bridge.id}-bridge-${i + 1}`);
  const names = namedPaths(bridge.name, bridge.paths);
  const ports = TALENT_BRIDGE_PORTS[bridge.id];
  bridge.paths.forEach((grants, i) => nodes.push({ id: ids[i], name: names[i], description: describeGrants(grants), school: 'shared', family: bridge.id, kind: 'path', cost: 1, budget: 3, grants, links: [...(i < 3 ? [ids[i + 1]] : []), ...(i === 0 ? [ports[0]] : []), ...(i === 3 ? [ports[1]] : [])] }));
  bridge.rules.forEach((rule, i) => nodes.push({ ...rule, school: 'shared', family: bridge.id, kind: 'rule', cost: 2, budget: 6, links: [ids[i ? 2 : 1]] }));
  nodes.push({ ...bridge.key, school: 'shared', family: bridge.id, kind: 'keystone', cost: 3, budget: 9, links: bridge.rules.map(rule => rule.id) });
}

function describeGrants(grants: Grant) {
  return Object.entries(grants).map(([key, value]) => `${statLabels[key as CombatStat] ?? key} ${value! >= 0 ? '+' : ''}${Number((value! * (ratioStats.has(key as CombatStat) ? 100 : 1)).toFixed(3))}${ratioStats.has(key as CombatStat) ? '%' : ['carrierLifetime', 'burnDuration'].includes(key) ? ' 秒' : key === 'copyCadence' ? ' 字' : ''}`).join('；') + '。';
}

export const TALENT_NODES: readonly TalentNode[] = nodes;
export const TALENT_BY_ID: Readonly<Record<string, TalentNode>> = Object.fromEntries(nodes.map(node => [node.id, node]));
