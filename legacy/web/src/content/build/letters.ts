import { RESOURCE_SCALE } from '../../contracts/build-resources.ts';
import type { BuildContribution, NumericDefinition, RelicDefinition, RuleDefinition, RuleRegistry, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const semantic = { concepts: { literacy: 1 }, objectKinds: ['letter'] as const, operationKinds: ['Mark'] as const,
  inputProperties: ['manual'], outputProperties: ['letter'], tradeoffKinds: ['auxiliary-allocation'] };
const stat = (id: string) => ({ stat: id });
const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const mark = (spread: boolean, mixed: boolean, inheritShape: boolean): RuleDefinition => ({
  id: `letters.${spread ? 'spread' : 'focus'}${mixed ? '.mixed' : ''}${inheritShape ? '.shape' : ''}`,
  stage: 'income', event: 'word.interrupted', targetKind: 'spell',
  modeSlot: 'letters.distribution', modeValue: spread ? 'spread' : 'focus',
  when: { all: [{ mode: 'letters.reward', value: mixed ? 'mixed' : 'power' },
    inheritShape ? { owned: 'R134', minLevel: 1 } : { not: { owned: 'R134', minLevel: 1 } }] },
  operation: { op: 'Mark', positionSelector: spread ? 'nearbyWords' : 'nextWord', matchPolicy: 'manualOnly',
    maxPositions: stat('letters.maxPositions'), rewardAllocation: 'power', humanReceiptClaim: 'once',
    opportunityCost: stat('letters.opportunityCostQ'), maxPerWord: stat('letters.maxPerWord'),
    rewardPlan: { storedShare: mixed ? { multiply: [stat('letters.storedShare'), { value: .75, unit: 'ratio' }] } : stat('letters.storedShare'),
      workShare: { value: mixed ? .25 : 0, unit: 'ratio' }, storedRetention: stat('letters.storedRetention'), workRetention: stat('letters.workRetention'),
      capacityUnits: stat('storage.capacity'), releaseDelayTicks: stat('storage.delayTicks'), lifeTicks: stat('storage.lifeTicks'), inheritShape } },
  resourceCost: [], inherit: 'never', repeat: { unit: 'receipt', limit: 1 } });
const rules = [false, true].flatMap(spread => [false, true].flatMap(mixed => [false, true].map(inherit => mark(spread, mixed, inherit))));
const entry = { rules: rules.map(rule => rule.id), capabilities: ['letters'] as const, modifiers: [], modes: [],
  supplyDirections: [{ resource: 'opportunity' as const, weight: 1 }] };
const talent = (id: string, contribution: BuildContribution = empty, extra: Partial<TalentDefinition> = {}): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`], semantic, appearance: 'mechanic', ...extra });
const relic = (id: string, contribution: BuildContribution, permitsAll: RelicDefinition['permitsAll'] = [], extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, maxLevel: 1, eligibility: { capability: 'letters', source: 'build' }, permitsAll,
  semantic, budget: { perOpportunity: 8, inherited: false }, ...extra });
const add = (stat: string, value: number, unit: NumericDefinition['unit']) => ({ stat, value, unit, pool: 'add' });
const spread: BuildContribution = { ...empty, modes: [{ slot: 'letters.distribution', value: 'spread' }] };
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: unit !== 'ratio', stage: 'income', multiplierPools: ['efficiency'] });
const numerics = [numeric('letters.maxPositions', 'count', 6, 1, 24), numeric('letters.maxPerWord', 'count', 72, 1, 72),
  numeric('letters.opportunityCostQ', 'opportunity', RESOURCE_SCALE, RESOURCE_SCALE, 8 * RESOURCE_SCALE),
  numeric('letters.storedShare', 'ratio', 0, 0, .75), numeric('letters.storedRetention', 'ratio', .85, 0, 1),
  numeric('letters.workRetention', 'ratio', .85, 0, 1)];

export const LETTER_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'legacyRelicIds' | 'modeSlots' | 'modeDefaults'> = {
  rules: Object.fromEntries(rules.map(rule => [rule.id, rule])),
  talents: { T31: talent('T31', entry), T33: talent('T33', spread),
    T32: talent('T32', { ...empty, capabilities: ['storage', 'letterStorage'], modifiers: [add('letters.storedShare', .5, 'ratio')] }),
    K14: talent('K14', { ...empty, modes: [{ slot: 'letters.reward', value: 'mixed' }] },
      { cost: 4, appearance: 'keystone', purchaseRequires: { all: [{ allocated: 'T31' }, { allocated: 'T32' }] } }),
    K15: talent('K15', { ...spread, modifiers: [add('letters.maxPositions', 6, 'count'), add('letters.maxPerWord', -71, 'count')] },
      { cost: 4, appearance: 'keystone', purchaseRequires: { all: [{ allocated: 'T31' }, { allocated: 'T33' }] } }),
    ...Object.fromEntries(Array.from({ length: 3 }, (_, index) => {
      const id = `N24-${String(index + 1).padStart(2, '0')}`;
      return [id, talent(id, { ...empty, modifiers: [add('letters.storedRetention', .03, 'ratio'), add('letters.workRetention', .03, 'ratio')] }, { cost: 1, appearance: 'ordinary' })];
    })),
  },
  relics: {
    R124: relic('R124', entry, [], { eligibility: { all: [] } }),
    R125: relic('R125', { ...empty, modifiers: [add('letters.storedShare', .25, 'ratio')] }, ['permit:talent:T32'],
      { eligibility: { all: [{ capability: 'letters', source: 'build' }, { capability: 'storage', source: 'build' }] } }),
    R126: relic('R126', { ...spread, modifiers: [add('letters.maxPositions', 2, 'count')] }, ['permit:talent:T33']),
    R127: relic('R127', { ...empty, modifiers: [add('letters.maxPositions', -3, 'count'), add('letters.opportunityCostQ', RESOURCE_SCALE, 'opportunity')] }),
    R134: relic('R134', { ...empty, modifiers: [add('letters.storedRetention', -.1, 'ratio')] }, ['permit:talent:T20'],
      { eligibility: { all: [{ capability: 'letters', source: 'build' }, { capability: 'copy', source: 'build' }, { capability: 'letterStorage', source: 'build' }] } }),
  },
  numerics: {
    ...Object.fromEntries(numerics.map(stat => [stat.id, stat])),
    'letters.lifeTicks': { id: 'letters.lifeTicks', unit: 'ticks', base: 600, min: 60, max: 1800, integer: true, stage: 'income', multiplierPools: [] },
    'letters.powerPerUnitQ': { id: 'letters.powerPerUnitQ', unit: 'power', base: 6 * RESOURCE_SCALE, min: 1,
      max: 16 * RESOURCE_SCALE, integer: true, stage: 'income', multiplierPools: ['efficiency'] },
  }, legacyRelicIds: { 'letters-dust': 'R124' },
  modeSlots: { 'letters.distribution': ['focus', 'spread'], 'letters.reward': ['power', 'mixed'] },
  modeDefaults: { 'letters.distribution': 'focus', 'letters.reward': 'power' },
};
