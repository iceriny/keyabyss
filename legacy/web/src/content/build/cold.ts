import type { BuildContribution, NumericDefinition, RuleDefinition, RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { cold: 1, protection: .4 }, objectKinds: ['spell', 'field'],
  operationKinds: ['Convert'], inputProperties: ['power'], outputProperties: ['cold'], tradeoffKinds: ['attack-allocation'] };
const convert: RuleDefinition = { id: 'cold.convert', stage: 'assemble', event: 'spell.assemble', targetKind: 'spell', when: { all: [] },
  operation: { op: 'Convert', fromComponent: 'power', toComponent: 'cold', share: { value: .12, unit: 'ratio' },
    rate: { value: 16, unit: 'ratio' }, conversionStage: 'assemble' }, resourceCost: [], inherit: 'never', repeat: { unit: 'receipt', limit: 1 } };
export const COLD_ENTRY: BuildContribution = { ...empty, rules: [convert.id], capabilities: ['cold'] };
const talent = (id: string, contribution: BuildContribution, ordinary = false): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: ordinary ? 1 : 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`],
  semantic, appearance: ordinary ? 'ordinary' : 'mechanic',
});
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: unit !== 'ratio', stage: 'commitHit', multiplierPools: ['efficiency'] });
const efficiency = (value: number): BuildContribution => ({ ...empty,
  modifiers: [{ stat: 'cold.efficiency', value, pool: 'efficiency', unit: 'ratio' }] });
const numerics = [numeric('cold.efficiency', 'ratio', 1, .1, 4), numeric('cold.freezeTicks', 'ticks', 93, 6, 240)];

export const COLD_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'legacyRelicIds'> = {
  rules: { [convert.id]: convert }, numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  talents: {
    T50: talent('T50', { ...COLD_ENTRY, modifiers: efficiency(.1).modifiers }),
    ...Object.fromEntries(Array.from({ length: 5 }, (_, index) => {
      const id = `N02-${String(index + 1).padStart(2, '0')}`; return [id, talent(id, efficiency(.04), true)];
    })),
  },
  relics: {
    R003: { ...RELIC_PRESENTATION.R003, ...COLD_ENTRY, id: 'R003', modifiers: efficiency(.15).modifiers,
      maxLevel: 3, eligibility: { all: [] }, permitsAll: [], semantic, budget: { perOpportunity: 8, inherited: false } },
  },
  legacyRelicIds: { frost: 'R003' },
};
