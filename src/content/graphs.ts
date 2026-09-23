import type { GraphDefinition, GraphNode, GraphRelation, GraphRegion } from '../contracts/graph.ts';
import { TALENT_NODES } from './talents.ts';
import { BOOKS, RELICS } from './catalog.ts';
import { combatCapabilities } from '../contracts/combat-weave.ts';

const families: readonly GraphRegion[] = [
  { id: 'copy', name: '复写与抄录', color: '#c9b4f0' },
  { id: 'binding', name: '装订与护持', color: '#d6c6ee' },
  { id: 'crystal', name: '晶体与容器', color: '#9cdef0' },
  { id: 'thermal', name: '热性与炉心', color: '#eeac80' },
  { id: 'conduction', name: '电荷与接力', color: '#eddaa0' },
  { id: 'geometry', name: '寻敌与几何', color: '#aabde5' },
  { id: 'reserve', name: '储备与回收', color: '#cbb68c' },
  { id: 'fragments', name: '碎片与聚合', color: '#accfe4' },
  { id: 'transport', name: '纸灵与运输', color: '#bca3e5' },
  { id: 'letters', name: '字母与词形', color: '#d3cba7' },
  { id: 'defense', name: '弹反与转换', color: '#a1c9b6' },
  { id: 'focus', name: '独卷与代价', color: '#d5a4a6' },
];
const familyIds = new Set(families.map(f => f.id));
const labels = { cold: '晶体与寒气', heat: '热性材料', conduction: '电性传导', carrier: '法术承载', guard: '防御出口', release: '终结释放', recovery: '剩余回收' };
const capabilityRegion = { cold: 'crystal', heat: 'thermal', conduction: 'conduction', carrier: 'copy', guard: 'defense', release: 'binding', recovery: 'reserve' };
export function relicFamily(relic: typeof RELICS[number]) {
  if (relic.family && familyIds.has(relic.family)) return relic.family;
  const stats = Object.keys(relic.grants ?? {}).join(' ').toLowerCase();
  if (/burn|fire|heat|inferno/.test(stats)) return 'thermal';
  if (/cold|frost|shatter|crystal/.test(stats)) return 'crystal';
  if (/chain|conduct|storm/.test(stats)) return 'conduction';
  if (/summon|spirit/.test(stats)) return 'transport';
  if (/copy|page|carrier/.test(stats)) return 'copy';
  if (/word|letter|perfect|combo|autofill/.test(stats)) return 'letters';
  if (/shield|ward|parry|dash|reflect|armor|health|leech|rescue/.test(stats)) return 'defense';
  if (/reach|gravity|impulse|pulse/.test(stats)) return 'geometry';
  return 'focus';
}
const relation = (source: string, target: string, kind: GraphRelation['kind'], label?: string): GraphRelation => ({ id: `${kind}:${source}:${target}`, source, target, kind, label });
const deduplicate = (edges: GraphRelation[]) => [...new Map(edges.map(edge => [edge.id, edge])).values()];

export const TALENT_GRAPH: GraphDefinition = {
  id: 'talents', version: 2,
  regions: [...Object.values(BOOKS).map(book => ({ id: book.id, name: book.name, color: book.color })), ...[
    ['binding', '合订书脊'], ['focus', '独卷精修'], ['reserve', '藏量回流'], ['geometry', '分合几何'], ['warding', '护持遗响'], ['letters', '词形复调'], ['transport', '行间运输'], ['transmutation', '材料易形'],
  ].map(([id, name]) => ({ id, name, color: '#d9c596' }))],
  nodes: TALENT_NODES.map(node => ({ id: node.id, definitionId: node.id, name: node.name, description: node.description, region: node.family ?? node.school, family: node.family ?? node.school, kind: node.root ? 'root' : node.kind ?? 'rule', cost: node.cost, tags: [...(node.capabilities ?? []), ...(node.requires ?? []), ...Object.keys(node.grants ?? {})] })),
  relations: deduplicate(TALENT_NODES.flatMap(node => [
    ...node.links.map(id => relation(...([node.id, id].sort() as [string, string]), 'path')),
    ...(node.requiresNodes ?? []).map(id => relation(id, node.id, 'requires')),
    ...TALENT_NODES.filter(other => node.exclusive && node.exclusive === other.exclusive && node.id < other.id).map(other => relation(node.id, other.id, 'excludes')),
  ])),
};

const relicNodes: GraphNode[] = RELICS.map(relic => ({ id: relic.id, definitionId: relic.id, name: relic.name, description: relic.desc, region: relicFamily(relic), family: relicFamily(relic), kind: 'relic', cost: relic.budget ?? 8, tags: [relic.tag, ...(relic.provides ?? []), ...(relic.needs ?? []), ...(relic.modifies ?? []), ...Object.keys(relic.grants ?? {})] }));
for (const capability of combatCapabilities) relicNodes.push({ id: `capability:${capability}`, definitionId: capability, name: labels[capability], description: '连接真实供给、加工与消耗此能力的零件；这不是可以免费领取的遗物。', region: capabilityRegion[capability], family: capabilityRegion[capability], kind: 'junction', condition: 'any', cost: 0, tags: [capability] });
export const RELIC_GRAPH: GraphDefinition = {
  id: 'relics', version: 2, regions: families, nodes: relicNodes,
  relations: deduplicate(RELICS.flatMap(relic => [
    ...(relic.requires ?? []).map(id => relation(id, relic.id, 'requires')),
    ...Object.keys(relic.requiresLevels ?? {}).map(id => relation(id, relic.id, 'requires')),
    ...(relic.evolution ? [relation(relic.evolution.from, relic.id, 'evolution')] : []),
    ...(relic.excludes ?? []).map(id => relation(...([relic.id, id].sort() as [string, string]), 'excludes')),
    ...(relic.provides ?? []).map(cap => relation(relic.id, `capability:${cap}`, 'connection', '提供')),
    ...(relic.needs ?? []).map(cap => relation(`capability:${cap}`, relic.id, 'requires', '需要')),
    ...(relic.modifies ?? []).map(cap => relation(`capability:${cap}`, relic.id, 'connection', '改写')),
    ...(relic.connections ?? []).map(id => relation(id, relic.id, 'connection')),
  ])),
};
