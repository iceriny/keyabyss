import type { BuildContribution, NumericDefinition, NumericModifier, RelicDefinition, RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { shaping: .8, routing: .6 }, objectKinds: ['spell'], operationKinds: ['Transfer', 'Release'],
  inputProperties: ['target'], outputProperties: ['target'], tradeoffKinds: ['distance', 'priority'] };
const add = (stat: string, value: number, unit: NumericModifier['unit']): NumericModifier => ({ stat, value, unit, pool: 'add' });
const talent = (id: string, modifiers: NumericModifier[]): TalentDefinition => ({ ...TALENT_PRESENTATION[id], ...empty, id, modifiers,
  cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`], semantic, appearance: 'mechanic' });
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: { any: [
    { capability: 'storage', source: 'build' }, { capability: 'copy', source: 'build' }, { capability: 'transfer', source: 'build' }] },
  permitsAll: [], semantic, budget: { perOpportunity: 8, inherited: false }, ...extra });
const numeric = (id: string, unit: NumericDefinition['unit'], max: number): NumericDefinition => ({
  id, unit, base: 0, min: 0, max, integer: true, stage: 'dispatch', multiplierPools: [] });
const numerics = [numeric('target.strongest', 'count', 1), numeric('target.fresh', 'count', 1),
  numeric('target.threatRadius', 'distance', 960), numeric('target.exitThreatRadius', 'distance', 960)];

export const TARGETING_CONTENT: Pick<RuleRegistry, 'talents' | 'relics' | 'numerics' | 'modeSlots'> = {
  talents: { T29: talent('T29', [add('target.strongest', 1, 'count')]), T30: talent('T30', [add('target.threatRadius', 320, 'distance')]) },
  relics: {
    R109: relic('R109', { ...empty, modifiers: [add('target.fresh', 1, 'count')] }),
    R121: relic('R121', { ...empty, modifiers: [add('target.threatRadius', 320, 'distance')] }),
    R122: relic('R122', { ...empty, modifiers: [add('target.strongest', 1, 'count')] }),
    R140: relic('R140', { ...empty, modifiers: [add('target.exitThreatRadius', 360, 'distance')] }, { permitsAll: ['permit:talent:T22'] }),
    R162: relic('R162', { ...empty, modes: [{ slot: 'target.preference', value: 'blindNear' }], modifiers: [add('target.fresh', 1, 'count')] }),
  },
  numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])), modeSlots: { 'target.preference': ['blindNear'] },
};
