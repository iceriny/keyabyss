import type { BuildContribution, NumericDefinition, NumericModifier, RelicDefinition, RuleDefinition, RuleRegistry,
  SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { shaping: 1, storage: .7 }, objectKinds: ['shell'],
  operationKinds: ['Merge'], inputProperties: ['stored'], outputProperties: ['stored'], tradeoffKinds: ['delay', 'targets'] };
const add = (stat: string, value: number, unit: NumericModifier['unit']): NumericModifier => ({ stat, value, unit, pool: 'add' });
const merge: RuleDefinition = { id: 'storage.merge', event: 'shell.assemble', stage: 'assemble', targetKind: 'shell', when: { not: { mode: 'transport.mode', value: 'fleet' } },
  operation: { op: 'Merge', compatibilityKey: 'shapeAndTarget', sameRoot: true, maxInputs: { stat: 'merge.maxInputs' },
    waitTicks: { stat: 'merge.waitTicks' }, outputPolicy: 'preserveShape' }, resourceCost: [], inherit: 'paidProcessing',
  repeat: { unit: 'lot', limit: 1 } };
const entry: BuildContribution = { ...empty, rules: [merge.id], capabilities: ['merge'] };
const talent = (id: string, contribution: BuildContribution, extra: Partial<TalentDefinition> = {}): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`],
  semantic, appearance: 'mechanic', ...extra });
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: { capability: 'storage', source: 'build' }, permitsAll: [],
  semantic, budget: { perOpportunity: 8, inherited: false }, ...extra });
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: true, stage: 'assemble', multiplierPools: [] });
const numerics = [numeric('merge.maxInputs', 'count', 2, 2, 8), numeric('merge.waitTicks', 'ticks', 30, 6, 180)];

export const MERGING_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics'> = {
  rules: { [merge.id]: merge }, numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  talents: {
    T27: talent('T27', entry),
    ...Object.fromEntries(Array.from({ length: 3 }, (_, i) => {
      const id = `N17-${String(i + 1).padStart(2, '0')}`;
      return [id, talent(id, { ...empty, modifiers: [add('merge.waitTicks', -6, 'ticks')] }, { cost: 1, appearance: 'ordinary' })];
    })),
  },
  relics: {
    R077: relic('R077', { ...empty, modifiers: [add('merge.maxInputs', 2, 'count'), add('merge.waitTicks', 6, 'ticks'), add('transport.mergeInputs', 2, 'count')] },
      { eligibility: { all: [{ capability: 'storage', source: 'build' }, { capability: 'merge', source: 'build' }] }, permitsAll: ['permit:talent:T27'] }),
    R108: relic('R108', entry),
  },
};
