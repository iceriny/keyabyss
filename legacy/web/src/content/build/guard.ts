import type { BuildContribution, RuleDefinition, RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { protection: 1, storage: .7 }, objectKinds: ['shell'], operationKinds: ['Guard'],
  inputProperties: ['stored', 'power'], outputProperties: ['unspent'], tradeoffKinds: ['attack-allocation'] };
const rules: RuleDefinition[] = (['oldest', 'newest'] as const).map(selectionOrder => ({
  id: `guard.${selectionOrder}`, stage: 'commitHit', event: 'projectile.intercept', targetKind: 'shell', when: { all: [] },
  modeSlot: 'guard.consumeOrder', modeValue: selectionOrder,
  operation: { op: 'Guard', projectileClass: 'reflectable', selectionOrder,
    powerPerBlockedUnit: { divide: [{ value: 1, unit: 'ratio' }, { stat: 'guard.efficiency' }] },
    reserveShare: { stat: 'guard.reserveShare' }, projectileClaim: 'once', maxInputs: { stat: 'guard.maxInputs' } },
  resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'enemyProjectile', limit: 1 },
}));
const entry: BuildContribution = { ...empty, rules: rules.map(rule => rule.id), capabilities: ['guard'] };
const order = (value: 'oldest' | 'newest'): BuildContribution => ({ ...empty, modes: [{ slot: 'guard.consumeOrder', value }],
  modifiers: [{ stat: 'guard.efficiency', pool: 'add', value: .1, unit: 'ratio' }] });
const talent = (id: string, contribution: BuildContribution): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: { all: [] },
  permits: [`permit:talent:${id}`], semantic, appearance: 'mechanic',
});
export const GUARD_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'modeSlots' | 'modeDefaults' | 'legacyRelicIds'> = {
  rules: Object.fromEntries(rules.map(rule => [rule.id, rule])),
  talents: {
    T21: talent('T21', entry),
    T23: talent('T23', order('oldest')),
    T24: talent('T24', order('newest')),
  },
  relics: {
    R138: { ...RELIC_PRESENTATION.R138, ...entry, maxLevel: 1, eligibility: { capability: 'storage', source: 'build' },
      permitsAll: [], semantic, budget: { perOpportunity: 8, inherited: false } },
    R139: { ...RELIC_PRESENTATION.R139, ...empty, modifiers: [{ stat: 'guard.efficiency', pool: 'add', value: .1, unit: 'ratio' }],
      maxLevel: 1, eligibility: { capability: 'guard', source: 'build' }, permitsAll: [], semantic, budget: { perOpportunity: 8, inherited: false } },
    R176: { ...RELIC_PRESENTATION.R176, ...empty, modifiers: [{ stat: 'guard.maxInputs', pool: 'add', value: 1, unit: 'count' }],
      maxLevel: 1, eligibility: { all: [{ capability: 'storage', source: 'build' }, { capability: 'guard', source: 'build' }] },
      permitsAll: ['permit:talent:T27'], semantic: { ...semantic, concepts: { protection: 1, storage: .7, shaping: .5 } },
      budget: { perOpportunity: 8, inherited: false } },
  },
  numerics: {
    'guard.efficiency': { id: 'guard.efficiency', unit: 'ratio', base: 1, min: 1, max: 4, integer: false, stage: 'commitHit', multiplierPools: [] },
    'guard.reserveShare': { id: 'guard.reserveShare', unit: 'ratio', base: .75, min: .1, max: 1, integer: false, stage: 'commitHit', multiplierPools: [] },
    'guard.maxInputs': { id: 'guard.maxInputs', unit: 'count', base: 1, min: 1, max: 2, integer: true, stage: 'commitHit', multiplierPools: [] },
  },
  modeSlots: { 'guard.consumeOrder': ['oldest', 'newest'] }, modeDefaults: { 'guard.consumeOrder': 'oldest' },
  legacyRelicIds: { 'binding-clasp': 'R138' },
};
