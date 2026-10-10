import { RESOURCE_SCALE as Q } from '../../contracts/build-resources.ts';
import type { BuildContribution, Condition, NumericDefinition, NumericModifier, RelicDefinition, RuleDefinition,
  RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const always: Condition = { all: [] };
const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { storage: 1, replication: .5 }, objectKinds: ['spell', 'shell'],
  operationKinds: ['Store', 'Copy', 'Release'], inputProperties: ['power', 'work'], outputProperties: ['stored'], tradeoffKinds: ['delay', 'capacity'] };
const stat = (id: string) => ({ stat: id });
const add = (stat: string, value: number, unit: NumericModifier['unit']): NumericModifier => ({ stat, value, unit, pool: 'add' });
const efficiency = (stat: string, value: number): NumericModifier => ({ stat, value, unit: 'ratio', pool: 'efficiency' });
const rule = (id: string, operation: RuleDefinition['operation'], extra: Partial<RuleDefinition> = {}): RuleDefinition => ({
  id, operation, stage: 'assemble', event: 'spell.assemble', targetKind: 'spell', when: always,
  resourceCost: [], inherit: 'never', repeat: { unit: 'receipt', limit: 1 }, ...extra,
});
const save = (shellArchetype: 'crystal' | 'paper'): Extract<RuleDefinition['operation'], { op: 'Store' }> => ({
  op: 'Store', shellArchetype, capacityUnits: stat('storage.capacity'), releaseDelayTicks: stat('storage.delayTicks'),
  lifeTicks: stat('storage.lifeTicks'), onNoCapacity: 'retain',
});
const copy = (inherit: boolean): RuleDefinition => rule(`copy.${inherit ? 'shape' : 'plain'}`, {
  op: 'Copy', templateSelector: 'manualSpell', workCost: stat('copy.workCostQ'), fundedPowerFactor: stat('copy.powerFactor'),
  inheritMask: inherit ? ['shape', 'cold', 'heat', 'charge'] : [], maxCopies: stat('copy.maxCopies'),
  storage: { shellArchetype: 'paper', capacityUnits: stat('storage.capacity'), releaseDelayTicks: stat('storage.delayTicks'), lifeTicks: stat('storage.lifeTicks') },
}, { when: inherit ? { allocated: 'T20' } : { not: { allocated: 'T20' } }, repeat: { unit: 'receipt', limit: 8 }, after: ['cold.convert'] });
const rules = [
  rule('storage.crystal', { ...save('crystal'), share: { value: .2, unit: 'ratio' }, retention: stat('storage.retention') },
    { after: ['cold.convert', 'copy.plain', 'copy.shape'] }),
  copy(false), copy(true),
  rule('storage.echo', { op: 'Release', unspentLotSelector: 'unspent', targetPolicy: 'original', exitClaim: 'close', onNoTarget: 'waitOnce' },
    { stage: 'finish', event: 'shell.finish', targetKind: 'shell', inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 }, after: ['fracture.finish'] }),
];
const copyEntry: BuildContribution = { ...empty, rules: ['copy.plain', 'copy.shape'], capabilities: ['copy', 'storage'] };
const crystalEntry: BuildContribution = { ...empty, rules: ['storage.crystal'], capabilities: ['storage'] };
const talent = (id: string, contribution: BuildContribution, extra: Partial<TalentDefinition> = {}): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: always, permits: [`permit:talent:${id}`],
  semantic, appearance: 'mechanic', ...extra,
});
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: always, permitsAll: [], semantic,
  budget: { perOpportunity: 8, inherited: false }, ...extra,
});
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: unit !== 'ratio', stage: 'assemble', multiplierPools: ['efficiency'],
});
const numerics = [
  numeric('storage.capacity', 'count', 6, 1, 64), numeric('storage.delayTicks', 'ticks', 120, 1, 3600),
  numeric('storage.lifeTicks', 'ticks', 600, 30, 7200), numeric('storage.retention', 'ratio', .9, .1, 1),
  numeric('copy.workCostQ', 'work', 4 * Q, Q, 64 * Q), numeric('copy.powerFactor', 'ratio', .22, .01, 1),
  numeric('copy.maxCopies', 'count', 4, 1, 8),
];

/** Sources share one rule ID; a second entrance does not run another complete supplier. */
export const STORAGE_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'modeSlots' | 'legacyRelicIds'> = {
  rules: Object.fromEntries(rules.map(rule => [rule.id, rule])), numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  talents: {
    T01: talent('T01', { ...crystalEntry, modifiers: [efficiency('storage.retention', .1)] }),
    T19: talent('T19', { ...copyEntry, modifiers: [efficiency('copy.powerFactor', .1)] }),
    T20: talent('T20', { ...empty, modifiers: [efficiency('copy.workCostQ', .25)] }),
    T22: talent('T22', { ...empty, rules: ['storage.echo'], capabilities: ['release'] }),
    K01: talent('K01', { ...empty, modes: [{ slot: 'storage-mode', value: 'long' }], modifiers: [
      add('storage.capacity', 4, 'count'), add('storage.delayTicks', 120, 'ticks'), add('storage.lifeTicks', 600, 'ticks'),
    ] }, { cost: 4, appearance: 'keystone', purchaseRequires: { any: [{ allocated: 'T01' }, { allocated: 'T19' }] } }),
    K11: talent('K11', { ...empty, modes: [{ slot: 'storage-mode', value: 'brief' }], modifiers: [
      efficiency('copy.workCostQ', -.3), add('storage.lifeTicks', -552, 'ticks'),
    ] }, { cost: 4, appearance: 'keystone', purchaseRequires: { all: [{ allocated: 'T19' }, { allocated: 'T22' }] } }),
    ...Object.fromEntries(Array.from({ length: 6 }, (_, i) => {
      const id = `N06-${String(i + 1).padStart(2, '0')}`;
      return [id, talent(id, { ...empty, modifiers: [add('storage.capacity', 1, 'count')] }, { cost: 1, appearance: 'ordinary' })];
    })),
  },
  relics: {
    R069: relic('R069', crystalEntry), R070: relic('R070', copyEntry),
    R071: relic('R071', { ...empty, modifiers: [add('storage.capacity', 2, 'count'), add('storage.lifeTicks', 120, 'ticks'),
      add('storage.delayTicks', 30, 'ticks')] }, { eligibility: { capability: 'storage', source: 'build' } }),
    R075: relic('R075', { ...empty, modifiers: [efficiency('copy.workCostQ', -.2), add('storage.lifeTicks', -540, 'ticks')] },
      { eligibility: { capability: 'copy', source: 'build' } }),
  },
  modeSlots: { 'storage-mode': ['long', 'brief'] },
  legacyRelicIds: { 'crystal-seed': 'R069', 'copy-quill': 'R070' },
};
