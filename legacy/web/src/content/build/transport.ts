import { RESOURCE_SCALE as Q } from '../../contracts/build-resources.ts';
import type { BuildContribution, NumericDefinition, NumericModifier, RelicDefinition, RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const summon: BuildContribution = { ...empty, capabilities: ['summon'] };
const transport: BuildContribution = { ...empty, capabilities: ['transport'] };
const semantic: SemanticProfile = { concepts: { transport: 1, storage: .6, replication: .3 }, objectKinds: ['shell', 'spell'],
  operationKinds: ['Copy', 'Store', 'Release'], inputProperties: ['work', 'stored'], outputProperties: ['spell'], tradeoffKinds: ['loss', 'delay', 'capacity'] };
const add = (stat: string, value: number, unit: NumericModifier['unit']): NumericModifier => ({ stat, value, unit, pool: 'add' });
const talent = (id: string, contribution: BuildContribution, extra: Partial<TalentDefinition> = {}): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`],
  semantic, appearance: 'mechanic', ...extra,
});
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: { all: [] }, permitsAll: [], semantic,
  budget: { perOpportunity: 8, inherited: false }, ...extra,
});
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: unit !== 'ratio', stage: 'assemble', multiplierPools: [],
});
const numerics = [
  numeric('summon.capacity', 'count', 1, 1, 8), numeric('summon.efficiency', 'ratio', 1, .5, 2),
  numeric('summon.workCostQ', 'work', 2 * Q, Q, 16 * Q), numeric('summon.powerFactor', 'ratio', .22, .01, 1),
  numeric('summon.queueCapacity', 'count', 12, 1, 64), numeric('summon.activeTicks', 'ticks', 300, 60, 1080),
  numeric('transport.retention', 'ratio', .9, .1, 1), numeric('transport.pickupRadius', 'distance', 96, 16, 240),
  numeric('transport.return', 'count', 0, 0, 1), numeric('transport.returnRetention', 'ratio', .8, .1, 1),
  numeric('transport.returnWaitTicks', 'ticks', 30, 1, 180),
  numeric('transport.mergeInputs', 'count', 4, 2, 8), numeric('transport.relay', 'count', 0, 0, 1),
];

/** Transport spends the physical spirit's paid attack; shared entrances never add a second action. */
export const TRANSPORT_CONTENT: Pick<RuleRegistry, 'talents' | 'relics' | 'numerics' | 'legacyRelicIds' | 'modeSlots' | 'modeDefaults'> = {
  numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  talents: {
    T25: talent('T25', transport),
    T26: talent('T26', { ...empty, modifiers: [add('transport.return', 1, 'count')] }),
    T52: talent('T52', { ...summon, modifiers: [add('summon.efficiency', .1, 'ratio')] }),
    K12: talent('K12', { ...empty, modes: [{ slot: 'transport.mode', value: 'fleet' }] },
      { cost: 4, appearance: 'keystone', purchaseRequires: { all: [{ allocated: 'T25' }, { allocated: 'T27' }] } }),
    K13: talent('K13', { ...empty, modes: [{ slot: 'transport.mode', value: 'solo' }], modifiers: [add('transport.retention', .1, 'ratio')] },
      { cost: 4, appearance: 'keystone', purchaseRequires: { allocated: 'T25' } }),
    ...Object.fromEntries(Array.from({ length: 4 }, (_, i) => {
      const id = `N16-${String(i + 1).padStart(2, '0')}`;
      return [id, talent(id, { ...empty, modifiers: [add('transport.retention', .03, 'ratio')] }, { cost: 1, appearance: 'ordinary' })];
    })),
  },
  relics: {
    R005: relic('R005', { ...summon, modifiers: [add('summon.capacity', 1, 'count')] }, { maxLevel: 3 }),
    R035: relic('R035', { ...summon, modifiers: [add('summon.efficiency', .1, 'ratio'), add('summon.activeTicks', 60, 'ticks')] }, { maxLevel: 2 }),
    R079: relic('R079', transport, { eligibility: { all: [{ capability: 'summon', source: 'build' }, { capability: 'storage', source: 'build' }] } }),
    R080: relic('R080', { ...empty, modifiers: [add('transport.returnRetention', .1, 'ratio')] },
      { eligibility: { capability: 'transport', source: 'build' }, permitsAll: ['permit:talent:T26'] }),
    R119: relic('R119', { ...empty, modifiers: [add('transport.relay', 1, 'count')] },
      { eligibility: { all: [{ capability: 'summon', source: 'build' }, { capability: 'transfer', source: 'build' },
        { capability: 'storage', source: 'build' }] }, permitsAll: ['permit:talent:T25'] }),
  },
  modeSlots: { 'transport.mode': ['ordinary', 'fleet', 'solo'] }, modeDefaults: { 'transport.mode': 'ordinary' },
  legacyRelicIds: { spirit: 'R005', bond: 'R035' },
};
