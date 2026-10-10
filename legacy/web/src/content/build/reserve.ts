import { RESOURCE_SCALE as Q, RESERVE_SPACE_UNITS } from '../../contracts/build-resources.ts';
import type { ReserveResource } from '../../contracts/build-resources.ts';
import type { BuildContribution, NumericDefinition, NumericModifier, Quantity, RelicDefinition, RuleDefinition,
  RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const resources: readonly ReserveResource[] = ['power', 'heat', 'charge', 'cold'];
const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { recovery: 1, storage: .5 }, objectKinds: ['spell', 'shell', 'status', 'reserve'],
  operationKinds: ['Recover', 'Attach'], inputProperties: ['unspent'], outputProperties: ['reserve'], tradeoffKinds: ['loss', 'delay', 'capacity'] };
const stat = (id: string): Quantity => ({ stat: id });
const value = (value: number, unit: 'ratio' | 'power' = 'ratio'): Quantity => ({ value, unit });
const add = (stat: string, value: number, unit: NumericModifier['unit']): NumericModifier => ({ stat, value, unit, pool: 'add' });
const efficiency = (stat: string, value: number): NumericModifier => ({ stat, value, unit: 'ratio', pool: 'efficiency' });
const materialMode = (resource: ReserveResource) => resource === 'power' ? {} : { modeSlot: 'reserve.materials', modeValue: 'all' };
const useRules: RuleDefinition[] = resources.map((resource, index) => ({
  id: `reserve.use.${index}-${resource}`, event: 'spell.assemble', stage: 'assemble', targetKind: 'spell', when: { not: { mode: 'reserve.mode', value: 'burst' } },
  operation: { op: 'Attach', lotSelector: 'reserve', targetSelector: 'spell', resource,
    amount: { value: 1_000_000 * Q / RESERVE_SPACE_UNITS[resource], unit: resource },
    reserveShare: stat('reserve.useShare'), reserveLimit: stat('reserve.useLimitQ') },
  resourceCost: [], inherit: 'never', repeat: { unit: 'receipt', limit: 1 },
  ...(resource === 'charge' ? { modeSlot: 'reserve.priority', modeValue: 'standard' } : {}),
}));
useRules.push({ ...useRules[2], id: 'reserve.early-charge', modeSlot: 'reserve.priority', modeValue: 'charge' });
useRules.push(...useRules.map(rule => ({ ...rule, id: `${rule.id}.burst`, when: { mode: 'reserve.mode', value: 'burst' } as const,
  operation: { ...rule.operation as Extract<RuleDefinition['operation'], { op: 'Attach' }>, reserveBurst: {
    minimumTargetRatio: stat('reserve.burstTargetRatio'), share: stat('reserve.burstShare'), totalLimit: stat('reserve.burstLimitQ'),
    cooldownManuals: stat('reserve.burstCooldown'),
  } } })));
export const RESERVE_USE_RULE_IDS: readonly string[] = Object.freeze(useRules.map(rule => rule.id));
type Source = 'dot' | 'extract' | 'shell' | 'miss' | 'clear' | 'route' | 'transport';
const recover = (source: Source, resource: ReserveResource): RuleDefinition => {
  const retention: Quantity = { min: [value(.7), { add: [stat('reserve.retention'),
    source === 'dot' ? stat('reserve.dotBonus') : source === 'miss' ? stat('reserve.missBonus') : value(0)] }] };
  return {
    id: `reserve.recover.${source}.${resource}`, stage: source === 'extract' ? 'assemble' : 'finish',
    event: source === 'dot' ? 'status.death' : source === 'extract' ? 'status.extract'
      : source === 'transport' ? 'transport.finish' : source === 'shell' ? 'shell.finish' : source === 'clear' ? 'room.finish' : source === 'route' ? 'route.finish' : 'spell.finish',
    targetKind: source === 'dot' || source === 'extract' ? 'status' : source === 'shell' || source === 'transport' ? 'shell' : 'spell',
    when: { all: [] }, operation: { op: 'Recover', remainingSelector: source === 'extract' ? 'self' : 'unspent', resource,
      share: source === 'extract' ? stat('reserve.extractShare') : value(1), retention, capacityKey: 'reserve.capacityQ', reuseAfter: 'nextManual' },
    resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: source === 'extract' ? 64 : 1 },
    ...(source === 'shell' ? { after: ['fracture.finish', 'storage.echo', 'native.shell-release'] }
      : source === 'route' ? { after: ['routing.recover.charge'] } : {}), ...materialMode(resource),
  };
};
const recoveryRules = (['dot', 'extract', 'shell', 'miss', 'clear', 'route', 'transport'] as const).flatMap(source => resources.map(resource => recover(source, resource)));
const entry = (...sources: Source[]): BuildContribution => ({ ...empty, capabilities: ['recover'],
  rules: [...useRules.map(rule => rule.id), ...recoveryRules.filter(rule => sources.some(source => rule.id.startsWith(`reserve.recover.${source}.`))).map(rule => rule.id)] });
const talent = (id: string, contribution: BuildContribution, extra: Partial<TalentDefinition> = {}): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`],
  semantic, appearance: 'mechanic', ...extra,
});
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: { capability: 'recover', source: 'build' }, permitsAll: [],
  semantic, budget: { perOpportunity: 8, inherited: false }, ...extra,
});
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: unit !== 'ratio', stage: 'assemble', multiplierPools: ['efficiency'],
});
const numerics = [numeric('reserve.capacityQ', 'power', 32 * Q, Q, 1024 * Q), numeric('reserve.useLimitQ', 'power', 12 * Q, Q, 256 * Q),
  numeric('reserve.useShare', 'ratio', 1, .05, 1), numeric('reserve.retention', 'ratio', .5, 0, .7),
  numeric('reserve.dotBonus', 'ratio', 0, 0, .2), numeric('reserve.missBonus', 'ratio', 0, 0, .2),
  numeric('reserve.extractShare', 'ratio', .25, .05, .75), numeric('reserve.archiveRetention', 'ratio', 0, 0, .9),
  numeric('reserve.burstTargetRatio', 'ratio', 3, 1, 16), numeric('reserve.burstShare', 'ratio', .75, .5, 1),
  numeric('reserve.burstLimitQ', 'power', 48 * Q, Q, 1024 * Q), numeric('reserve.burstCooldown', 'count', 2, 1, 16)];
const numericTalents = Object.fromEntries([14, 15].flatMap(family => Array.from({ length: 5 }, (_, index) => {
  const id = `N${family}-${String(index + 1).padStart(2, '0')}`;
  return [id, talent(id, { ...empty, modifiers: [family === 14 ? efficiency('reserve.capacityQ', .05) : add('reserve.retention', .02, 'ratio')] },
    { cost: 1, appearance: 'ordinary' })];
})));

export const RESERVE_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'modeSlots' | 'modeDefaults'> = {
  rules: Object.fromEntries([...useRules, ...recoveryRules].map(rule => [rule.id, rule])),
  numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  talents: {
    ...numericTalents,
    T07: talent('T07', entry('dot')), T08: talent('T08', entry('extract')),
    T09: talent('T09', { ...empty, modes: [{ slot: 'reserve.materials', value: 'all' }] }),
    T10: talent('T10', { ...empty, modifiers: [efficiency('reserve.useShare', -.5), efficiency('reserve.useLimitQ', -.25)] }),
    T11: talent('T11', { ...empty, modifiers: [add('reserve.archiveRetention', .65, 'ratio')] }),
    T12: talent('T12', entry('miss', 'clear', 'route', 'transport')),
    K06: talent('K06', { ...empty, modes: [{ slot: 'reserve.mode', value: 'long' }], modifiers: [
      add('reserve.archiveRetention', .15, 'ratio'), efficiency('reserve.useLimitQ', -.5), add('reserve.capacityQ', 16 * Q, 'power'),
    ] }, { cost: 4, appearance: 'keystone', purchaseRequires: { allocated: 'T11' } }),
    K07: talent('K07', { ...empty, modes: [{ slot: 'reserve.mode', value: 'burst' }] },
      { cost: 4, appearance: 'keystone', purchaseRequires: { all: [{ allocated: 'T09' }, { allocated: 'T29' }] } }),
  },
  relics: {
    R085: relic('R085', { ...empty, modifiers: [add('reserve.dotBonus', .1, 'ratio'), add('reserve.capacityQ', -8 * Q, 'power')] },
      { eligibility: { all: [{ capability: 'recover', source: 'build' }, { capability: 'ongoing', source: 'build' }] } }),
    R086: relic('R086', { ...empty, modifiers: [add('reserve.capacityQ', 16 * Q, 'power'), add('reserve.useLimitQ', 4 * Q, 'power'), add('reserve.burstLimitQ', 4 * Q, 'power'),
      add('reserve.retention', -.1, 'ratio')] }),
    R087: relic('R087', { ...empty, modes: [{ slot: 'reserve.materials', value: 'all' }] }),
    R088: relic('R088', { ...empty, modifiers: [efficiency('reserve.useShare', -.25), efficiency('reserve.useLimitQ', -.25)] },
      { permitsAll: ['permit:talent:T10'] }),
    R089: relic('R089', { ...empty, modifiers: [add('reserve.burstShare', .15, 'ratio'), add('reserve.burstLimitQ', 16 * Q, 'power'),
      add('reserve.burstCooldown', 1, 'count')] }, { permitsAll: ['permit:talent:K07'] }),
    R090: relic('R090', entry('dot'), { eligibility: { capability: 'ongoing', source: 'build' } }),
    R091: relic('R091', { ...empty, modifiers: [add('reserve.extractShare', .15, 'ratio')] }, { permitsAll: ['permit:talent:T08'] }),
    R092: relic('R092', entry('shell'), { eligibility: { capability: 'storage', source: 'build' } }),
    R094: relic('R094', { ...empty, modifiers: [add('reserve.missBonus', .1, 'ratio')] }, { permitsAll: ['permit:talent:T12'] }),
    R095: relic('R095', { ...empty, modifiers: [add('reserve.archiveRetention', .1, 'ratio')] }, { permitsAll: ['permit:talent:T11'] }),
  },
  modeSlots: { 'reserve.materials': ['power', 'all'], 'reserve.mode': ['steady', 'long', 'burst'], 'reserve.priority': ['standard', 'charge'] },
  modeDefaults: { 'reserve.materials': 'power', 'reserve.mode': 'steady', 'reserve.priority': 'standard' },
};
