import { RESOURCE_SCALE as Q } from '../../contracts/build-resources.ts';
import type { BuildContribution, NumericDefinition, RuleDefinition, RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { heat: 1, storage: .6, structure: .4 }, objectKinds: ['spell', 'shell'],
  operationKinds: ['Heat', 'Fracture'], inputProperties: ['heat', 'stored'], outputProperties: ['unspent'], tradeoffKinds: ['delay', 'attack-allocation'] };
const stat = (id: string) => ({ stat: id });
const heat = (mode: 'open' | 'retain' | 'immediate', fracture = false): RuleDefinition => ({
  id: `heat.${mode}.${fracture ? 'fracture' : 'plain'}`, stage: 'prepareHit', event: 'shell.heat', targetKind: 'shell',
  modeSlot: 'heat.response', modeValue: mode,
  when: mode === 'retain' ? { all: [] } : fracture ? { owned: 'R101', minLevel: 1 } : { not: { owned: 'R101', minLevel: 1 } },
  operation: { op: 'Heat', thermalLot: 'self', shellSelector: 'self', amount: stat('heat.contactQ'),
    threshold: mode === 'immediate' ? { divide: [stat('heat.thresholdQ'), { value: 4, unit: 'ratio' }] } : stat('heat.thresholdQ'),
    heatMode: mode === 'retain' ? 'retain' : fracture ? 'fracture' : 'open' },
  resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 64 },
});
const fracture = (trigger: 'heat' | 'finish'): RuleDefinition => ({
  id: `fracture.${trigger}`, event: trigger === 'heat' ? 'shell.fracture' : 'shell.finish',
  stage: trigger === 'heat' ? 'afterHit' : 'finish', targetKind: 'shell',
  when: { objectProperty: 'integrity', comparison: 'gte', value: 1 },
  operation: { op: 'Fracture', integrityCost: { value: 1, unit: 'count' }, allocationPattern: 'radial',
    maxPieces: stat('fracture.pieces'), trigger }, resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 },
});
const heaters = [heat('open'), heat('open', true), heat('retain'), heat('immediate'), heat('immediate', true)];
const rules = [...heaters, fracture('heat'), fracture('finish')];
const entry: BuildContribution = { ...empty, rules: heaters.map(rule => rule.id), capabilities: ['release'] };
const talent = (id: string, contribution: BuildContribution, extra: Partial<TalentDefinition> = {}): TalentDefinition => ({
  ...TALENT_PRESENTATION[id], ...contribution, id, cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`],
  semantic, appearance: 'mechanic', ...extra,
});
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: true, stage: 'prepareHit', multiplierPools: ['efficiency'],
});
const numerics = [numeric('heat.contactQ', 'heat', 2 * Q, 1, 64 * Q), numeric('heat.thresholdQ', 'heat', 4 * Q, 4, 64 * Q),
  numeric('heat.capacityQ', 'heat', 8 * Q, Q, 128 * Q), numeric('heat.reach', 'distance', 96, 1, 480),
  numeric('heat.powerPerUnit', 'ratio', 4, 1, 16), numeric('fracture.reach', 'distance', 260, 1, 640),
  numeric('fracture.pieces', 'count', 3, 1, 16)];

export const THERMAL_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'modeSlots' | 'modeDefaults' | 'legacyRelicIds'> = {
  rules: Object.fromEntries(rules.map(rule => [rule.id, rule])), numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  talents: {
    T02: talent('T02', { ...empty, rules: ['fracture.heat', 'fracture.finish'], capabilities: ['fracture'] }),
    T04: talent('T04', { ...empty, modifiers: [
      { stat: 'heat.contactQ', pool: 'efficiency', value: -.25, unit: 'ratio' },
      { stat: 'storage.lifeTicks', pool: 'add', value: 180, unit: 'ticks' },
      { stat: 'storage.delayTicks', pool: 'add', value: 60, unit: 'ticks' },
    ] }),
    T05: talent('T05', entry),
    K04: talent('K04', { ...entry, modes: [{ slot: 'heat.response', value: 'retain' }],
      modifiers: [{ stat: 'storage.delayTicks', pool: 'add', value: 120, unit: 'ticks' }] },
    { cost: 4, appearance: 'keystone', purchaseRequires: { any: [{ allocated: 'T05' }, { allocated: 'T04' }] } }),
    K05: talent('K05', { ...empty, modes: [{ slot: 'heat.response', value: 'immediate' }],
      modifiers: [{ stat: 'storage.lifeTicks', pool: 'add', value: -480, unit: 'ticks' }] },
    { cost: 4, appearance: 'keystone', purchaseRequires: { allocated: 'T05' } }),
  },
  relics: {
    R066: { ...RELIC_PRESENTATION.R066, ...empty, capabilities: ['heat'], supplyDirections: [{ resource: 'heat', weight: 1 }],
      maxLevel: 1, eligibility: { all: [] }, permitsAll: [], semantic, budget: { perOpportunity: 8, inherited: false } },
    R101: { ...RELIC_PRESENTATION.R101, ...entry, modifiers: [{ stat: 'heat.thresholdQ', pool: 'efficiency', value: -.25, unit: 'ratio' }],
      maxLevel: 1, eligibility: { all: [{ capability: 'storage', source: 'build' }, { capability: 'heat', source: 'build' }] },
      permitsAll: ['permit:talent:T02'], semantic, budget: { perOpportunity: 8, inherited: false } },
    R102: { ...RELIC_PRESENTATION.R102, ...empty, modifiers: [
      { stat: 'heat.contactQ', pool: 'efficiency', value: -.25, unit: 'ratio' },
      { stat: 'storage.lifeTicks', pool: 'add', value: 180, unit: 'ticks' },
    ], maxLevel: 1, eligibility: { capability: 'storage', source: 'build' }, permitsAll: [], semantic,
    budget: { perOpportunity: 8, inherited: false } },
  },
  modeSlots: { 'heat.response': ['open', 'retain', 'immediate'] }, modeDefaults: { 'heat.response': 'open' },
  // Multiple legacy items can coexist; their many-to-one asset migration requires an explicit settlement.
  legacyRelicIds: { emberink: 'R066' },
};
