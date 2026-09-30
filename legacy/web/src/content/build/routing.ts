import { RESOURCE_SCALE as Q } from '../../contracts/build-resources.ts';
import type { BuildContribution, Condition, NumericDefinition, NumericModifier, RelicDefinition, RuleDefinition,
  RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';
import { RESERVE_USE_RULE_IDS } from './reserve.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { routing: 1, shaping: .4 }, objectKinds: ['spell', 'reserve'],
  operationKinds: ['Allocate', 'Transfer', 'Recover'], inputProperties: ['charge', 'power'], outputProperties: ['routed'],
  tradeoffKinds: ['distance', 'targets', 'loss'] };
const bridgeSemantic: SemanticProfile = { concepts: { routing: 1, storage: .7 }, objectKinds: ['shell', 'spell'],
  operationKinds: ['Transfer'], inputProperties: ['charge', 'stored'], outputProperties: ['routed'],
  tradeoffKinds: ['distance', 'loss', 'delay'] };
const chain: Condition = { objectProperty: 'shape', comparison: 'eq', value: 'chain' };
const stat = (id: string) => ({ stat: id });
const add = (stat: string, value: number, unit: NumericModifier['unit']): NumericModifier => ({ stat, value, unit, pool: 'add' });
const efficiency = (stat: string, value: number): NumericModifier => ({ stat, value, unit: 'ratio', pool: 'efficiency' });
const transfer: RuleDefinition = { id: 'routing.transfer', stage: 'afterHit', event: 'hit.after', targetKind: 'spell', when: chain,
  operation: { op: 'Transfer', targetPolicy: 'nextUnhit', maxDistance: stat('routing.distance'),
    hopCost: { max: [{ value: 1, unit: 'charge' }, { divide: [stat('routing.hopCostQ'), stat('routing.chargeEfficiency')] }] },
    maxHops: { value: 32, unit: 'count' }, onNoTarget: 'recover' },
  resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 32 } };
const split: RuleDefinition = { id: 'routing.split', stage: 'assemble', event: 'spell.assemble', targetKind: 'spell', when: { not: chain },
  operation: { op: 'Allocate', sourceLot: 'self', shares: [.25], resourceShares: { charge: [1] }, maxChildren: 1,
    remainderPolicy: 'parent', shape: 'chain', applications: { max: [{ value: 1, unit: 'count' }, stat('routing.targets')] } }, resourceCost: [], inherit: 'never',
  repeat: { unit: 'receipt', limit: 1 }, after: ['storage.crystal', 'copy.plain', 'copy.shape', ...RESERVE_USE_RULE_IDS] };
const recover: RuleDefinition = { id: 'routing.recover.charge', stage: 'finish', event: 'route.finish', targetKind: 'spell', when: chain,
  operation: { op: 'Recover', remainingSelector: 'unspent', resource: 'charge', retention: stat('reserve.retention'),
    capacityKey: 'reserve.capacityQ', reuseAfter: 'nextManual' }, resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 } };
export const ROUTING_ENTRY: BuildContribution = { ...empty, rules: [transfer.id, split.id], capabilities: ['charge', 'transfer'],
  supplyDirections: [{ resource: 'charge', weight: 1 }] };
const recovery: BuildContribution = { ...empty, rules: [recover.id, ...RESERVE_USE_RULE_IDS], capabilities: ['recover'] };
const bridge: BuildContribution = { ...empty, modifiers: [add('routing.shellRelay', 1, 'count')] };
const talent = (id: string, contribution: BuildContribution, extra: Partial<TalentDefinition> = {}): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`],
  semantic, appearance: 'mechanic', ...extra });
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: { capability: 'transfer', source: 'build' }, permitsAll: [],
  semantic, budget: { perOpportunity: 8, inherited: false }, ...extra });
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: unit !== 'ratio', stage: 'assemble', multiplierPools: ['efficiency'] });
const numerics = [numeric('routing.distance', 'distance', 300, 40, 1400), numeric('routing.targets', 'count', 3, 0, 16),
  numeric('routing.hopCostQ', 'charge', Q / 2, 1, 16 * Q), numeric('routing.chargeEfficiency', 'ratio', 1, .25, 4),
  numeric('routing.hitRetention', 'ratio', .78, .1, 1), numeric('routing.shellRelay', 'count', 0, 0, 1),
  numeric('routing.relayLimit', 'count', 1, 1, 4), numeric('routing.shellEfficiency', 'ratio', 1, .5, 4)];
const far: BuildContribution = { ...empty, modifiers: [efficiency('routing.distance', .5), add('routing.targets', -1, 'count')] };
const near: BuildContribution = { ...empty, modifiers: [efficiency('routing.distance', -.35), add('routing.targets', 2, 'count')] };

export const ROUTING_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'modeSlots' | 'modeDefaults'> = {
  rules: Object.fromEntries([transfer, split, recover].map(rule => [rule.id, rule])),
  numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  talents: {
    T13: talent('T13', { ...ROUTING_ENTRY, modifiers: [efficiency('routing.chargeEfficiency', .1)] }),
    T14: talent('T14', bridge, { semantic: bridgeSemantic }), T15: talent('T15', far), T16: talent('T16', near), T17: talent('T17', recovery),
    K08: talent('K08', { ...empty, modes: [{ slot: 'routing.mode', value: 'corridor' }],
      modifiers: [add('routing.relayLimit', 3, 'count'), add('routing.targets', -1, 'count')] },
    { cost: 4, appearance: 'keystone', semantic: bridgeSemantic, purchaseRequires: { all: [{ allocated: 'T14' }, { allocated: 'T15' }] } }),
    K09: talent('K09', { ...near, modes: [{ slot: 'routing.mode', value: 'mesh' }] },
      { cost: 4, appearance: 'keystone', purchaseRequires: { any: [{ allocated: 'T14' }, { allocated: 'T16' }] } }),
    ...Object.fromEntries(Array.from({ length: 4 }, (_, i) => {
      const id = `N11-${String(i + 1).padStart(2, '0')}`;
      return [id, talent(id, { ...empty, modifiers: [efficiency('routing.distance', .05)] }, { cost: 1, appearance: 'ordinary' })];
    })),
  },
  relics: {
    R093: relic('R093', recovery), R110: relic('R110', ROUTING_ENTRY, { eligibility: { all: [] } }),
    R111: relic('R111', bridge, { semantic: bridgeSemantic, eligibility: { capability: 'storage', source: 'build' } }),
    R112: relic('R112', far), R113: relic('R113', near),
    R114: relic('R114', { ...empty, modifiers: [add('routing.shellEfficiency', .25, 'ratio')] },
      { semantic: bridgeSemantic, eligibility: { all: [{ capability: 'storage', source: 'build' }, { capability: 'transfer', source: 'build' }] },
        permitsAll: ['permit:talent:T14'] }),
    R116: relic('R116', { ...empty, modes: [{ slot: 'reserve.priority', value: 'charge' }] }, { permitsAll: ['permit:talent:T17'] }),
    R118: relic('R118', { ...empty, modifiers: [add('routing.targets', -1, 'count')] }, { permitsAll: ['permit:talent:K08'] }),
  },
  modeSlots: { 'routing.mode': ['ordinary', 'corridor', 'mesh'] }, modeDefaults: { 'routing.mode': 'ordinary' },
};
