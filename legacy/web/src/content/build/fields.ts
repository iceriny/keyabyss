import type { BuildContribution, NumericDefinition, RelicDefinition, RuleDefinition, RuleRegistry, SemanticProfile, TalentDefinition } from '../../contracts/build-rules.ts';
import { TALENT_PRESENTATION, RELIC_PRESENTATION } from './presentation.ts';
import { RESERVE_USE_RULE_IDS } from './reserve.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { duration: 1, field: .8, recovery: .3 }, objectKinds: ['spell', 'status', 'field'],
  operationKinds: ['Field', 'Recover'], inputProperties: ['power', 'cold'], outputProperties: ['ongoing', 'unspent'],
  tradeoffKinds: ['delay', 'loss', 'targets'] };
const stat = (id: string) => ({ stat: id });
const field = (kind: 'heat' | 'cold'): RuleDefinition => ({
  id: `field.${kind}`, stage: 'prepareHit', event: kind === 'heat' ? 'status.start' : 'hit.prepare',
  targetKind: kind === 'heat' ? 'status' : 'spell', when: { all: [] },
  operation: { op: 'Field', shape: 'circle', radius: stat('field.radius'), lifeTicks: stat('field.lifeTicks'),
    maxApplications: stat('field.applications'), lotAllocation: 'onContact', onFinish: 'recover',
    share: { value: 0, unit: 'ratio' }, resourceShares: kind === 'heat' ? { power: .5 } : { cold: .35 } },
  resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 },
});
const recoveryRules: RuleDefinition[] = (['field.finish', 'room.finish'] as const).flatMap(event =>
  (['power', 'cold', 'heat', 'charge'] as const).map(resource => ({
    id: `field.recover.${event}.${resource}`, event, stage: 'finish', targetKind: 'field', when: { all: [] },
    operation: { op: 'Recover', remainingSelector: 'unspent', resource, retention: stat('reserve.retention'),
      capacityKey: 'reserve.capacityQ', reuseAfter: 'nextManual' }, resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 },
    ...(resource === 'power' ? {} : { modeSlot: 'reserve.materials', modeValue: 'all' }),
  })));
const heat: BuildContribution = { ...empty, rules: ['field.heat'], capabilities: ['field'], modes: [{ slot: 'ongoing.entry', value: 'heat' }] };
export const COLD_FIELD_ENTRY: BuildContribution = { ...empty, rules: ['field.cold'], capabilities: ['field'] };
const recovery: BuildContribution = { ...empty, rules: [...recoveryRules.map(rule => rule.id), ...RESERVE_USE_RULE_IDS], capabilities: ['recover'] };
const relay: BuildContribution = { ...empty, modifiers: [{ stat: 'field.relay', pool: 'add', value: 1, unit: 'count' }] };
const relaySemantic: SemanticProfile = { concepts: { field: 1, routing: .8, duration: .4 }, objectKinds: ['field', 'spell'],
  operationKinds: ['Transfer'], inputProperties: ['ongoing', 'charge'], outputProperties: ['routed'], tradeoffKinds: ['duration', 'loss'] };
const talent = (id: string, contribution: BuildContribution): TalentDefinition => ({ ...TALENT_PRESENTATION[id], ...contribution,
  id, cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`], semantic, appearance: 'mechanic' });
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: { capability: 'field', source: 'build' }, permitsAll: [],
  semantic, budget: { perOpportunity: 8, inherited: false }, ...extra });
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: unit !== 'ratio', stage: 'prepareHit', multiplierPools: ['efficiency'] });
const numerics = [numeric('field.radius', 'distance', 90, 12, 360), numeric('field.lifeTicks', 'ticks', 240, 30, 960),
  numeric('field.applications', 'count', 8, 1, 32), numeric('ongoing.share', 'ratio', .25, .05, .6),
  numeric('ongoing.retention', 'ratio', .9, .1, 1), numeric('ongoing.lifeTicks', 'ticks', 240, 30, 960),
  numeric('ongoing.applications', 'count', 8, 1, 32), numeric('ongoing.universal', 'count', 0, 0, 1),
  numeric('field.relay', 'count', 0, 0, 1), numeric('field.relayRange', 'ratio', 1, 1, 3)];

export const FIELD_CONTENT: Pick<RuleRegistry, 'rules' | 'talents' | 'relics' | 'numerics' | 'modeSlots'> = {
  rules: Object.fromEntries([field('heat'), field('cold'), ...recoveryRules].map(rule => [rule.id, rule])),
  numerics: Object.fromEntries(numerics.map(value => [value.id, value])),
  talents: {
    T45: talent('T45', heat),
    T46: talent('T46', { ...COLD_FIELD_ENTRY, modifiers: [{ stat: 'field.radius', pool: 'efficiency', value: .1, unit: 'ratio' }] }),
    T47: { ...talent('T47', relay), semantic: relaySemantic },
    T48: talent('T48', recovery),
    T49: talent('T49', { ...empty, capabilities: ['ongoing'], modifiers: [
      { stat: 'ongoing.universal', pool: 'add', value: 1, unit: 'count' },
      { stat: 'ongoing.retention', pool: 'efficiency', value: .1, unit: 'ratio' },
    ] }),
  },
  relics: {
    R120: relic('R120', { ...relay, modifiers: [...relay.modifiers, { stat: 'field.relayRange', pool: 'add', value: .2, unit: 'ratio' }] },
      { permitsAll: ['permit:talent:T47'], eligibility: { all: [{ capability: 'field', source: 'build' }, { capability: 'charge', source: 'build' }] },
        semantic: relaySemantic }),
    R152: relic('R152', COLD_FIELD_ENTRY, { eligibility: { capability: 'cold', source: 'build' } }),
    R153: relic('R153', heat, { eligibility: { any: [{ capability: 'heat', source: 'build' }, { capability: 'ongoing', source: 'build' }] } }),
    R154: relic('R154', { ...empty, modifiers: [
      { stat: 'field.lifeTicks', pool: 'add', value: 120, unit: 'ticks' },
      { stat: 'field.applications', pool: 'add', value: 4, unit: 'count' },
    ] }),
    R155: relic('R155', { ...recovery, modifiers: [{ stat: 'reserve.retention', pool: 'add', value: .05, unit: 'ratio' }] },
      { permitsAll: ['permit:talent:T48'] }),
  },
  modeSlots: { 'ongoing.entry': ['heat'] },
};
